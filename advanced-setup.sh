#!/bin/bash

# Hata durumunda betiği durdur
set -e

cat << "EOF"
   _    ____ ____  _  ___  ___  _   _   ____  _____ _____ _   _ ____
  / \  / ___|  _ \/ |/ _ \|__ \| | | | / ___|| ____|_   _| | | |  _ \
 / _ \| |   | |_) | | | | | / /| | | | \___ \|  _|   | | | | | | |_) |
/ ___ \ |___|  _ <| | |_| |/ /_| |_| |  ___) | |___  | | | |_| |  __/
/_/   \_\____|_| \_\_|\___//____|\___/  |____/|_____| |_|  \___/|_|

======================================================================
         RFID Okuyucu ve Sanal Klavye Kurulum
======================================================================
EOF

echo "Nasıl bir kurulum yapmak istiyorsunuz?"
echo "1) Docker ile Kurulum (İzole ortam - Tavsiye Edilen)"
echo "2) Systemd ile Kurulum (Docker olmadan doğrudan Host üzerinde)"
read -p "Seçiminiz (1 veya 2): " INSTALL_CHOICE

if [[ "$INSTALL_CHOICE" != "1" && "$INSTALL_CHOICE" != "2" ]]; then
    echo "Hata: Geçersiz seçim yaptınız. Kurulum iptal edildi."
    exit 1
fi

echo -e "\n[1/6] Sistem paketleri güncelleniyor ve bağımlılıklar kuruluyor..."
sudo apt-get update
# Systemd kurulumu için python kütüphanelerini de host'a kuruyoruz. Docker için de zarar vermez.
sudo apt-get install -y pcscd libccid pcsc-tools python3 python3-pyscard python3-evdev

echo -e "\n[2/6] ACR122U sürücüsü (acr122u_driver.deb) kuruluyor..."
if [ -f "./acr122u_driver.deb" ]; then
    sudo dpkg -i ./acr122u_driver.deb
    sudo apt-get install -f -y
else
    echo "HATA: 'acr122u_driver.deb' dosyası bu dizinde bulunamadı!"
    echo "Lütfen sürücü dosyasını betik ile aynı klasöre koyup tekrar deneyin."
    exit 1
fi

echo -e "\n[3/6] Çakışan NFC kernel modülleri devre dışı bırakılıyor (Blacklist)..."
sudo modprobe -r pn533_usb || true
sudo modprobe -r pn533 || true
sudo modprobe -r nfc || true

sudo bash -c 'cat << INNER_EOF > /etc/modprobe.d/blacklist-acr122u.conf
blacklist pn533
blacklist pn533_usb
blacklist nfc
INNER_EOF'
echo "Çakışan modüller kara listeye eklendi."

echo -e "\n[4/6] Smart Card (pcscd) servisi başlatılıyor..."
sudo systemctl enable --now pcscd.socket
sudo systemctl restart pcscd

echo -e "\n[5/6] Sanal klavye için 'uinput' kernel modülü yükleniyor..."
sudo modprobe uinput

if ! grep -q "^uinput$" /etc/modules-load.d/uinput.conf 2>/dev/null; then
    echo "uinput" | sudo tee -a /etc/modules-load.d/uinput.conf
    echo "uinput modülü kalıcı hale getirildi."
fi

if [ "$INSTALL_CHOICE" == "1" ]; then
    echo -e "\n[6/6] [DOCKER] Konteyner derleniyor ve başlatılıyor..."
    docker compose down
    docker compose up -d --build
    
    echo "======================================================"
    echo " Kurulum Tamamlandı! (DOCKER) Sanal klavye çalışıyor. "
    echo "======================================================"
    echo "Loglar aşağıda akmaya başlayacaktır (Çıkmak için CTRL+C yapabilirsiniz):"
    echo ""
    docker logs -f rfid-keyboard-service

elif [ "$INSTALL_CHOICE" == "2" ]; then
    echo -e "\n[6/6] [SYSTEMD] Servis dosyası oluşturuluyor ve başlatılıyor..."
    CURRENT_DIR=$(pwd)
    SERVICE_FILE="/etc/systemd/system/rfid-keyboard.service"
    
    # Systemd birim dosyasını (unit file) oluştur
    sudo bash -c "cat << SERVICE_EOF > $SERVICE_FILE
[Unit]
Description=Smart RFID Virtual Keyboard Service
After=pcscd.service network.target

[Service]
Type=simple
ExecStart=/usr/bin/python3 $CURRENT_DIR/rfid-keyboard.py
WorkingDirectory=$CURRENT_DIR
Restart=always
RestartSec=5
# uinput ve evdev kernel seviyesinde yetki istediği için root olarak çalıştırıyoruz
User=root

[Install]
WantedBy=multi-user.target
SERVICE_EOF"

    # Systemd deamon'ı yenile ve servisi başlat
    sudo systemctl daemon-reload
    sudo systemctl enable rfid-keyboard.service
    sudo systemctl restart rfid-keyboard.service
    
    echo "======================================================"
    echo " Kurulum Tamamlandı! (SYSTEMD) Sanal klavye çalışıyor."
    echo "======================================================"
    echo "Loglar aşağıda akmaya başlayacaktır (Çıkmak için CTRL+C yapabilirsiniz):"
    echo ""
    sudo journalctl -u rfid-keyboard.service -f
fi
