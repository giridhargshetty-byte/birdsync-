<?php
/**
 * BirdSync KFD - Survey Report Export
 * Karnataka Forest Department | Madikeri Research Circle
 *
 * Exports detections as CSV (for analysis) or a printable HTML survey report
 * (for field records). Read-only: never writes to the database.
 *
 *   scripts/kfd_report.php?format=csv&from=2026-08-01&to=2026-08-17
 *   scripts/kfd_report.php?format=html&range=7
 */

define('__ROOT__', dirname(dirname(__FILE__)));
require_once(__ROOT__ . '/scripts/common.php');

set_timezone();
$config = get_config();
$site_name = get_sitename();

// ---------------------------------------------------------------- parameters
$format = (isset($_GET['format']) && $_GET['format'] === 'csv') ? 'csv' : 'html';

// Accept an explicit range, else fall back to a rolling window of N days.
$valid_date = function ($d) {
    return is_string($d) && preg_match('/^\d{4}-\d{2}-\d{2}$/', $d) === 1;
};
$from = (isset($_GET['from']) && $valid_date($_GET['from'])) ? $_GET['from'] : null;
$to   = (isset($_GET['to'])   && $valid_date($_GET['to']))   ? $_GET['to']   : null;

if ($from === null || $to === null) {
    $range = isset($_GET['range']) ? intval($_GET['range']) : 7;
    if ($range < 1 || $range > 3650) { $range = 7; }
    $to   = date('Y-m-d');
    $from = date('Y-m-d', strtotime("-" . ($range - 1) . " days"));
}
if ($from > $to) { [$from, $to] = [$to, $from]; }

$min_conf = isset($_GET['min_conf']) ? floatval($_GET['min_conf']) : 0.0;
if ($min_conf < 0 || $min_conf > 1) { $min_conf = 0.0; }

// ---------------------------------------------------------------- query
// NOTE: get_db() opens './scripts/birds.db', which only resolves correctly when
// the including script runs from the web root. This page is opened directly at
// /scripts/kfd_report.php, so the working directory differs - open by absolute
// path instead. Read-only: this page never writes to the database.
$db_path = get_home() . '/BirdNET-Pi/scripts/birds.db';
if (!file_exists($db_path)) {
    http_response_code(503);
    echo 'Detections database not found at ' . htmlspecialchars($db_path, ENT_QUOTES, 'UTF-8');
    exit();
}
$db = new SQLite3($db_path, SQLITE3_OPEN_READONLY);
$db->busyTimeout(2000);

$stmt = $db->prepare(
    'SELECT Date, Time, Com_Name, Sci_Name, Confidence, Lat, Lon, File_Name
     FROM detections
     WHERE Date BETWEEN :from AND :to AND Confidence >= :min_conf
     ORDER BY Date DESC, Time DESC'
);
$stmt->bindValue(':from', $from, SQLITE3_TEXT);
$stmt->bindValue(':to', $to, SQLITE3_TEXT);
$stmt->bindValue(':min_conf', $min_conf, SQLITE3_FLOAT);
$result = $stmt->execute();

$rows = [];
while ($row = $result->fetchArray(SQLITE3_ASSOC)) { $rows[] = $row; }

// ---------------------------------------------------------------- CSV output
if ($format === 'csv') {
    $filename = 'KFD_Bioacoustic_Survey_' . $from . '_to_' . $to . '.csv';
    header('Content-Type: text/csv; charset=utf-8');
    header('Content-Disposition: attachment; filename="' . $filename . '"');

    $out = fopen('php://output', 'w');
    // UTF-8 BOM so Kannada/scientific names open correctly in Excel.
    fwrite($out, "\xEF\xBB\xBF");

    fputcsv($out, ['Karnataka Forest Department - Bioacoustic Survey Report']);
    fputcsv($out, ['Station', $site_name]);
    fputcsv($out, ['Period', $from . ' to ' . $to]);
    fputcsv($out, ['Generated', date('Y-m-d H:i:s T')]);
    fputcsv($out, ['Prepared by', 'Madikeri Research Circle']);
    fputcsv($out, []);
    fputcsv($out, ['Date', 'Time', 'Common Name', 'Scientific Name',
                   'Confidence', 'Latitude', 'Longitude', 'Audio File']);

    // Neutralise spreadsheet formula injection in text fields.
    $safe = function ($v) {
        $v = (string)$v;
        return (strlen($v) && strpbrk($v[0], "=+-@\t\r") !== false) ? "'" . $v : $v;
    };

    foreach ($rows as $r) {
        fputcsv($out, [
            $safe($r['Date']), $safe($r['Time']),
            $safe($r['Com_Name']), $safe($r['Sci_Name']),
            number_format((float)$r['Confidence'], 4),
            $r['Lat'], $r['Lon'], $safe($r['File_Name']),
        ]);
    }
    fclose($out);
    exit();
}

// ---------------------------------------------------------------- HTML report
// Aggregate for the summary section.
$species = [];
foreach ($rows as $r) {
    $k = $r['Sci_Name'];
    if (!isset($species[$k])) {
        $species[$k] = ['com' => $r['Com_Name'], 'sci' => $k, 'count' => 0, 'max' => 0.0];
    }
    $species[$k]['count']++;
    $species[$k]['max'] = max($species[$k]['max'], (float)$r['Confidence']);
}
uasort($species, function ($a, $b) { return $b['count'] <=> $a['count']; });

$total = count($rows);
$days  = max(1, (strtotime($to) - strtotime($from)) / 86400 + 1);
$h = function ($s) { return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); };
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>KFD Bioacoustic Survey Report</title>
<!-- root-relative: this page lives under /scripts/, the stylesheet at the web root -->
<link rel="stylesheet" href="/<?php echo $h(get_color_scheme()); ?>">
<style>
  .kfd-report { max-width: 1000px; margin: 0 auto; padding: 16px; }
  .kfd-report-head {
    border-bottom: 3px solid var(--kfd-dark, #0b3d2c);
    padding-bottom: 12px; margin-bottom: 18px; text-align: center;
  }
  .kfd-report-head h1 { margin: 4px 0; font-size: 22px; letter-spacing: 1px; }
  .kfd-report-head .sub { font-size: 13px; opacity: 0.75; }
  .kfd-meta { display: flex; flex-wrap: wrap; gap: 10px; margin-bottom: 18px; }
  .kfd-stat {
    flex: 1 1 150px; border: 1px solid var(--kfd-border, #d7e4dc);
    border-radius: 6px; padding: 10px; text-align: center;
  }
  .kfd-stat .n { font-size: 22px; font-weight: 700; color: var(--kfd-dark, #0b3d2c); }
  .kfd-stat .l { font-size: 11px; text-transform: uppercase; opacity: 0.7; }
  .kfd-report table { width: 100%; margin-bottom: 20px; }
  .kfd-toolbar { text-align: center; margin-bottom: 16px; }
  .kfd-toolbar a, .kfd-toolbar button {
    display: inline-block; padding: 8px 14px; margin: 3px;
    border-radius: 4px; text-decoration: none; font-size: 13px;
    background: var(--kfd-surface-tint, #eef7f1); color: var(--kfd-dark, #0b3d2c);
    border: 1px solid var(--kfd-border, #d7e4dc); cursor: pointer;
  }
  .kfd-footer {
    margin-top: 24px; padding-top: 12px; font-size: 11.5px; text-align: center;
    border-top: 1px solid var(--kfd-border, #d7e4dc); opacity: 0.8;
  }
  @media print {
    .kfd-toolbar, .topnav, .banner { display: none !important; }
    .kfd-report { max-width: none; }
  }
</style>
</head>
<body>
<div class="kfd-report">

  <div class="kfd-report-head">
    <div class="sub">ಕರ್ನಾಟಕ ಅರಣ್ಯ ಇಲಾಖೆ</div>
    <h1>Bioacoustic Survey Report</h1>
    <div class="sub">Karnataka Forest Department &middot; <?php echo $h($site_name); ?></div>
  </div>

  <div class="kfd-toolbar">
    <a href="?format=csv&amp;from=<?php echo $h($from); ?>&amp;to=<?php echo $h($to); ?>&amp;min_conf=<?php echo $h($min_conf); ?>">Download CSV</a>
    <button onclick="window.print()">Print / Save PDF</button>
    <a href="?range=1">Today</a>
    <a href="?range=7">Last 7 days</a>
    <a href="?range=30">Last 30 days</a>
  </div>

  <div class="kfd-meta">
    <div class="kfd-stat"><div class="n"><?php echo number_format($total); ?></div><div class="l">Detections</div></div>
    <div class="kfd-stat"><div class="n"><?php echo number_format(count($species)); ?></div><div class="l">Species</div></div>
    <div class="kfd-stat"><div class="n"><?php echo number_format($days); ?></div><div class="l">Days surveyed</div></div>
    <div class="kfd-stat"><div class="n"><?php echo $total ? number_format($total / $days, 1) : '0'; ?></div><div class="l">Per day avg</div></div>
  </div>

  <p style="text-align:center; font-size:13px;">
    Survey period <strong><?php echo $h($from); ?></strong> to <strong><?php echo $h($to); ?></strong>
    <?php if ($min_conf > 0): ?>
      &middot; minimum confidence <?php echo $h(number_format($min_conf, 2)); ?>
    <?php endif; ?>
  </p>

  <h3>Species Summary</h3>
  <?php if (empty($species)): ?>
    <p style="text-align:center; opacity:0.7;">No detections recorded in this period.</p>
  <?php else: ?>
  <table>
    <thead><tr><th>#</th><th>Common Name</th><th>Scientific Name</th><th>Detections</th><th>Peak Confidence</th></tr></thead>
    <tbody>
    <?php $i = 1; foreach ($species as $s): ?>
      <tr>
        <td><?php echo $i++; ?></td>
        <td><strong><?php echo $h($s['com']); ?></strong></td>
        <td><em><?php echo $h($s['sci']); ?></em></td>
        <td><?php echo number_format($s['count']); ?></td>
        <td><?php echo number_format($s['max'] * 100, 1); ?>%</td>
      </tr>
    <?php endforeach; ?>
    </tbody>
  </table>

  <h3>Detection Log</h3>
  <table>
    <thead><tr><th>Date</th><th>Time</th><th>Common Name</th><th>Scientific Name</th><th>Confidence</th></tr></thead>
    <tbody>
    <?php foreach (array_slice($rows, 0, 500) as $r): ?>
      <tr>
        <td><?php echo $h($r['Date']); ?></td>
        <td><?php echo $h($r['Time']); ?></td>
        <td><?php echo $h($r['Com_Name']); ?></td>
        <td><em><?php echo $h($r['Sci_Name']); ?></em></td>
        <td><?php echo number_format((float)$r['Confidence'] * 100, 1); ?>%</td>
      </tr>
    <?php endforeach; ?>
    </tbody>
  </table>
  <?php if ($total > 500): ?>
    <p style="text-align:center; font-size:12px; opacity:0.75;">
      Showing the 500 most recent of <?php echo number_format($total); ?> detections.
      Download the CSV for the complete dataset.
    </p>
  <?php endif; ?>
  <?php endif; ?>

  <div class="kfd-footer">
    Generated <?php echo date('d M Y, H:i T'); ?> &middot;
    BirdSync bioacoustic monitoring station<br>
    Designed by <strong>Madikeri Research Circle</strong>, Karnataka Forest Department
  </div>

</div>
</body>
</html>
