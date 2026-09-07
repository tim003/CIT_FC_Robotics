// I2C bus scanner for the ESP32-S3 Super Mini bring-up.
//
// Answers one question: what is actually answering on GPIO2/GPIO3?
// Expected for this build (see docs/wiring/netlist.md):
//   0x3C  SSD1306 OLED
//   0x40  PCA9685 servo driver
//
// If a device is missing here, the main sketch cannot talk to it either --
// and a missing 0x3C halts the main sketch before it starts the Wi-Fi AP.
//
// Build:
//   arduino-cli compile --fqbn esp32:esp32:esp32s3:CDCOnBoot=cdc \
//     -u -p /dev/cu.usbmodem* firmware/test/i2c-scan

#include <Wire.h>

#define I2C_SDA 2
#define I2C_SCL 3

void setup() {
  Serial.begin(115200);
  delay(2000);              // let native-USB CDC enumerate before printing
  Wire.begin(I2C_SDA, I2C_SCL);
  Serial.println();
  Serial.printf("I2C scan on SDA=GPIO%d SCL=GPIO%d\n", I2C_SDA, I2C_SCL);
}

void loop() {
  int found = 0;
  for (uint8_t addr = 1; addr < 127; addr++) {
    Wire.beginTransmission(addr);
    if (Wire.endTransmission() == 0) {
      Serial.printf("  found 0x%02X", addr);
      if (addr == 0x3C || addr == 0x3D) Serial.print("   <- SSD1306 OLED");
      if (addr == 0x40) Serial.print("   <- PCA9685");
      if (addr == 0x70) Serial.print("   <- PCA9685 all-call (normal)");
      Serial.println();
      found++;
    }
  }
  if (found == 0) {
    Serial.println("  nothing found.");
    Serial.println("  check: SDA/SCL not swapped, both modules powered,");
    Serial.println("         grounds common with the ESP32.");
  }
  Serial.printf("  %d device(s)\n\n", found);
  delay(3000);
}
