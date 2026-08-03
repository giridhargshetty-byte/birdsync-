/**
 * BirdSync - Canvas Charting Library
 * Custom lightweight Canvas charts styled for light & calm government portal theme.
 */

class BirdSyncCharts {
  static drawBarChart(canvasId, labels, data, colors) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    
    canvas.width = rect.width * window.devicePixelRatio || 600;
    canvas.height = rect.height * window.devicePixelRatio || 240;
    ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);

    const width = rect.width;
    const height = rect.height;
    const padding = { top: 25, right: 20, bottom: 40, left: 45 };

    ctx.clearRect(0, 0, width, height);

    if (!data || data.length === 0) return;

    const maxVal = Math.max(...data, 10);
    const chartW = width - padding.left - padding.right;
    const chartH = height - padding.top - padding.bottom;
    const barWidth = Math.max((chartW / data.length) - 8, 8);

    // Draw Gridlines & Y-Axis Labels
    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 1;
    ctx.fillStyle = '#64748b';
    ctx.font = '11px Inter, sans-serif';
    ctx.textAlign = 'right';

    const steps = 4;
    for (let i = 0; i <= steps; i++) {
      const val = Math.round((maxVal / steps) * i);
      const y = height - padding.bottom - (chartH / steps) * i;
      
      ctx.beginPath();
      ctx.moveTo(padding.left, y);
      ctx.lineTo(width - padding.right, y);
      ctx.stroke();

      ctx.fillText(val.toString(), padding.left - 8, y + 4);
    }

    // Draw Bars
    data.forEach((val, idx) => {
      const x = padding.left + idx * (chartW / data.length) + (chartW / data.length - barWidth) / 2;
      const barH = (val / maxVal) * chartH;
      const y = height - padding.bottom - barH;

      const grad = ctx.createLinearGradient(0, y, 0, height - padding.bottom);
      const mainColor = colors && colors[idx] ? colors[idx] : '#059669';
      grad.addColorStop(0, mainColor);
      grad.addColorStop(1, 'rgba(5, 150, 105, 0.15)');

      ctx.fillStyle = grad;
      ctx.beginPath();
      ctx.roundRect ? ctx.roundRect(x, y, barWidth, barH, [4, 4, 0, 0]) : ctx.rect(x, y, barWidth, barH);
      ctx.fill();

      if (val > 0) {
        ctx.fillStyle = '#0f172a';
        ctx.textAlign = 'center';
        ctx.font = '600 11px Inter, sans-serif';
        ctx.fillText(val.toString(), x + barWidth / 2, y - 6);
      }

      ctx.fillStyle = '#64748b';
      ctx.textAlign = 'center';
      ctx.font = '10px Inter, sans-serif';
      if (labels && labels[idx]) {
        ctx.fillText(labels[idx], x + barWidth / 2, height - 14);
      }
    });
  }

  static drawDonutChart(canvasId, speciesCounts) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    
    canvas.width = rect.width * window.devicePixelRatio || 240;
    canvas.height = rect.height * window.devicePixelRatio || 240;
    ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);

    const width = rect.width;
    const height = rect.height;
    ctx.clearRect(0, 0, width, height);

    const total = speciesCounts.reduce((acc, curr) => acc + curr.count, 0);
    if (total === 0) return;

    const centerX = width / 2;
    const centerY = height / 2;
    const outerRadius = Math.min(centerX, centerY) - 15;
    const innerRadius = outerRadius * 0.65;

    let startAngle = -Math.PI / 2;

    speciesCounts.forEach(item => {
      const sliceAngle = (item.count / total) * (Math.PI * 2);
      const endAngle = startAngle + sliceAngle;

      ctx.beginPath();
      ctx.arc(centerX, centerY, outerRadius, startAngle, endAngle);
      ctx.arc(centerX, centerY, innerRadius, endAngle, startAngle, true);
      ctx.closePath();

      ctx.fillStyle = item.color || '#059669';
      ctx.fill();

      ctx.strokeStyle = '#ffffff';
      ctx.lineWidth = 2;
      ctx.stroke();

      startAngle = endAngle;
    });

    ctx.fillStyle = '#0f172a';
    ctx.textAlign = 'center';
    ctx.font = '700 20px Outfit, sans-serif';
    ctx.fillText(total.toString(), centerX, centerY - 2);

    ctx.fillStyle = '#64748b';
    ctx.font = '500 11px Inter, sans-serif';
    ctx.fillText('Detections', centerX, centerY + 14);
  }

  static drawHeatmap(canvasId, hourlyData) {
    const canvas = document.getElementById(canvasId);
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    const rect = canvas.getBoundingClientRect();
    
    canvas.width = rect.width * window.devicePixelRatio || 600;
    canvas.height = rect.height * window.devicePixelRatio || 120;
    ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);

    const width = rect.width;
    const height = rect.height;
    ctx.clearRect(0, 0, width, height);

    const padding = { top: 20, right: 15, bottom: 30, left: 15 };
    const chartW = width - padding.left - padding.right;
    const cellWidth = chartW / 24;
    const cellHeight = height - padding.top - padding.bottom;

    const maxVal = Math.max(...hourlyData, 1);

    hourlyData.forEach((val, hour) => {
      const x = padding.left + hour * cellWidth;
      const intensity = val / maxVal;

      if (val === 0) {
        ctx.fillStyle = '#f1f5f9';
      } else {
        const r = Math.round(209 * (1 - intensity) + 5 * intensity);
        const g = Math.round(250 * (1 - intensity) + 150 * intensity);
        const b = Math.round(229 * (1 - intensity) + 105 * intensity);
        ctx.fillStyle = `rgb(${r}, ${g}, ${b})`;
      }

      ctx.beginPath();
      ctx.roundRect ? ctx.roundRect(x + 1, padding.top, cellWidth - 2, cellHeight, 4) : ctx.rect(x + 1, padding.top, cellWidth - 2, cellHeight);
      ctx.fill();

      if (hour % 3 === 0) {
        ctx.fillStyle = '#64748b';
        ctx.textAlign = 'center';
        ctx.font = '10px Inter, sans-serif';
        const label = hour === 0 ? '12AM' : hour === 12 ? '12PM' : hour > 12 ? `${hour - 12}PM` : `${hour}AM`;
        ctx.fillText(label, x + cellWidth / 2, height - 8);
      }
    });
  }
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { BirdSyncCharts };
}
