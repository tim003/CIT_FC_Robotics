#include <Wire.h>
#include <Adafruit_PWMServoDriver.h>
#include <Adafruit_SSD1306.h>
#include <Adafruit_GFX.h>

// 指定 SDA 設定在 GPIO 2，SCL 設定在 GPIO 3
#define SDA_PIN 2
#define SCL_PIN 3

// 初始化 PCA9685 與 OLED 螢幕
Adafruit_PWMServoDriver pwm = Adafruit_PWMServoDriver(0x40);
Adafruit_SSD1306 display(128, 64, &Wire, -1);

// 設定 MG90S 伺服馬達的脈衝極限值（可依實際微調）
#define SERVOMIN  150
#define SERVOMAX  600

void setup(){
  Serial.begin(115200);

  // 設定並啟動自訂的 I2C 引腳
  Wire.begin(SDA_PIN, SCL_PIN);

  // 初始化 PCA9685 (標準伺服馬達頻率 50Hz)[cite: 1, 6]
  pwm.begin();
  pwm.setPWMFreq(50);

  // 初始化 SSD1306 OLED 螢幕 (預設位址 0x3C)[cite: 1, 6]
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) {
    Serial.println(F("OLED 初始化失敗！"));
    while(1);
  }

  // 顯示開機畫面
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Sesame S3 Test (G2/G3)");
  display.display();
  delay(1000);
}

void loop(){
  // 1. 控制 3 組伺服馬達轉到 0 度[cite: 1, 6]
  for (int i = 0; i < 3; i++) {
    pwm.setPWM(i, 0, SERVOMIN);
  }
  updateDisplay("Angle: 0 Deg");
  delay(1000);

  // 2. 控制 3 組伺服馬達轉到 90 度 (中間值)[cite: 1, 6]
  for (int i = 0; i < 3; i++) {
    pwm.setPWM(i, 0, (SERVOMIN + SERVOMAX) / 2);
  }
  updateDisplay("Angle: 90 Deg");
  delay(1000);

  // 3. 控制 3 組伺服馬達轉到 180 度[cite: 1, 6]
  for (int i = 0; i < 3; i++) {
    pwm.setPWM(i, 0, SERVOMAX);
  }
  updateDisplay("Angle: 180 Deg");
  delay(1000);
}

// OLED 畫面更新輔助函式
void updateDisplay(String text){
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.println("Sesame S3 Test (G2/G3)");
  display.setCursor(0, 25);
  display.println(text);
  display.display();
}
