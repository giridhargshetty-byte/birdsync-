#!/usr/bin/env python3
"""
BirdSync KFD - Offline Raspberry Pi 5B Audio Engine & Local Server
Karnataka Forest Department Bioacoustic Wildlife Surveillance Platform
"""

import http.server
import socketserver
import os
import sys
import json
import time

PORT = 8080
DIRECTORY = os.path.dirname(os.path.abspath(__file__))

class BirdSyncHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

    def end_headers(self):
        # Allow cross-origin and disable caching for API endpoints
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        super().end_headers()

    def do_GET(self):
        if self.path == '/api/status':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            status = {
                "system": "BirdSync KFD Bioacoustic Engine",
                "hardware": "Raspberry Pi 5B (ARM64)",
                "mode": "100% Offline Sanctuary Mode",
                "uptime_seconds": int(time.time()),
                "status": "ONLINE",
                "location": "Karnataka Forest Sanctuary Site #01"
            }
            self.wfile.write(json.dumps(status).encode('utf-8'))
            return
        
        return super().do_GET()

def run_server():
    os.chdir(DIRECTORY)
    handler = BirdSyncHTTPRequestHandler
    with socketserver.TCPServer(("", PORT), handler) as httpd:
        print(f"==================================================================")
        print(f" 🌿 BirdSync Pi 5B Offline Server Active")
        print(f" 📍 Port: {PORT}")
        print(f" 🌐 Access: http://localhost:{PORT} or http://192.168.4.1:{PORT}")
        print(f"==================================================================")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down BirdSync server...")
            httpd.shutdown()

if __name__ == "__main__":
    run_server()
