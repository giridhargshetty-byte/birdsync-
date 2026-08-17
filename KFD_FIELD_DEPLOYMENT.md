# BirdSync KFD — Field Deployment Guide

**Karnataka Forest Department** · Designed by **Madikeri Research Circle**

Offline bioacoustic monitoring station on Raspberry Pi 5, built on
[Nachtzuster/BirdNET-Pi](https://github.com/Nachtzuster/BirdNET-Pi).

---

## 1. What this fork changes

Everything here is additive or cosmetic. The analysis pipeline, database schema,
settings pages, and services are untouched upstream code.

| Area | Change |
|---|---|
| `homepage/style.css` | White + dark-green KFD theme, gold accent |
| `homepage/static/dark-style.css` | Dark-green night theme (Settings → Color Scheme) |
| `templates/green_bootstrap.css` | Matching theme for Adminer / phpSysInfo panels |
| `homepage/images/` | KFD emblem, banner, favicon |
| `homepage/index.php` | Departmental credit line under station name |
| `homepage/views.php` | One added nav button: **Survey Report** |
| `scripts/kfd_report.php` | **New** — CSV + printable survey report |
| `scripts/kfd_field_setup.sh` | **New** — field readiness script (mic, offline, clock) |

---

## 2. Install

Requires internet **during installation only**.

```bash
git clone https://github.com/giridhargshetty-byte/birdsync-.git ~/BirdNET-Pi
~/BirdNET-Pi/scripts/install_birdnet.sh
```

Passwordless sudo is required, and the installer reboots on success. Run it
inside `tmux` so a dropped SSH session cannot kill it midway.

Already installed? Pull just this fork's changes without touching your data:

```bash
cd ~/BirdNET-Pi && git pull
```

---

## 3. Field readiness check

```bash
sudo ~/BirdNET-Pi/scripts/kfd_field_setup.sh --check   # report only
sudo ~/BirdNET-Pi/scripts/kfd_field_setup.sh           # apply fixes
```

It verifies and fixes, idempotently:

1. **Microphone capture switch** — the single most common failure.
2. **Actual audio signal** — measures peak amplitude of the newest recording.
3. **Latitude / longitude** — warns if unset (see §5, this silently discards detections).
4. **Offline hardening** — disables the online update check and warns on Flickr lookups.
5. **Clock persistence** and disk headroom.

---

## 4. The muted-microphone problem

USB audio adapters commonly boot with the capture switch **off**. The symptom is
misleading: `arecord` runs, WAV files appear at the correct size, but every
sample is zero.

Diagnose:

```bash
amixer -c 0 | grep -A4 -i capture
```

`[off]` at the end of the `Mono: Capture ...` line means muted. Fix it with the
**`cap`** verb — `unmute` operates on playback switches and silently does nothing
here:

```bash
amixer -c 0 sset Mic 100% cap
sudo alsactl store
```

`alsactl store` is essential: without it the mic re-mutes on the next power cycle.

Verify real signal (peak should be in the hundreds or thousands, not 0):

```bash
python3 -c "
import wave,struct,glob,os
f=sorted(glob.glob(os.path.expanduser('~/BirdSongs/StreamData/*.wav')),key=os.path.getmtime)[-1]
w=wave.open(f); d=w.readframes(min(w.getnframes(),48000*3))
s=struct.unpack('<%dh'%(len(d)//2),d)
print('peak',max(abs(x) for x in s))"
```

If it stays 0 with the switch on, the problem is hardware. A USB-C-to-3.5mm
headset dongle needs a 4-pole **TRRS** microphone; a standard TRS mic registers
nothing. Prefer a true USB microphone for field use.

---

## 5. Detections logged but never saved

If the log shows a species but the dashboard does not:

```bash
journalctl -u birdnet_analysis.service -n 200 --no-pager | grep -i "excluded as"
```

`utils/analysis.py` logs every prediction *before* filtering, then discards it if
it fails any filter. The usual cause is **latitude/longitude left at 0.0000** —
BirdNET then builds its plausible-species list for a point in the Atlantic Ocean,
so genuine local species are rejected as implausible.

Fix in **Tools → Settings → Latitude / Longitude**. Use the real station
coordinates; the species list is location-specific.

Still excluded? Either lower **Species Occurrence Frequency Threshold**
(`SF_THRESH`), or bypass the filter for specific birds:

```bash
echo "Pavo cristatus_Indian Peafowl" >> ~/BirdNET-Pi/whitelist_species_list.txt
sudo systemctl restart birdnet_analysis.service
```

---

## 6. Survey reports

**Survey Report** in the dashboard nav, or directly:

| URL | Output |
|---|---|
| `/scripts/kfd_report.php` | Printable report, last 7 days |
| `/scripts/kfd_report.php?range=30` | Last 30 days |
| `/scripts/kfd_report.php?format=csv&from=2026-08-01&to=2026-08-31` | CSV download |
| `...&min_conf=0.8` | Only detections at ≥80% confidence |

CSV is UTF-8 with BOM so scientific and Kannada names open correctly in Excel,
and text fields are guarded against spreadsheet formula injection. "Print / Save
PDF" produces a clean page with navigation hidden.

If Caddy basic auth is configured, `/scripts*` is password-protected — expected,
since survey data should not be world-readable.

---

## 7. Offline operation

Fully offline after installation. Points to be aware of:

- **Update check** — the dashboard runs `git fetch` on page load when logged in,
  which stalls without an uplink. `SILENCE_UPDATE_INDICATOR=1` disables it (the
  setup script does this).
- **Bird images** — supplied by Flickr. Leave `FLICKR_API_KEY` empty offline, or
  every page waits on DNS timeouts.
- **Wikipedia links** — harmless; they simply will not open.
- **Clock** — no NTP offline. Fit the **Pi 5 RTC battery**, otherwise every power
  cut resets the clock and corrupts survey timestamps. `fake-hwclock` is a
  partial fallback.
- **Storage** — recordings accumulate. Set retention under Tools → Settings and
  keep an eye on `df -h`.

---

## 8. Wi-Fi hotspot for field access

Lets officers connect directly with no infrastructure. Raspberry Pi OS Bookworm
and Trixie use NetworkManager — do **not** use the old `hostapd`/`dnsmasq`
recipes, they conflict with it.

```bash
sudo raspi-config nonint do_wifi_country IN
sudo nmcli connection add type wifi ifname wlan0 con-name BirdSyncAP autoconnect yes ssid BirdSync_KFD
sudo nmcli connection modify BirdSyncAP 802-11-wireless.mode ap 802-11-wireless.band bg ipv4.method shared
sudo nmcli connection modify BirdSyncAP wifi-sec.key-mgmt wpa-psk wifi-sec.psk "CHANGE_THIS_PASSWORD"
sudo nmcli connection up BirdSyncAP
```

Dashboard is then at **http://10.42.0.1**.

`band bg` pins 2.4 GHz deliberately — it penetrates forest canopy far better than
5 GHz. `ipv4.method shared` provides DHCP automatically. **Set your own
password.**

The Pi has one radio, so enabling the hotspot disconnects it from any existing
Wi-Fi network. Configure this with a monitor attached, or over Ethernet.

---

## 9. Logo

`homepage/images/` currently ships a **placeholder** emblem. To use the official
departmental seal, replace these three files at the same sizes and commit:

| File | Size | Used for |
|---|---|---|
| `bird.png` | 85×85 | Corner badge / mobile |
| `bnp.png` | 1063×236 | Top banner |
| `favicon.ico` | 32×32 | Browser tab |

Only use artwork the department holds rights to.
