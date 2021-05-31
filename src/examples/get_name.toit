// Copyright 2021 Krzysztof Mróz. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import serial.ports.uart
import gpio
import ..rn4871 show *

RX_PIN ::= 33
TX_PIN ::= 32
RESET_PIN ::= 25



main:
  tx_pin := gpio.Pin TX_PIN
  rx_pin := gpio.Pin RX_PIN 
  rst_pin := gpio.Pin RESET_PIN --input=false --output=true --pull_up=true --pull_down=false
  
  device := RN4871 --tx=tx_pin --rx=rx_pin --reset_pin=rst_pin --baud_rate=115200 --debug_mode=true
  device.pin_reboot
  device.enter_configuration_mode
  
  // Print the device name
  print device.get_name
  