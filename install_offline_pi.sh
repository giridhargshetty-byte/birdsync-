#!/bin/bash
# ==============================================================================
# BirdSync KFD - Raspberry Pi 5B Offline Deployment & Installation Script
# Target OS: Raspberry Pi OS 64-bit (Bookworm)
# Operation Mode: 100% Completely Offline (Sanctuary / Field Station Mode)
# ==============================================================================

set -e

echo "----------------------------------------------------------------------"
echo "  🌿 BirdSync - Karnataka Forest Department Bioacoustic AI System"
echo "  🚀 Installing 100% Offline Surveillance Stack for Raspberry Pi 5B"
echo "----------------------------------------------------------------------"

# 1. System Package Installation
echo "[1/6] Installing offline server, browser, and audio runtime dependencies..."
sudo apt-get update -y
sudo apt-get install -y \
    nginx \
    openssl \
    python3 \
    python3-pip \
    python3-venv \
    chromium-browser \
    unclutter \
    alsa-utils \
    pulseaudio \
    fonts-noto-core \
    fonts-noto-extra \
    fonts-dejavu \
    net-tools \
    hostapd \
    dnsmasq

# 2. Deploy Web Application to Nginx
echo "[2/6] Configuring Nginx Web Server for BirdSync..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_DIR="/var/www/birdsync"
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/"
sudo chown -R www-data:www-data "$INSTALL_DIR"
sudo chmod -R 755 "$INSTALL_DIR"

# Generate Self-Signed SSL Certificate for secure browser microphone access
echo "Generating self-signed SSL certificate for HTTPS microphone access..."
sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
    -keyout /etc/ssl/private/birdsync.key \
    -out /etc/ssl/certs/birdsync.crt \
    -subj "/C=IN/ST=Karnataka/L=Bengaluru/O=KFD/OU=Bioacoustics/CN=birdsync.local" 2>/dev/null || true

# Nginx Site Config (HTTP & HTTPS)
cat << 'EOF' | sudo tee /etc/nginx/sites-available/birdsync
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;

    ssl_certificate /etc/ssl/certs/birdsync.crt;
    ssl_certificate_key /etc/ssl/private/birdsync.key;

    server_name birdsync.local localhost _;

    root /var/www/birdsync;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    # Audio file cache optimization
    location ~* \.(wav|mp3|ogg|aac)$ {
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }

    # Static assets cache
    location ~* \.(css|js|png|jpg|jpeg|svg|ico)$ {
        expires 7d;
        add_header Cache-Control "public, no-transform";
    }
}
EOF

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sf /etc/nginx/sites-available/birdsync /etc/nginx/sites-enabled/birdsync
sudo nginx -t
sudo systemctl restart nginx
sudo systemctl enable nginx

# 3. Configure Wi-Fi Access Point (Hotspot) for Remote Forest Field Devices
echo "[3/6] Configuring Offline Forest Sanctuary Wi-Fi Hotspot (BirdSync_KFD_Hotspot)..."

cat << 'EOF' | sudo tee /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=BirdSync_KFD_Hotspot
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=KFD_Forest_2026!
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

cat << 'EOF' | sudo tee /etc/dnsmasq.d/birdsync-hotspot.conf
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.50,255.255.255.0,24h
domain=birdsync.local
address=/birdsync.local/192.168.4.1
address=/birdsync/192.168.4.1
EOF

# Static IP for wlan0
if ! grep -q "interface wlan0" /etc/dhcpcd.conf 2>/dev/null; then
cat << 'EOF' | sudo tee -a /etc/dhcpcd.conf
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOF
fi

sudo systemctl unmask hostapd 2>/dev/null || true
sudo systemctl enable hostapd 2>/dev/null || true
sudo systemctl enable dnsmasq 2>/dev/null || true

# 4. Create Kiosk Display Autostart Service (for Pi HDMI Monitors)
echo "[4/6] Setting up HDMI Kiosk Mode Autostart Service..."
cat << 'EOF' | sudo tee /etc/systemd/system/birdsync-kiosk.service
[Unit]
Description=BirdSync Kiosk Display Service
After=network.target nginx.service graphic.target

[Service]
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/pi/.Xauthority
ExecStart=/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk http://localhost --incognito --disable-translate --autoplay-policy=no-user-gesture-required
Restart=always
User=pi

[Install]
WantedBy=graphical.target
EOF

sudo systemctl enable birdsync-kiosk.service 2>/dev/null || true

# 5. Audio Subsystem Permissions & Check
echo "[5/6] Configuring USB Microphone & Audio Permissions..."
sudo usermod -aG audio pi 2>/dev/null || true
sudo usermod -aG audio www-data 2>/dev/null || true

# 6. Final Status & Summary
echo "======================================================================"
echo "  ✅ BirdSync Raspberry Pi 5B Offline Stack Installed Successfully!"
echo "======================================================================"
echo ""
echo "  🌐 Local Access URL:    http://localhost  or  http://birdsync.local"
echo "  📶 Sanctuary Hotspot:   SSID: BirdSync_KFD_Hotspot"
echo "                          Password: KFD_Forest_2026!"
echo "                          Hotspot IP: http://192.168.4.1"
echo ""
echo "  🎙️ USB Mic Detection Check:"
echo "     Run 'arecord -l' to list connected bioacoustic microphones."
echo ""
echo "  🔄 Reboot the Raspberry Pi 5B to start all offline services:"
echo "     sudo reboot"
echo "======================================================================"
