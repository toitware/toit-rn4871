// Copyright (C) 2021 Toitware ApS. All rights reserved.

// Driver for RN4871 bluetooth module

import binary
import serial.device
import serial.registers
import serial.ports.uart
import gpio
import .constants show *


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
  pinReboot ->bool:
    reset_pin_.set 0
    sleep --ms=50
    reset_pin_.set 1
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    if(result == REBOOT_EVENT):
      sleep --ms=INTERNAL_CMD_TIMEOUT
      print "Reboot successfull"
      return true
    else:
      print "Reboot failure"
      return false
  
  popData -> string:
    result := recMessage
    recMessage = ""
    answerLen = 0
    return result
  
  readData -> string:
    return recMessage


  answerOrTimeout --timeout=INTERNAL_CMD_TIMEOUT-> bool:
    exception := catch: 
      with_timeout --ms=timeout: 
        uartBuffer = antenna.read
        recMessage = uartBuffer.to_string.trim
        answerLen = recMessage.size
    
    if(exception != null):  
      print "Exception raised: Answer timeout"
      return false

    return true
    

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
    setStatus ENUM_ENTER_CONFMODE
    sendData CONF_COMMAND
    result := readForTime --ms=INTERNAL_CMD_TIMEOUT
    if(result == PROMPT or result == "CMD"):
      print "Command mode set up"
      setStatus ENUM_CONFMODE
      return true   
    else:
      print "Failed to set command mode"
      return false
  
  enterDataMode ->bool:
    setStatus ENUM_ENTER_DATMODE
    antenna.write EXIT_CONF
    result := answerOrTimeout --timeout=STATUS_CHANGE_TIMEOUT
    if readData == PROMPT_END:
      setStatus ENUM_DATAMODE
    return result


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
    sendCommand FACTORY_RESET
    result := (answerOrTimeout --timeout=STATUS_CHANGE_TIMEOUT)
    sleep --ms=STATUS_CHANGE_TIMEOUT
    return result

  assignRandomAddress userRA ->bool:
    if(status == ENUM_CONFMODE):
      timeout := 0
      if(null == userRA):
        sendCommand AUTO_RANDOM_ADDRESS
      else:
        //Would be nice to be able to choose specific but they didn't have it in the original project either
        sendCommand AUTO_RANDOM_ADDRESS
      
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

    if newName.size > MAX_DEVICE_NAME_LEN:
      print "Error: The name is too long"
      return false
    this.uartBuffer = SET_NAME + newName
    sendCommand(uartBuffer)
    result := answerOrTimeout
    if(popData != AOK_RESP):
      result = false
    answerOrTimeout
    return result

  getName:
    if(status != ENUM_CONFMODE):
      return "Error: Not in the CONFMODE"
    sendCommand GET_DEVICE_NAME
    answerOrTimeout
    actualResult := extractResult popData
    return actualResult
  
  extractResult name/string="" lis/List=[] firstIteration=true-> string:
    if firstIteration:
      if name == "":
        return name
      tempList := name.split "\n"
      tempList.map:
        lis = lis + (it.split " ")
    if lis == []:
      return ""
        
    elem := lis.remove_last.trim
    if  (elem != "CMD>" and elem != "," and elem !=""):
      return elem
    return extractResult "" lis false

  getFwVersion:
    if(status != ENUM_CONFMODE):
      return false

    sendCommand DISPLAY_FW_VERSION
    answerOrTimeout
    result := popData
    return result

  getSwVersion:
    if(status != ENUM_CONFMODE):
      return false

    sendCommand GET_SWVERSION
    answerOrTimeout
    result := popData
    return result

  getHwVersion:
    if(status != ENUM_CONFMODE):
      return false

    sendCommand GET_HWVERSION
    answerOrTimeout
    result := popData
    return result

  setBaudRate param/int -> bool:
    if(status != ENUM_CONFMODE):
      return false

    sendCommand SET_BAUDRATE+",$param"
    return answerOrTimeout

  getBaudRate -> string:
    if(status != ENUM_CONFMODE):
      print "Error: Not in Configuration mode"
      return ""

    sendCommand GET_BAUDRATE
    answerOrTimeout
    result := popData
    return result

  getSN -> string:
    if(status != ENUM_CONFMODE):
      print "Error: Not in Configuration mode"
      return ""

    sendCommand GET_SERIALNUM
    answerOrTimeout
    result := popData
    return result

  setPowerSave powerSave/bool:
    // if not in configuration mode enter immediately
    if (status != ENUM_CONFMODE):
      if (not enterConfigurationMode):
        print "Error: Cannot enter Configuration mode"
        return ""

    // write command to buffer
    if (powerSave):
      sendCommand SET_LOW_POWER_ON
      print "Low power ON"
    else:
      sendCommand SET_LOW_POWER_OFF
      print "Low power OFF"

    result := answerOrTimeout
    return result
  
  getConStatus -> string:
    if(status != ENUM_CONFMODE):
      print "Error: Not in Configuration mode"
      return ""

    sendCommand GET_CONNECTION_STATUS
    answerOrTimeout
    result := popData
    return result

  getPowerSave:
    if (status != ENUM_CONFMODE):
        return false

    sendCommand GET_POWERSAVE
    answerOrTimeout
    recMessage = popData
    return recMessage

  sendCommand stream/string->none:
    answerLen = 0
    antenna.write (stream.trim+CR )

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

  setBeaconFeatures value:
    is_correct := false
    catch:
      try:
        value = value.to_string
      finally:
        [BEACON_OFF, BEACON_ON, BEACON_ADV_ON].do:
          if (it == value):
            is_correct = true
    
    if(is_correct == false):
      print "Error: Value: $value is not in beacon commands set"
      return false
    
    sendCommand SET_BEACON_FEATURES+value
    answerOrTimeout
    if readData == AOK_RESP:
      return true
    else:
      return false


  getSettings addr/string -> string:
    uartBuffer = GET_SETTINGS + addr
    sendCommand uartBuffer
    answerOrTimeout
    return popData

  setSettings addr/string value/string:
    // Manual insertion of settings
    uartBuffer = SET_SETTINGS + addr + "," + value
    sendCommand uartBuffer
    answerOrTimeout
    result := popData
    result = extractResult result
    print "setSettings response: $result"
    if result == AOK_RESP:
      return true
    else:
      return false
  
  setAdvPower value/int:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT

    sendCommand SET_ADV_POWER + "$value"
    answerOrTimeout
    result := extractResult popData
    if result == AOK_RESP:
      return true
    else:
      return false

  setConnPower value/int:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT

    sendCommand SET_CONN_POWER + "$value"
    answerOrTimeout
    result := extractResult popData
    if result == AOK_RESP:
      return true
    else:
      return false


// *********************************************************************************
// Set the module to Dormant
// *********************************************************************************
// Immediately forces the device into lowest power mode possible.
// Removing the device from Dormant mode requires power reset.
// Input : void
// Output: bool true if successfully executed
// *********************************************************************************
  dormantMode -> none:
    print "[dormantMode]"
    sendCommand(SET_DORMANT_MODE)
    sleep --ms=INTERNAL_CMD_TIMEOUT

  readForTime --ms/int=INTERNAL_CMD_TIMEOUT ->string:
    dur := Duration --ms=ms
    start := Time.now
    result := ""
    while (start.to_now < dur ):
      answerOrTimeout
      result = result + popData
    return result

  devInfo -> string:
    sendCommand GET_DEVICE_INFO
    result := readForTime
    return result

  setSupFeatures value:
    is_correct := false
    [FEATURE_NO_BEACON_SCAN, FEATURE_NO_CONNECT_SCAN, FEATURE_NO_DUPLICATE_SCAN, FEATURE_PASSIVE_SCAN, FEATURE_UART_TRANSP_NO_ACK, FEATURE_MLDP_SUPPORT].do:
      if (it == value):
        is_correct = true
        
    if(is_correct == false):
      print "Error: Value: $value is not in supported features set"
      return false
    sendCommand SET_SUPPORTED_FEATURES+value
    answerOrTimeout
    if popData == AOK_RESP:
      return true
    else:
      return false

  setDefServices value:
    is_correct := false
    [SERVICE_NO_SERVICE, SERVICE_DEVICE_INFO_SERVICE, SERVICE_UART_TRANSP_SERVICE, SERVICE_BEACON_SERVICE, SERVICE_AIRPATCH_SERVICE].do:
      if (it == value):
        is_correct = true
        
    if(is_correct == false):
      print "Error: Value: $value is not a default service"
      return false
    sendCommand SET_DEFAULT_SERVICES+value
    answerOrTimeout
    if popData == AOK_RESP:
      return true
    else:
      return false

  listenToUart --ms/int=INTERNAL_CMD_TIMEOUT -> none:
    dur := Duration --ms=ms
    start := Time.now
    print "Begin to listen to UART\n"
    while (start.to_now < dur ):
      antenna.write "test"
      exception := catch: 
        with_timeout --ms=ms: 
          uartBuffer = antenna.read
          recMessage = uartBuffer.to_string.trim  
      if(exception != null):  
        //
      else:
        print popData
  
  // *********************************************************************************
  // Clear all services
  // *********************************************************************************
  // Clears all settings of services and characteristics.
  // A power cycle is required afterwards to make the changes effective.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearAllServices:
    print "[cleanAllServices]"
    sendCommand(CLEAR_ALL_SERVICES)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

  // *********************************************************************************
  // Start Advertisement
  // *********************************************************************************
  // The advertisement is undirect connectable.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  startAdvertising:
    print "[startAdvertising]"
    sendCommand(START_DEFAULT_ADV)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

  // *********************************************************************************
  // Stops Advertisement
  // *********************************************************************************
  // Stops advertisement started by the startAdvertising method.
  // Input : void
  // Output: bool true if successfully executed
  //*********************************************************************************
  stopAdvertising:
    print "[stopAdvertising]"
    sendCommand(STOP_ADV)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

  // *********************************************************************************
  // Clear the advertising structure Immediately
  // *********************************************************************************
  // Make the changes immediately effective without a reboot.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearImmediateAdvertising:
    print "[clearImmediateAdvertising]"
    sendCommand(CLEAR_IMMEDIATE_ADV)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

  // *********************************************************************************
  // Clear the advertising structure in a permanent way
  // *********************************************************************************
  // The changes are saved into NVM only if other procedures require permanent
  // configuration changes. A reboot is requested after executing this method.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearPermanentAdvertising:
    print "[clearPermanentAdvertising]"
    sendCommand(CLEAR_PERMANENT_ADV)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

  // *********************************************************************************
  // Clear the Beacon structure Immediately
  // *********************************************************************************
  // Make the changes immediately effective without a reboot.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearImmediateBeacon:
    print "[clearImmediateBeacon]"
    sendCommand(CLEAR_IMMEDIATE_BEACON)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

// *********************************************************************************
// Clear the Beacon structure in a permanent way
// *********************************************************************************
// The changes are saved into NVM only if other procedures require permanent
// configuration changes. A reboot is requested after executing this method.
// Input : void
// Output: bool true if successfully executed
// *********************************************************************************
  clearPermanentBeacon:
    print "[clearPermanentBeacon]"
    sendCommand(CLEAR_PERMANENT_BEACON)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false


  // *********************************************************************************
  // Start Advertising immediatly
  // *********************************************************************************
  // Input : uint8_t adType  Bluetooth SIG defines AD types in the assigned number list
  //         in the Core Specification
  //         const char adData[] has various lengths and follows the format defined
  //         by Bluetooth SIG Supplement to the Bluetooth Core specification
  // Output: bool true if successfully executed
  // *********************************************************************************

  startImmediateAdvertising adType/string adData/string ->bool:    
    typeName := ""
    AD_TYPES.filter:
      if AD_TYPES[it] == adType:
        typeName = it

    if typeName == "":
      print "startImmediateAdvertising failed: adType $adType is not one of accepted types"
      return false

    print "[startImmediateAdvertising]: type $typeName, data $adData "
    sendCommand(START_IMMEDIATE_ADV+adType+","+adData)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

// *********************************************************************************
// Start Advertising permanently
// *********************************************************************************
// A reboot is needed after issuing this method
// Input : uint8_t adType  Bluetooth SIG defines AD types in the assigned number list
//         in the Core Specification
//         const char adData[] has various lengths and follows the format defined
//         by Bluetooth SIG Supplement to the Bluetooth Core specification
// Output: bool true if successfully executed
// *********************************************************************************
  startPermanentAdvertising adType/string adData/string ->bool:    
    typeName := ""
    AD_TYPES.filter:
      if AD_TYPES[it] == adType:
        typeName = it

    if typeName == "":
      print "startPermanentAdvertising failed: adType $adType is not one of accepted types"
      return false

    print "[startPermanentAdvertising]: type $typeName, data $adData "
    sendCommand(START_PERMANENT_ADV+adType+","+adData)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

// *********************************************************************************
// Start Beacon adv immediatly
// *********************************************************************************
// Input : uint8_t adType  Bluetooth SIG defines AD types in the assigned number list
//         in the Core Specification
//         const char adData[] has various lengths and follows the format defined
//         by Bluetooth SIG Supplement to the Bluetooth Core specification
// Output: bool true if successfully executed
// *********************************************************************************

  startImmediateBeacon adType/string adData/string ->bool:    
    typeName := ""
    AD_TYPES.filter:
      if AD_TYPES[it] == adType:
        typeName = it

    if typeName == "":
      print "startImmediateBeacon failed: adType $adType is not one of accepted types"
      return false

    print "[startImmediateBeacon]: type $typeName, data $adData "
    sendCommand(START_IMMEDIATE_BEACON+adType+","+adData)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

// *********************************************************************************
// Start Beacon adv permanently
// *********************************************************************************
// A reboot is needed after issuing this method
// Input : uint8_t adType  Bluetooth SIG defines AD types in the assigned number list
//         in the Core Specification
//         const char adData[] has various lengths and follows the format defined
//         by Bluetooth SIG Supplement to the Bluetooth Core specification
// Output: bool true if successfully executed
// *********************************************************************************

  startPermanentBeacon adType/string adData/string ->bool:    
    typeName := ""
    AD_TYPES.filter:
      if AD_TYPES[it] == adType:
        typeName = it

    if typeName == "":
      print "startPermanentBeacon failed: adType $adType is not one of accepted types"
      return false

    print "[startPermanentBeacon]: type $typeName, data $adData "
    sendCommand(START_PERMANENT_BEACON+adType+","+adData)
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    print result
    if result == AOK_RESP:
      return true
    else:
      return false

// *********************************************************************************
// Start Scanning
// *********************************************************************************
// Method available only when the module is set as a Central (GAP) device and is
// ready for scan before establishing connection.
// By default, scan interval of 375 milliseconds and scan window of 250 milliseconds
// Use stopScanning() method to stop an active scan
// The user has the option to specify the scan interval and scan window as first 
// and second parameter, respectively. Each unit is 0.625 millisecond. Scan interval
// must be larger or equal to scan window. The scan interval and the scan window
// values can range from 2.5 milliseconds to 10.24 seconds.
// Input1 : void
// or
// Input2 : uint16_t scan interval value (must be >= scan window)
//         uint16_t scan window value
// Output: bool true if successfully executed
// *********************************************************************************
  startScanning --scanInterval/int=0 --scanWindow/int=0:
    if(scanInterval*scanWindow != 0):
      print "[startScanning] Custom scanning"
      sendCommand "$START_CUSTOM_SCAN$scanInterval,$scanWindow"
    else:
      print "[startScanning] Default scanning"
      sendCommand START_DEFAULT_SCAN
    
    answerOrTimeout
    if popData == SCANNING_RESP:
      return true
    else:
      return false