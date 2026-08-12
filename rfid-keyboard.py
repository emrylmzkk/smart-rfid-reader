import time
from smartcard.CardMonitoring import CardMonitor, CardObserver
from smartcard.util import toHexString
from evdev import UInput, ecodes as e

KEY_MAP = {
    '0': e.KEY_0, '1': e.KEY_1, '2': e.KEY_2, '3': e.KEY_3, '4': e.KEY_4,
    '5': e.KEY_5, '6': e.KEY_6, '7': e.KEY_7, '8': e.KEY_8, '9': e.KEY_9
}
GET_UID_APDU = [0xFF, 0xCA, 0x00, 0x00, 0x00]

def send_key(ui, key_code):
    ui.write(e.EV_KEY, key_code, 1)
    ui.syn()
    time.sleep(0.008)
    ui.write(e.EV_KEY, key_code, 0)
    ui.syn()
    time.sleep(0.008)

def type_string(ui, text):
    for char in text:
        if char in KEY_MAP:
            send_key(ui, KEY_MAP[char])
    send_key(ui, e.KEY_ENTER)

class RFIDObserver(CardObserver):
    def __init__(self, ui):
        self.ui = ui

    def update(self, observable, actions):
        added, removed = actions
        for card in added:
            try:
                conn = card.createConnection()
                conn.connect()
                data, sw1, sw2 = conn.transmit(GET_UID_APDU)
                if sw1 == 0x90 and sw2 == 0x00:
                    uid_decimal = int.from_bytes(bytes(data), byteorder='little')
                    uid_str = str(uid_decimal).zfill(10)
                    print(f"Okunan UID: {uid_str}")
                    type_string(self.ui, uid_str)
                conn.disconnect()
            except Exception as ex:
                print(f"Okuma hatası: {ex}")

def main():
    with UInput(name="Virtual-RFID-Keyboard") as ui:
        print("Sanal RFID Klavye Aktif (Event-driven)...")
        monitor = CardMonitor()
        observer = RFIDObserver(ui)
        monitor.addObserver(observer)
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            monitor.deleteObserver(observer)

if __name__ == '__main__':
    main()