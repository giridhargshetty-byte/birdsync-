# 🌿 BirdSync KFD - Raspberry Pi 5B Offline Deployment Guide

This guide provides step-by-step instructions to install and run **BirdSync (Karnataka Forest Department Bioacoustic Surveillance System)** on a **Raspberry Pi 5B** completely **offline** (without internet connection) in remote forest sanctuaries, national parks, and field stations.

---

## 📋 System Requirements

| Component | Recommendation |
| :--- | :--- |
| **Hardware** | Raspberry Pi 5B (4GB or 8GB RAM recommended) |
| **Storage** | 32GB+ High-Speed Class 10 / Application Class 2 MicroSD Card |
| **Operating System** | Raspberry Pi OS 64-bit (Desktop or Lite, Bookworm release) |
| **Audio Hardware** | USB Microphone (e.g., USB Soundcard / Omnidirectional Field Mic) or I2S Mic Array |
| **Display (Optional)** | HDMI Monitor / Touchscreen (for Kiosk kiosk mode) |
| **Power Supply** | Official Raspberry Pi 27W USB-C Power Supply |

---

## ⚡ Quick 1-Step Installation

1. Copy the `bird sync` application folder onto an SD card or USB flash drive and paste it onto your Raspberry Pi 5B at `/home/pi/birdsync`.
2. Open terminal on your Raspberry Pi and navigate to the directory:
   ```bash
   cd /home/pi/birdsync
   ```
3. Make the installer script executable and run it:
   ```bash
   chmod +x install_offline_pi.sh
   sudo ./install_offline_pi.sh
   ```
4. Reboot the Raspberry Pi 5B:
   ```bash
   sudo reboot
   ```

---

## 📡 Features of Offline Raspberry Pi 5B Deployment

### 1. 🌐 Standalone Local Web Portal (`http://birdsync.local`)
- Serves the bioacoustic surveillance dashboard instantly via high-performance Nginx.
- Pre-cached offline fonts and local assets (`assets/kfd-seal.png`). Zero internet dependencies.

### 2. 📶 Sanctuary Wi-Fi Hotspot (`BirdSync_KFD_Hotspot`)
- Field Officers and Range Forest Officers (RFOs) can connect their smartphones, tablets, or laptops directly to the Raspberry Pi's Wi-Fi network in the deep forest.
- **SSID**: `BirdSync_KFD_Hotspot`
- **Password**: `KFD_Forest_2026!`
- **Access URL**: Open browser to `http://192.168.4.1` or `http://birdsync.local`

### 3. 🖥️ Auto-Boot HDMI Kiosk Mode
- Connect any HDMI monitor or field display.
- Upon booting up, Raspberry Pi automatically opens Chromium in fullscreen Kiosk Mode on `http://localhost`.

### 4. 🎙️ Live USB Audio Mic Monitoring
- Automatically interfaces with USB Microphones (`hw:0,0` or `hw:1,0`).
- Runs real-time FFT spectrogram rendering and simulated bioacoustic detection engine in pure Web Audio & WebAssembly.

---

## 🛠️ Manual Alternative: Running Standalone Python Backend Server

If you prefer using Python instead of Nginx:

```bash
python3 birdsync_backend.py
```
Then access the portal at: `http://localhost:8080` or `http://192.168.4.1:8080`.

---

## 🔧 Audio Input Configuration & Diagnostics

To check available microphones connected to your Pi 5B:

```bash
# List capture audio devices
arecord -l

# Test sound recording (5 seconds test)
arecord -D default -d 5 -f cd test.wav && aplay test.wav
```

---

## 🔒 Power Failure Protection & Reliability
- Raspberry Pi OS is configured to run entirely out of RAM cache for Web Server assets, preventing SD card corruption during sudden field power outages.
