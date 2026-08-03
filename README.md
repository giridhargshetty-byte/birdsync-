# 🌿 BirdSync KFD - Bioacoustic Surveillance System

> **Karnataka Forest Department (KFD) Bioacoustic AI System for Raspberry Pi 5B & Field Stations**

BirdSync is an offline-first bioacoustic surveillance and real-time audio analytics dashboard designed for deployment in remote forest sanctuaries, national parks, and field monitoring stations.

---

## ⚡ Quick Installation on Raspberry Pi 5B

### Method 1: One-Line Installer (Recommended)

Run this command directly in your Raspberry Pi terminal:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/birdsync.git
cd birdsync
chmod +x install_offline_pi.sh
sudo ./install_offline_pi.sh
```

After installation completes, reboot your Pi:
```bash
sudo reboot
```

---

## 🔑 Key Features

* **🌐 Standalone Local Portal**: Served locally via Nginx at `http://birdsync.local` with zero internet dependency.
* **📶 Sanctuary Wi-Fi Hotspot**: Creates `BirdSync_KFD_Hotspot` so field officers can view dashboards on mobile devices in deep forest zones.
* **🖥️ HDMI Kiosk Mode**: Automatically boots into full-screen dashboard mode on connected field monitors.
* **🎙️ Real-time Audio AI**: Real-time microphone audio processing, spectrogram visualization, and species identification.

---

## 📁 Repository Structure

```
.
├── index.html                # Main Bioacoustic Surveillance Dashboard UI
├── app.js                    # Core Web Audio, FFT Spectrogram & UI Logic
├── species_data.js           # Wildlife Species Database & Bioacoustic Signatures
├── charts.js                 # Dynamic Analytics & Time-series Visualizations
├── styles.css                # KFD Field-optimised UI Design Tokens & Theme
├── birdsync_backend.py       # Standalone Python Web Server Alternative
├── install_offline_pi.sh     # 1-Click Automated Raspberry Pi Installer
└── README_RASPBERRY_PI_5B.md # Detailed Raspberry Pi 5B Hardware & Network Guide
```

---

## 📖 Detailed Guides

- For complete Raspberry Pi hardware setup, hotspot configuration, and USB microphone diagnostics, refer to [README_RASPBERRY_PI_5B.md](README_RASPBERRY_PI_5B.md).

---

## 📄 License

Developed for Karnataka Forest Department Field Operations.
