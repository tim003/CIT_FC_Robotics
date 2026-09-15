#include <cassert>
#include <cstdint>
#include <cstring>

#include "sesame_servo_map.h"

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

  void configureOutput(uint8_t pin) { configuredPin = pin; }
  void disable(uint8_t pin) { disabledPin = pin; }
  void enable(uint8_t pin) {
    enabledPin = pin;
    ++enableCount;
  }
};

int main() {
  constexpr uint8_t expectedChannels[SERVO_COUNT] = {4, 5, 0, 1, 7, 6, 2, 3};
  constexpr const char* expectedPhysical[SERVO_COUNT] = {
      "ULF", "ULB", "LLF", "LLB", "URF", "URB", "LRF", "LRB"};
  constexpr const char* expectedLogicalByPhysical[SERVO_COUNT] = {
      "L1", "L2", "L3", "L4", "R1", "R2", "R3", "R4"};
  constexpr uint8_t expectedLogicalIndexByPhysical[SERVO_COUNT] = {
      2, 3, 6, 7, 0, 1, 5, 4};

  bool seenPhysical[SERVO_COUNT] = {};
  bool seenLogical[SERVO_COUNT] = {};
  for (uint8_t logical = 0; logical < SERVO_COUNT; ++logical) {
    const uint8_t channel = pcaChannelForLogicalServo(logical);
    assert(channel == expectedChannels[logical]);
    assert(channel < SERVO_COUNT);
    assert(!seenPhysical[channel]);
    seenPhysical[channel] = true;
  }
  assert(pcaChannelForLogicalServo(SERVO_COUNT) == INVALID_PCA9685_CHANNEL);

  for (uint8_t channel = 0; channel < SERVO_COUNT; ++channel) {
    const ServoDefinition& servo = SERVO_MAP[channel];
    assert(servo.channel == channel);
    assert(std::strcmp(servo.abbreviation, expectedPhysical[channel]) == 0);
    assert(std::strcmp(servo.logicalName, expectedLogicalByPhysical[channel]) == 0);
    assert(servo.logicalIndex == expectedLogicalIndexByPhysical[channel]);
    assert(!seenLogical[servo.logicalIndex]);
    seenLogical[servo.logicalIndex] = true;
  }

  int8_t trims[SERVO_COUNT] = {7, 0, 0, 0, -11, 0, 0, 0};
  const TranslatedServoCommand r1 = translateServoCommand(0, 90, trims);
  assert(r1.valid && r1.pcaChannel == 4 && r1.adjustedAngle == 97);
  const TranslatedServoCommand r4 = translateServoCommand(4, 90, trims);
  assert(r4.valid && r4.pcaChannel == 7 && r4.adjustedAngle == 79);
  assert(translateServoCommand(0, -20, trims).adjustedAngle == 0);
  assert(translateServoCommand(0, 200, trims).adjustedAngle == 180);
  assert(!translateServoCommand(8, 90, trims).valid);

  FakePwm failedPwm;
  FakeOutputEnable failedOe;
  assert(!enableClearedPcaOutputs(failedPwm, failedOe, false));
  assert(failedPwm.callCount == 0);
  assert(failedOe.enableCount == 0);

  // Pre-start OTA errors (ArduinoOTA reports a rejected password through
  // onError() before onStart()) must never disable the servo outputs; only an
  // error after the transfer started keeps them disabled until reboot.
  static_assert(!otaErrorRequiresServoDisable(false),
                "pre-start OTA errors must not disable servo outputs");
  static_assert(otaErrorRequiresServoDisable(true),
                "post-start OTA errors must disable servo outputs");
  assert(!otaErrorRequiresServoDisable(false));
  assert(otaErrorRequiresServoDisable(true));

  // The decision is taken before any state mutation: on the pre-start path no
  // output-enable call happens and readiness survives untouched.
  FakeOutputEnable preStartOe;
  bool preStartReady = true;
  if (otaErrorRequiresServoDisable(false)) {
    prepareServoOutputsForFirmwareUpdate(preStartOe, preStartReady);
  }
  assert(preStartReady);
  assert(preStartOe.configuredPin == 255);
  assert(preStartOe.disabledPin == 255);
  assert(preStartOe.enableCount == 0);

  // Post-start path: the same helper drives the fail-closed disable.
  FakeOutputEnable postStartOe;
  bool postStartReady = true;
  if (otaErrorRequiresServoDisable(true)) {
    prepareServoOutputsForFirmwareUpdate(postStartOe, postStartReady);
  }
  assert(!postStartReady);
  assert(postStartOe.configuredPin == PCA9685_OUTPUT_ENABLE_PIN);
  assert(postStartOe.disabledPin == PCA9685_OUTPUT_ENABLE_PIN);
  assert(postStartOe.enableCount == 0);

  FakeOutputEnable otaOe;
  bool outputsReady = true;
  prepareServoOutputsForFirmwareUpdate(otaOe, outputsReady);
  assert(!outputsReady);
  assert(otaOe.configuredPin == PCA9685_OUTPUT_ENABLE_PIN);
  assert(otaOe.disabledPin == PCA9685_OUTPUT_ENABLE_PIN);
  assert(otaOe.enableCount == 0);

  FakePwm readyPwm;
  FakeOutputEnable readyOe;
  assert(enableClearedPcaOutputs(readyPwm, readyOe, true));
  assert(readyPwm.callCount == PCA9685_OUTPUT_COUNT);
  for (uint8_t channel = 0; channel < PCA9685_OUTPUT_COUNT; ++channel) {
    assert(readyPwm.channels[channel] == channel);
    assert(readyPwm.onValues[channel] == 0);
    assert(readyPwm.offValues[channel] == 4096);
  }
  assert(readyOe.enabledPin == PCA9685_OUTPUT_ENABLE_PIN);
  assert(readyOe.enableCount == 1);
}
