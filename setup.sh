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

echo -e "\n[1/6] Sistem paketleri güncelleniyor ve bağımlılıklar kuruluyor..."
sudo apt-get update
sudo apt-get install -y pcscd libccid pcsc-tools

echo -e "\n[2/6] ACR122U sürücüsü (acr122u_driver.deb) kuruluyor..."
if [ -f "./acr122u_driver.deb" ]; then
    sudo dpkg -i ./acr122u_driver.deb
    # dpkg sonrası olası eksik bağımlılıkları onar
    sudo apt-get install -f -y
else
    echo "HATA: 'acr122u_driver.deb' dosyası bu dizinde bulunamadı!"
    echo "Lütfen sürücü dosyasını betik ile aynı klasöre koyup tekrar deneyin."
    exit 1
fi

echo -e "\n[3/6] Çakışan NFC kernel modülleri devre dışı bırakılıyor (Blacklist)..."
# Modüller o anda yüklü değilse betiğin hata verip durmaması için '|| true' ekliyoruz
sudo modprobe -r pn533_usb || true
sudo modprobe -r pn533 || true
sudo modprobe -r nfc || true

# Yeniden başlatmalarda bu modüllerin yüklenmesini engellemek için kara listeye alıyoruz
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

# Yeniden başlatmalarda modülün otomatik yüklenmesi için kalıcı hale getir
if ! grep -q "^uinput$" /etc/modules-load.d/uinput.conf 2>/dev/null; then
    echo "uinput" | sudo tee -a /etc/modules-load.d/uinput.conf
    echo "uinput modülü kalıcı hale getirildi."
fi

echo -e "\n[6/6] Docker container'ı derleniyor ve başlatılıyor..."
# Eski container varsa temizle
docker compose down

# Yeniden derle ve arka planda başlat
docker compose up -d --build

echo "======================================================"
echo " Kurulum Tamamlandı! Sanal klavye servisi çalışıyor.  "
echo "======================================================"
echo "Loglar aşağıda akmaya başlayacaktır (Çıkmak için CTRL+C yapabilirsiniz):"
echo ""

# Logları canlı takip et
docker logs -f rfid-keyboard-service
