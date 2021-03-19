// Copyright (C) 2021 Toitware ApS. All rights reserved.

// Driver for RN4871 bluetooth module

import binary
import serial.device
import serial.registers

class RN4871:
    reg_/serial.Registers ::= ?
    
    constructor dev/serial.Device:
        reg_ = dev.registers