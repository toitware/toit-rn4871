# UART based driver for Microchip RN4871 BLE module

Contains all the functionalities of RN4871 Bluetooth module.

Needs `RX`, `TX` and `RESET` pins to be connected to the ESP32 microcontroller and specified at `RN4871` object creation. Uses the `UART` interface of the ESP32.

## Usage
A simple usage example.

```
import uart
import gpio
import rn4871 show *

RX_PIN ::= 33
TX_PIN ::= 32
RESET_PIN ::= 25

main:
  tx_pin := gpio.Pin TX_PIN
  rx_pin := gpio.Pin RX_PIN 
  rst_pin := gpio.Pin RESET_PIN --output --pull_up
  
  device := RN4871 --tx=tx_pin --rx=rx_pin --reset_pin=rst_pin --baud_rate=115200 --debug_mode=true
  device.pin_reboot
  device.enter_configuration_mode
  
  print device.get_name
  
```

See the `examples` folder for more examples.

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/toitware/bluetooth-rn4871-module/issues
