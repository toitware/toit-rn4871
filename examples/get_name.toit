// Copyright 2021 Toitware ApS.
// Use of this source code is governed by a Zero-Clause BSD license that can
// be found in the tests/EXAMPLES_LICENSE file.

import gpio
import rn4871 show *
import rn4871.constants show *

RX-PIN ::= 33
TX-PIN ::= 32
RESET-PIN ::= 25

main:
  tx-pin := gpio.Pin TX-PIN
  rx-pin := gpio.Pin RX-PIN
  rst-pin := gpio.Pin RESET-PIN --output --pull-up

  device := Rn4871
      --tx=tx-pin
      --rx=rx-pin
      --reset-pin=rst-pin
      --baud-rate=115200
      --debug-mode
  device.pin-reboot
  device.enter-configuration-mode

  // Print the device name
  print (device.read-for-time --ms=1000)

  device.close
  rst-pin.close
  rx-pin.close
  tx-pin.close
