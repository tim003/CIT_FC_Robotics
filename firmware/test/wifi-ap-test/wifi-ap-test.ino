// Minimal Wi-Fi AP test for the ESP32-S3 Super Mini.
//
// Isolates the radio from everything else: no OLED, no I2C, no servos.
// It starts the same AP as the main firmware and reports what actually
// happened, including softAP()'s return value -- which the main sketch
// (inherited from upstream) ignores.
//
// If the SSID appears here but not in the main firmware, the fault is in the
// firmware. If it appears in neither, the fault is the board or its power.
//
// Build:
//   arduino-cli compile --clean --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
//     -u -p /dev/cu.usbmodem101 firmware/test/wifi-ap-test

#include <WiFi.h>

#define AP_SSID "Sesame-Controller"
#define AP_PASS "12345678"

void setup() {
  Serial.begin(115200);
  delay(3000);                 // let native-USB CDC enumerate before printing

  Serial.println();
  Serial.println("=== ESP32-S3 Wi-Fi AP test ===");
  Serial.printf("chip:  %s rev %d\n", ESP.getChipModel(), ESP.getChipRevision());
  Serial.printf("reset: %d  (1=power-on, 3=SW, 5=deep-sleep, 6=brownout!)\n",
                (int)esp_reset_reason());

  WiFi.persistent(false);

  // --- RECEIVE TEST -------------------------------------------------------
  // Scan for nearby networks before starting our own. This needs no phone and
  // no second device: if this board can HEAR other access points, its radio
  // and antenna are physically working, and any AP problem is software. If it
  // hears nothing while a phone in the same spot sees a dozen networks, the
  // RF front end or antenna is the fault.
  Serial.println("scanning for nearby networks...");
  WiFi.mode(WIFI_STA);
  int n = WiFi.scanNetworks();
  if (n <= 0) {
    Serial.println("  *** ZERO networks heard -- radio or antenna fault ***");
  } else {
    Serial.printf("  heard %d networks:\n", n);
    for (int i = 0; i < n && i < 12; i++) {
      Serial.printf("    %-24s  %d dBm  ch%d\n",
                    WiFi.SSID(i).c_str(), WiFi.RSSI(i), WiFi.channel(i));
    }
    Serial.println("  -> radio and antenna are working.");
  }
  WiFi.scanDelete();
  Serial.println();

  if (!WiFi.mode(WIFI_AP)) {
    Serial.println("FAIL: WiFi.mode(WIFI_AP) returned false");
  }

  // Force maximum TX power. Some ESP32-S3 Super Mini boards come up at a low
  // default, and with their small ceramic antenna that can make the AP
  // effectively invisible more than a few centimetres away.
  Serial.printf("TX pwr before: %d\n", (int)WiFi.getTxPower());
  WiFi.setTxPower(WIFI_POWER_19_5dBm);
  Serial.printf("TX pwr after:  %d\n", (int)WiFi.getTxPower());

  // Explicit channel 1, not hidden, 4 clients max.
  bool ok = WiFi.softAP(AP_SSID, AP_PASS, 1, 0, 4);
  Serial.printf("softAP() -> %s\n", ok ? "TRUE (AP started)" : "FALSE (AP FAILED)");

  if (ok) {
    Serial.printf("  SSID:    %s\n", AP_SSID);
    Serial.printf("  pass:    %s\n", AP_PASS);
    Serial.printf("  IP:      %s\n", WiFi.softAPIP().toString().c_str());
    Serial.printf("  AP MAC:  %s\n", WiFi.softAPmacAddress().c_str());
    Serial.printf("  channel: %d\n", WiFi.channel());
    Serial.printf("  TX pwr:  %d (units of 0.25 dBm; ~78 = 19.5 dBm)\n",
                  (int)WiFi.getTxPower());
  }

  Serial.println();
  Serial.println("Look for \"Sesame-Controller\" on your phone now.");
  Serial.println("Hold the phone within ~30 cm of the board.");
  Serial.println();
}

void loop() {
  static uint32_t n = 0;
  Serial.printf("[%lus] AP up, clients connected: %d   heap: %lu\n",
                (unsigned long)(n * 3),
                WiFi.softAPgetStationNum(),
                (unsigned long)ESP.getFreeHeap());
  n++;
  delay(3000);
}
