# OLED display

## Installed hardware identity

The project display is the **MN096-12864-4 128×64 OLED module**, controlled by
an **SSD1315** at I2C address `0x3C`. It is not an SSD1306 module.

This identification is source-backed:

- Akizuki Denshi's [module reference for product
  112031](https://akizukidenshi.com/goodsaffix/112031%20202604%E5%85%A5%E8%8D%B7%E3%83%AD%E3%83%83%E3%83%88%E5%8F%82%E8%80%83%E8%B3%87%E6%96%99%E3%81%BE%E3%81%A8%E3%82%81.pdf)
  labels the module `MN096-12864-4`, marks the controller `1315`, and names
  schematic component J3 as `SSD1315`.
- Solomon Systech's [SSD1315
  datasheet](https://akizukidenshi.com/goodsaffix/SSD1315%20%E5%8F%82%E8%80%83%E8%B3%87%E6%96%99.pdf)
  identifies the IC as a 128×64 OLED/PLED driver with an I2C interface.

## Firmware compatibility

The firmware intentionally continues to use Adafruit's `Adafruit_SSD1306`
library and its `SSD1306_*` API constants. On 2026-09-14, a spare display was
hardware-tested through the full library initialization sequence, including the
`AFh` display-on command, and rendered the eight-servo diagnostic interface
correctly. Those library identifiers describe the compatible software API, not
the installed controller.

The original installed display was separately diagnosed as defective: it
acknowledged the preceding initialization commands, then pulled SDA low when
sent `AFh`. Replacing that module with the known-good spare restored normal
display operation without a firmware or library change.
