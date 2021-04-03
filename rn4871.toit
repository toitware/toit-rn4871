// Copyright (C) 2021 Toitware ApS. All rights reserved.

// Driver for RN4871 bluetooth module

import binary
import serial.device
import serial.registers
import serial.ports.uart
import gpio


DELAY_INTERNAL_CMD ::= 5
INTERNAL_CMD_TIMEOUT ::= 200 // 1000 mSec = 1Sec.
SMALL_ANSWER_DATA_LEN::= 20

PROMPT ::= "CMD>"
PROMPT_FIRST_CHAR::= 'C'
PROMPT_LAST_CHAR ::= '>'
PROMPT_LEN ::= 4
PROMPT_END ::= "END"
PROMPT_END_FIST_CHAR ::= 'E'
PROMPT_END_LAST_CHAR ::= 'D'
PROMPT_ERROR ::= "Err"

DATA_LAST_CHAR ::= "\r"

CONF_COMMAND::= "\$\$\$"

// commands
FACTORY_RESET::= "SF,1"
EXIT_CONF ::="---\r"

AUTO_RANDOM_ADDRESS::= "&R"
USER_RANDOM_ADDRESS::= "&,"

SET_NAME ::="SDM,"
GET_NAME ::="GDM"

SET_BAUDRATE ::="SB,"
GET_BAUDRATE ::="GB"

SET_POWERSAVE ::="SO,"
GET_POWERSAVE ::="GO"
POWERSAVE_ENABLE::='1'
POWERSAVE_DISABLE ::='0'

GET_FWVERSION ::="GDF"
GET_HWVERSION ::="GDH"
GET_SWVERSION ::="GDR"
GET_SERIALNUM ::="GDS"

// Status enums
ENUM_ENTER_DATMODE ::= 0
ENUM_DATAMODE ::= 1
ENUM_ENTER_CONFMODE ::= 2
ENUM_CONFMODE ::= 3

// Answers enums
ENUM_NO_ANSWER ::= 1
ENUM_PARTIAL_ANSWER ::= 2
ENUM_COMPLETE_ANSWER ::= 3
ENUM_DATA_ANSWER ::= 4

// Baudrate settings
ENUM_BAUDRATE_460800 ::= 1
ENUM_BAUDRATE_921600 ::= 0
ENUM_BAUDRATE_230400 ::= 2
ENUM_BAUDRATE_115200 ::= 3
ENUM_BAUDRATE_57600 ::= 4
ENUM_BAUDRATE_38400 ::= 5
ENUM_BAUDRATE_28800 ::= 6
ENUM_BAUDRATE_19200 ::= 7
ENUM_BAUDRATE_14400 ::= 8
ENUM_BAUDRATE_9600 ::= 9
ENUM_BAUDRATE_4800 ::= 0xA
ENUM_BAUDRATE_2400 ::= 0xB


class RN4871:
  
  recMessage := ""
  antenna/serial.Port
  status/int := ENUM_DATAMODE
  answerLen/int := 0
  uartBuffer := []
  uartBufferLen := 10
  endStreamChar := PROMPT_LAST_CHAR

  rx_pin_/gpio.Pin
  tx_pin_/gpio.Pin
  reset_pin_/gpio.Pin
  bleAddress := []



  // UART constructor
  constructor --tx/gpio.Pin --rx/gpio.Pin --reset_pin/gpio.Pin --baud_rate/int:
    rx_pin_ = rx
    tx_pin_ = tx
    reset_pin_ = reset_pin
    antenna = serial.Port --tx=tx --rx=rx --baud_rate=baud_rate
    status = ENUM_DATAMODE
    answerLen = 0
    print "Device object created"
    
  // Reset
  reboot ->bool:
    reset_pin_.set 0
    sleep --ms=50
    reset_pin_.set 1
    answerOrTimeout
    if(popData == "%REBOOT%"):
      sleep --ms=INTERNAL_CMD_TIMEOUT*5
      print "Reboot successfull. Communication established properly"
      return true
    else:
      print "Reboot failure. Communication not established"
      return false

  popData -> string:
    result := recMessage
    recMessage = ""
    answerLen = 0
    return result
  
  readData -> string:
    return recMessage


  answerOrTimeout -> bool:
    with_timeout --ms=INTERNAL_CMD_TIMEOUT: 
      uartBuffer = antenna.read
      recMessage = uartBuffer.to_string.trim
      answerLen = recMessage.size
      return true

    return false

  startBLE userRA=null:
    if (this.enterConfigurationMode == false):
      return false

    if ((this.assignRandomAddress userRA) == false):
      return false

    if (this.enterDataMode == false):
      return false

    return true

  enterConfigurationMode ->bool:
    // Command mode
    sendData CONF_COMMAND
    answerOrTimeout
    
    if(popData == PROMPT):
      print "Command mode set up"
      setStatus ENUM_CONFMODE
      return true   
    else:
      print "Failed to set command mode"
      return false
  
  enterDataMode ->bool:
    setStatus ENUM_ENTER_DATMODE
    antenna.write EXIT_CONF
    
    return answerOrTimeout

  hasAnswer:
    uartBuffer = recMessage.to_byte_array
    
    if(status != ENUM_DATAMODE):
      if(uartBuffer.last == endStreamChar):
        validateAnswer
        return ENUM_COMPLETE_ANSWER
    else:
      return ENUM_DATA_ANSWER

    if (recMessage.size > uartBufferLen):
      return ENUM_PARTIAL_ANSWER

    return ENUM_NO_ANSWER

  factoryReset: 
    // if not in configuration mode enter immediately
    if(status != ENUM_CONFMODE):
      if(not enterConfigurationMode):
        return false
    
    rawConfiguration FACTORY_RESET
    return answerOrTimeout

  assignRandomAddress userRA ->bool:
    if(status == ENUM_CONFMODE):
      timeout := 0
      if(null == userRA):
        rawConfiguration AUTO_RANDOM_ADDRESS
      else:
        //Would be nice to be able to choose specific but they didn't have it in the original project either
        rawConfiguration AUTO_RANDOM_ADDRESS
      
      if(answerOrTimeout == true):
        setAddress popData.trim.to_byte_array
        return true
      else:
        return false

    else:
      return false

  sendData message/string:
    answerLen = 0 // Reset Answer Counter
    antenna.write message
    print "Message sent: $message" 

  setName newName:
    if(status != ENUM_CONFMODE):
      return false
    
    this.uartBuffer = SET_NAME + ", " + newName
    rawConfiguration(uartBuffer)

    return answerOrTimeout

  getName:
    if(status != ENUM_CONFMODE):
      return false
    rawConfiguration GET_NAME
    answerOrTimeout
    return popData

  getFwVersion:
    if(status != ENUM_CONFMODE):
      return false

    rawConfiguration(GET_FWVERSION)
    answerOrTimeout
    return popData

  getSwVersion:
    if(status != ENUM_CONFMODE):
      return false

    rawConfiguration GET_SWVERSION
    answerOrTimeout
    return popData

  getHwVersion:
    if(status != ENUM_CONFMODE):
      return false

    rawConfiguration GET_HWVERSION
    answerOrTimeout
    return popData

  setBaudRate param/int -> bool:
    if(status != ENUM_CONFMODE):
      return false

    rawConfiguration SET_BAUDRATE+",$param"
    return answerOrTimeout

  getBaudRate -> string:
    if(status != ENUM_CONFMODE):
      print "Error: Not in Configuration mode"
      return ""

    rawConfiguration GET_BAUDRATE
    answerOrTimeout
    return popData

  getSN -> string:
    if(status != ENUM_CONFMODE):
      print "Error: Not in Configuration mode"
      return ""

    rawConfiguration GET_SERIALNUM
    answerOrTimeout
    return popData

  setPowerSave powerSave/bool:
    // if not in configuration mode enter immediately
    if (status != ENUM_CONFMODE):
      if (not enterConfigurationMode):
        print "Error: Cannot enter Configuration mode"
        return ""

    // write command to buffer
    if (powerSave):
      uartBuffer = SET_POWERSAVE + ",$POWERSAVE_ENABLE"
    else:
      uartBuffer = SET_POWERSAVE + ",$POWERSAVE_DISABLE"

    rawConfiguration uartBuffer
    answerOrTimeout
    return popData
    
  getPowerSave:
    if (status != ENUM_CONFMODE):
        return false

    rawConfiguration GET_POWERSAVE
    result := answerOrTimeout

    recMessage = readData
    if(recMessage == PROMPT_ERROR):
      print "Error lol"
      return false

    return result

  rawConfiguration stream/string->none:
    answerLen = 0
    antenna.write (stream.trim+DATA_LAST_CHAR )

  validateAnswer:
    if (status == ENUM_ENTER_CONFMODE):
      if ((recMessage[0] == PROMPT_FIRST_CHAR) and (recMessage[recMessage.size-1] == PROMPT_LAST_CHAR)):
        setStatus ENUM_CONFMODE
        return true

    if (status == ENUM_ENTER_DATMODE):
      if ((recMessage[0] == PROMPT_FIRST_CHAR) and (recMessage[recMessage.size-1] == PROMPT_LAST_CHAR)):
        setStatus ENUM_DATAMODE
        return true

    return false


  setStatus statusToSet:


    if(ENUM_ENTER_DATMODE == statusToSet):
      print "Status set to: ENTER_DATMODE"
    else if (ENUM_DATAMODE == statusToSet):
      print "Status set to: DATAMODE"
    else if (ENUM_ENTER_CONFMODE == statusToSet):
      print "Status set to: ENTER_CONFMODE"
    else if (ENUM_CONFMODE == statusToSet):
      print "Status set to: CONFMODE"
    else:
      print "Error: Not able to update status. Mode: $statusToSet is unknown"
      return false
    
    status = statusToSet
    
    return true

  setAddress address:
    this.bleAddress  = address
    print "Address assigned to $address"
    return true
