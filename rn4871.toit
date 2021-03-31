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

DATA_LAST_CHAR ::= '\r'

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

class RN4871:
  
  recMessage := ""
  antenna/serial.Port
  status/int
  answerLen/int := 0
  uartBuffer := []
  uartBufferLen := 10
  endStreamChar := PROMPT_LAST_CHAR

  rx_pin_/gpio.Pin
  tx_pin_/gpio.Pin
  reset_pin_/gpio.Pin
  bleAddress := []


/*
private:
    boolean checkAnswer(const char *answer);
    char *uartBuffer;
    int uartBufferLen;
    RN4870StatusE status;
    char endStreamChar;
    char bleAddress[6];
*/
  
  



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
    recMessage = readData
    if(recMessage == "%REBOOT%"):
      print "Communication established properly. Message received:"
      print recMessage
      recMessage = ""   
      return true
    else:
      print "Communication not established, Message received"
      print recMessage
      recMessage = ""   
      return false

  readData -> string:
    return antenna.read.to_string.trim

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
    recMessage = readData
    print "elo"
    print recMessage
    if(recMessage == PROMPT):
      print "Command mode set up"
      return true   
    else:
      print "Failed to set command mode"
      return false
  
  enterDataMode ->bool:
    setStatus ENUM_ENTER_DATMODE
    antenna.write EXIT_CONF
    return true;

  hasAnswer:
    recMessage = antenna.read
    uartBuffer = recMessage
    
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
    return true

  assignRandomAddress userRA ->bool:
    if(status == ENUM_CONFMODE):
      timeout := 0
      if(null == userRA):
        rawConfiguration AUTO_RANDOM_ADDRESS
      else:
        //Would be nice to be able to choose specific but they didn't have it in the original project either
        rawConfiguration AUTO_RANDOM_ADDRESS
      
      if(answerOrTimeout == true):
        setAddress this.recMessage.trim.to_int
        return true
      else:
        return false

    else:
      return false

  sendData message/string:
    answerLen = 0 // Reset Answer Counter
    antenna.write message+"\n"
    print "Message sent: $message\n"

  setName newName:
    if(status != ENUM_CONFMODE):
      return false
    
    this.uartBuffer = SET_NAME + ", " + newName
    rawConfiguration(uartBuffer)

    return answerOrTimeout

  getName:
    if(status != ENUM_CONFMODE):
      return "Not in Configuration mode"
    print "I'm here"
    rawConfiguration GET_NAME
    result := antenna.read.to_string
    return result

  rawConfiguration stream/string->none:
    this.answerLen = 0
    this.antenna.write stream.trim+"\n" 

  validateAnswer:
    return true

  answerOrTimeout:
/*
      while ((this->hasAnswer()!=completeAnswer) && (INTERNAL_CMD_TIMEOUT>timeout)){
        delay(DELAY_INTERNAL_CMD);
        timeout++;
    }

    if (INTERNAL_CMD_TIMEOUT>timeout) {
        return true;
    } else {
        return false;
    }
}
*/
    return true 

  setStatus statusToSet:
    print "Set status to: $statusToSet"
    return true

  setAddress address:
    this.bleAddress  = address
    return true
