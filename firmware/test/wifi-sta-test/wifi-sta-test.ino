// Station-mode test: proves whether this board can TRANSMIT at all.
//
// The AP test showed the radio receives fine (it heard 14 networks) but no
// client can see its access point. That leaves two possibilities, and they
// need completely different responses:
//
//   1. The transmitter is dead      -> hardware fault, replace the board
//   2. Only AP mode is broken       -> software, and fixable
//
// Joining a network as a client requires transmitting: probe requests,
// authentication, and association are all two-way. So if this connects, the
// transmitter works and the fault is AP-specific. If it cannot connect to a
// router that it can plainly hear, the transmitter is dead.
//
// EDIT THE TWO LINES BELOW before flashing.
//
// Build:
//   arduino-cli compile --clean --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
//     -u -p /dev/cu.usbmodem101 firmware/test/wifi-sta-test

// Must be a 2.4 GHz network -- the ESP32 cannot see 5 GHz at all.
// A phone hotspot (set to "Maximize Compatibility") is the best target: it
// rules out enterprise login, MAC filtering and a mistyped password at once.
//
// Do not commit real credentials. Leave these placeholders in git.
#define TEST_SSID "your-network-name"
#define TEST_PASS "your-password"

#include <WiFi.h>

static const char *statusName(int s) {
  switch (s) {
    case WL_IDLE_STATUS:     return "IDLE";
    case WL_NO_SSID_AVAIL:   return "NO_SSID_AVAIL (network not found)";
    case WL_SCAN_COMPLETED:  return "SCAN_COMPLETED";
    case WL_CONNECTED:       return "CONNECTED";
    case WL_CONNECT_FAILED:  return "CONNECT_FAILED (usually wrong password)";
    case WL_CONNECTION_LOST: return "CONNECTION_LOST";
    case WL_DISCONNECTED:    return "DISCONNECTED (still trying)";
    default:                 return "unknown";
  }
}

void setup() {
  Serial.begin(115200);
  delay(3000);

  Serial.println();
  Serial.println("=== ESP32-S3 station-mode transmit test ===");
  Serial.printf("target SSID: \"%s\"\n\n", TEST_SSID);

  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setTxPower(WIFI_POWER_19_5dBm);

  // Confirm we can actually hear the target before blaming the transmitter.
  Serial.println("scanning...");
  int n = WiFi.scanNetworks();
  bool found = false;
  int rssi = 0;
  for (int i = 0; i < n; i++) {
    if (WiFi.SSID(i) == TEST_SSID) { found = true; rssi = WiFi.RSSI(i); }
  }
  if (found) {
    Serial.printf("  target IS audible at %d dBm -- good, receive works.\n\n", rssi);
  } else {
    Serial.println("  *** target NOT heard. Wrong name, or it is 5 GHz only. ***");
    Serial.println("  ESP32 is 2.4 GHz only. Fix this before trusting the result.\n");
  }
  WiFi.scanDelete();

  Serial.println("connecting (30s limit)...");
  WiFi.begin(TEST_SSID, TEST_PASS);

  unsigned long start = millis();
  int last = -1;
  while (WiFi.status() != WL_CONNECTED && millis() - start < 30000) {
    int s = WiFi.status();
    if (s != last) { Serial.printf("  [%2lus] %s\n", (millis() - start) / 1000, statusName(s)); last = s; }
    delay(250);
  }

  Serial.println();
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("*** CONNECTED -- THE TRANSMITTER WORKS. ***");
    Serial.printf("  IP:   %s\n", WiFi.localIP().toString().c_str());
    Serial.printf("  RSSI: %d dBm\n", WiFi.RSSI());
    Serial.println("  => The board is fine. The fault is specific to AP mode.");
  } else {
    Serial.println("*** FAILED TO CONNECT ***");
    Serial.printf("  final status: %s\n", statusName(WiFi.status()));
    Serial.println("  If the target was audible above but this still failed,");
    Serial.println("  the board can hear but cannot speak => transmitter is dead.");
  }
}

void loop() {
  delay(5000);
  Serial.printf("status: %s  RSSI: %d\n", statusName(WiFi.status()), WiFi.RSSI());
}
