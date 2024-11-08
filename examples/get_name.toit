// Copyright 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/TESTS_LICENSE file.

import serial.ports.uart
import gpio
import rn4871 show *
import rn4871.constants show *

RX_PIN ::= 33
TX_PIN ::= 32
RESET_PIN ::= 25

main:
  tx_pin := gpio.Pin TX_PIN
  rx_pin := gpio.Pin RX_PIN
  rst_pin := gpio.Pin RESET_PIN --output --pull_up

  device := RN4871 --tx=tx_pin --rx=rx_pin --reset_pin=rst_pin --baud_rate=115200 --debug_mode
  device.pin_reboot
  device.enter_configuration_mode

  /// Print the device name
  print (device.read_for_time --ms=1000)
