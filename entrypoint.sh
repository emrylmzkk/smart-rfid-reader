#!/bin/bash
# Konteyner içinde pcscd servisini arka planda başlat
pcscd &
sleep 1

# RFID klavye betiğini çalıştır
exec python3 /app/rfid-keyboard.py