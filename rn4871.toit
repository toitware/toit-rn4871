// Copyright (C) 2021 Toitware ApS. All rights reserved.

// Driver for RN4871 bluetooth module

import binary
import serial.device
import serial.registers
import serial.ports.uart
import gpio

RX_PIN ::= 32
TX_PIN ::= 33
RESET_PIN ::= 25

class RN4871:
  
  rec_message := ""
  port4871/serial.Port


  // UART constructor
  constructor --tx/gpio.Pin --rx/gpio.Pin --reset_pin/gpio.Pin --baud_rate/int:
    port4871 = serial.Port --tx=tx --rx=rx --baud_rate=baud_rate
    // Reset
    reset_pin.set 0
    sleep --ms=50
    reset_pin.set 1
    rec_message = port4871.read.to_string
    if(rec_message.compare_to "%REBOOT"):
      print "Communication established properly"   
    else:
      print "Communication not established"

  write message/string:
    port4871.write message+"\n" 

  read:
    return port4871.read.to_string



  command_mode:
    // Command mode
    port4871.write "\$\$\$"
    rec_message = port4871.read.to_string
    print rec_message
    if(rec_message.compare_to "CMD>"):
      print "Command mode set up"   
    else:
      print "Failed to set command mode"

  