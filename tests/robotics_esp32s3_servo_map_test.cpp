#include <cassert>
#include <cstdint>
#include <cstring>

#include "robotics_esp32s3_servo_map.h"

struct FakePwm {
  uint8_t channels[PCA9685_OUTPUT_COUNT] = {};
  uint16_t onValues[PCA9685_OUTPUT_COUNT] = {};
  uint16_t offValues[PCA9685_OUTPUT_COUNT] = {};
  uint8_t callCount = 0;

  void setPWM(uint8_t channel, uint16_t on, uint16_t off) {
    channels[callCount] = channel;
    onValues[callCount] = on;
    offValues[callCount] = off;
    ++callCount;
  }
};

struct FakeOutputEnable {
  uint8_t configuredPin = 255;
  uint8_t disabledPin = 255;
  uint8_t enabledPin = 255;
  uint8_t enableCount = 0;
  uint8_t callOrder[3] = {0, 0, 0};
  uint8_t callCount = 0;

  void configureOutput(uint8_t pin) {
    configuredPin = pin;
    callOrder[callCount++] = 1;
  }

  void disable(uint8_t pin) {
    disabledPin = pin;
    callOrder[callCount++] = 2;
  }

  void enable(uint8_t pin) {
    enabledPin = pin;
    enableCount++;
    callOrder[callCount++] = 3;
  }
};

int main() {
  const char* expectedNames[] = {
      "ULF", "ULB", "LLF", "LLB", "URF", "URB", "LRF", "LRB"};

  static_assert(SERVO_COUNT == 8, "The robot must expose eight leg servos");
  for (uint8_t index = 0; index < SERVO_COUNT; ++index) {
    assert(SERVO_MAP[index].channel == index);
    assert(std::strcmp(SERVO_MAP[index].abbreviation, expectedNames[index]) == 0);
  }

  const uint8_t expectedPairs[DISPLAY_ROW_COUNT][2] = {
      {0, 4}, {1, 5}, {2, 6}, {3, 7}};
  for (uint8_t row = 0; row < DISPLAY_ROW_COUNT; ++row) {
    assert(DISPLAY_PAIRS[row][0] == expectedPairs[row][0]);
    assert(DISPLAY_PAIRS[row][1] == expectedPairs[row][1]);
  }

  assert(servoAngleToPulse(0) == 150);
  assert(servoAngleToPulse(90) == 331);
  assert(servoAngleToPulse(180) == 512);

  char cell[SERVO_CELL_BUFFER_SIZE];
  formatServoCell(cell, sizeof(cell), SERVO_MAP[0], -1, false);
  assert(std::strcmp(cell, " 0 ULF:---") == 0);

  formatServoCell(cell, sizeof(cell), SERVO_MAP[0], 90, true);
  assert(std::strcmp(cell, "*0 ULF: 90") == 0);

  formatServoCell(cell, sizeof(cell), SERVO_MAP[7], 180, false);
  assert(std::strcmp(cell, " 7 LRB:180") == 0);

  FakeOutputEnable outputEnable;
  holdServoOutputsDisabled(outputEnable);
  assert(outputEnable.configuredPin == 18);
  assert(outputEnable.disabledPin == 18);
  assert(outputEnable.callCount == 2);
  assert(outputEnable.callOrder[0] == 1);
  assert(outputEnable.callOrder[1] == 2);

  FakePwm pwm;
  FakeOutputEnable clearOe;
  assert(enableClearedPcaOutputs(pwm, clearOe, true));
  assert(pwm.callCount == PCA9685_OUTPUT_COUNT);
  for (uint8_t channel = 0; channel < PCA9685_OUTPUT_COUNT; ++channel) {
    assert(pwm.channels[channel] == channel);
    assert(pwm.onValues[channel] == 0);
    assert(pwm.offValues[channel] == 4096);
  }
  assert(clearOe.enabledPin == 18);
  assert(clearOe.enableCount == 1);

  return 0;
}
