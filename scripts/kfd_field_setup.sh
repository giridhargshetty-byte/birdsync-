#!/usr/bin/env bash
# =============================================================================
# BirdSync KFD - Field Deployment Setup
# Karnataka Forest Department | Madikeri Research Circle
#
# Applies the fixes needed for unattended offline operation on a Raspberry Pi 5
# in the field. Safe to re-run: every step is idempotent and skips work that is
# already done. Does not touch the detections database or your settings.
#
#   sudo ./kfd_field_setup.sh              # apply everything
#   sudo ./kfd_field_setup.sh --check      # report state, change nothing
# =============================================================================

set -uo pipefail

CHECK_ONLY=0
[ "${1:-}" == "--check" ] && CHECK_ONLY=1

RUN_USER="${SUDO_USER:-$USER}"
RUN_HOME=$(getent passwd "$RUN_USER" | cut -d: -f6)
CONF=/etc/birdnet/birdnet.conf

ok()   { echo "  [ OK ] $*"; }
warn() { echo "  [WARN] $*"; }
act()  { echo "  [ DO ] $*"; }
hdr()  { echo; echo "=== $* ==="; }

# -----------------------------------------------------------------------------
hdr "1. Microphone capture switch"
# The USB capture switch defaults to [off] on many USB audio adapters, which
# makes arecord produce perfectly-sized WAV files containing pure silence.
# 'cap' enables the capture switch; 'unmute' does NOT (that is playback only).

CARD=$(arecord -l 2>/dev/null | sed -n 's/^card \([0-9]\+\).*/\1/p' | head -1)
if [ -z "$CARD" ]; then
  warn "No capture device found. Check the USB mic is plugged in (lsusb)."
else
  ok "Capture device on card $CARD"
  # Find every capture-capable simple control and enable it.
  MIC_CONTROLS=$(amixer -c "$CARD" scontrols 2>/dev/null \
                 | sed -n "s/.*'\(.*\)',.*/\1/p")
  for CTL in $MIC_CONTROLS; do
    if amixer -c "$CARD" sget "$CTL" 2>/dev/null | grep -q "cswitch"; then
      STATE=$(amixer -c "$CARD" sget "$CTL" 2>/dev/null | grep -o "\[o[nf]*\]" | head -1)
      if [ "$STATE" == "[off]" ]; then
        if [ $CHECK_ONLY -eq 1 ]; then
          warn "Control '$CTL' is MUTED (would enable)"
        else
          act "Enabling capture on '$CTL'"
          amixer -c "$CARD" sset "$CTL" 100% cap >/dev/null 2>&1
        fi
      else
        ok "Control '$CTL' capture is on"
      fi
    fi
  done

  if [ $CHECK_ONLY -eq 0 ]; then
    # Persist mixer state so the mic is not muted again after a power cycle.
    alsactl store 2>/dev/null && ok "Mixer state saved (survives reboot)"
    systemctl enable alsa-restore.service >/dev/null 2>&1
  fi
fi

# -----------------------------------------------------------------------------
hdr "2. Verify the microphone is producing signal"

LATEST=$(ls -t "$RUN_HOME"/BirdSongs/StreamData/*.wav 2>/dev/null | head -1)
if [ -z "$LATEST" ]; then
  warn "No recordings yet - is birdnet_recording.service running?"
else
  LEVEL=$(python3 - "$LATEST" <<'PY' 2>/dev/null
import sys, wave, struct
try:
    w = wave.open(sys.argv[1]); d = w.readframes(min(w.getnframes(), 48000*3))
    s = struct.unpack('<%dh' % (len(d)//2), d)
    print(max(abs(x) for x in s))
except Exception:
    print(-1)
PY
)
  if [ "$LEVEL" == "-1" ]; then
    warn "Could not read $LATEST"
  elif [ "$LEVEL" -lt 10 ]; then
    warn "Audio is SILENT (peak $LEVEL). Mic muted, unplugged, or wrong device."
    warn "If using a USB-C headset dongle, the mic must be a 4-pole TRRS plug."
  else
    ok "Audio signal present (peak $LEVEL)"
  fi
fi

# -----------------------------------------------------------------------------
hdr "3. Location settings (required for detections to be kept)"

LAT=$(grep -E "^LATITUDE=" "$CONF" 2>/dev/null | cut -d= -f2)
LON=$(grep -E "^LONGITUDE=" "$CONF" 2>/dev/null | cut -d= -f2)
if [ "$LAT" == "0.0000" ] || [ "$LON" == "0.0000" ] || [ -z "$LAT" ]; then
  warn "LATITUDE/LONGITUDE are unset ($LAT / $LON)."
  warn "BirdNET filters out every species implausible at 0,0 (Atlantic Ocean),"
  warn "so valid local detections are silently discarded."
  warn "Fix in the dashboard: Tools -> Settings -> Latitude / Longitude."
else
  ok "Location set to $LAT / $LON"
fi

# -----------------------------------------------------------------------------
hdr "4. Offline hardening"

# 4a. The dashboard runs 'git fetch' against GitHub on page load to check for
# updates. With no uplink this blocks page rendering until the network times
# out, making the UI feel broken in the field.
if grep -qE "^SILENCE_UPDATE_INDICATOR=1" "$CONF" 2>/dev/null; then
  ok "Update indicator already silenced"
elif [ $CHECK_ONLY -eq 1 ]; then
  warn "Update check is ON (would disable for offline use)"
else
  act "Disabling online update check"
  if grep -qE "^SILENCE_UPDATE_INDICATOR=" "$CONF"; then
    sed -i 's/^SILENCE_UPDATE_INDICATOR=.*/SILENCE_UPDATE_INDICATOR=1/' "$CONF"
  else
    echo "SILENCE_UPDATE_INDICATOR=1" >> "$CONF"
  fi
fi

# 4b. Flickr supplies bird thumbnails. Offline each lookup waits for DNS/TCP
# timeouts, so leaving the key empty keeps pages fast.
FKEY=$(grep -E "^FLICKR_API_KEY=" "$CONF" 2>/dev/null | cut -d= -f2)
if [ -z "$FKEY" ]; then
  ok "Flickr image lookups disabled (no API key set)"
else
  warn "FLICKR_API_KEY is set; image lookups will stall without internet."
  warn "Clear it in Tools -> Settings for offline deployment."
fi

# 4c. Without an uplink there is no NTP, and the Pi 5 has no clock battery by
# default, so every reboot restores a stale time and corrupts survey
# timestamps. fake-hwclock at least preserves monotonic-ish time across boots.
if dpkg -s fake-hwclock >/dev/null 2>&1; then
  ok "fake-hwclock installed (clock persists across reboots)"
else
  warn "fake-hwclock NOT installed - timestamps will reset on power loss."
  warn "Best fix: fit the Pi 5 RTC battery. Fallback: apt install fake-hwclock"
fi

# -----------------------------------------------------------------------------
hdr "5. Storage safety"

USE=$(df --output=pcent / | tail -1 | tr -dc '0-9')
if [ "${USE:-0}" -gt 85 ]; then
  warn "Disk is ${USE}% full - recordings may stop. Check retention settings."
else
  ok "Disk usage ${USE}%"
fi

echo
if [ $CHECK_ONLY -eq 1 ]; then
  echo "Check complete (no changes made)."
else
  echo "Field setup complete."
  echo "Restart capture to apply:  sudo systemctl restart birdnet_recording.service"
fi
