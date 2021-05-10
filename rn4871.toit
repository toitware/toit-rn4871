// Copyright (C) 2021 Toitware ApS. All rights reserved.

// Driver for RN4871 bluetooth module

import binary
import serial.device
import serial.registers
import serial.ports.uart
import gpio
import .constants show *
import encoding.hex


class RN4871:
  
  recMessage := ""
  antenna/serial.Port
  status/int := ENUM_DATAMODE
  answerLen/int := 0
  uartBuffer := []
  rx_pin_/gpio.Pin
  tx_pin_/gpio.Pin
  reset_pin_/gpio.Pin
  bleAddress := []
  debug := false

  // UART constructor
  constructor --tx/gpio.Pin --rx/gpio.Pin --reset_pin/gpio.Pin --baud_rate/int --debug_mode/bool=false:
    rx_pin_ = rx
    tx_pin_ = tx
    reset_pin_ = reset_pin
    antenna = serial.Port --tx=tx --rx=rx --baud_rate=baud_rate
    status = ENUM_DATAMODE
    answerLen = 0
    debug = debug_mode
    print "Device object created"

// ---------------------------------------Utility Methods ----------------------------------------

  lookupKey paramsMap/Map param/any -> string:
    paramsMap.do:
      if paramsMap[it] == param:
        return it
    return ""
    
  convertWordToHexString input/string -> string:
    output := ""
    input.to_byte_array.do:
      //output += convertNumberToHexString it
      output += it.stringify 16
    return output

  expectedResult resp/string --ms=INTERNAL_CMD_TIMEOUT -> bool:
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    return result == resp

  debugPrint text/string:
    if (debug == true):
      print text

  readForTime --ms/int=INTERNAL_CMD_TIMEOUT ->string:
    dur := Duration --ms=ms
    start := Time.now
    result := ""
    while start.to_now < dur:
      answerOrTimeout
      result = result + popData
    return result

  listenToUart --ms/int=INTERNAL_CMD_TIMEOUT -> none:
    dur := Duration --ms=ms
    start := Time.now
    print "Begin listening to UART\n"
    while start.to_now < dur:
      exception := catch: 
        with_timeout --ms=ms: 
          uartBuffer = antenna.read
          recMessage = uartBuffer.to_string.trim  
      if(exception == null):  
        print popData

  popData -> string:
    result := recMessage
    recMessage = ""
    answerLen =0
    return result
  
  readData -> string:
    return recMessage

  answerOrTimeout --timeout=INTERNAL_CMD_TIMEOUT-> bool:
    exception := catch: 
      with_timeout --ms=timeout: 
        uartBuffer = antenna.read
        recMessage = uartBuffer.to_string.trim
        answerLen = recMessage.size
    
    if exception != null:  
      return false

    return true

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
    if  elem != "CMD>" and elem != "," and elem !="":
      return elem
    return extractResult "" lis false

  sendData message/string:
    answerLen = 0 // Reset Answer Counter
    antenna.write message
    print "Message sent: $message" 

  sendCommand stream/string->none:
    answerLen = 0
    antenna.write (stream.trim+CR)

  validateAnswer:
    if status == ENUM_ENTER_CONFMODE:
      if recMessage[0] == PROMPT_FIRST_CHAR and recMessage[recMessage.size-1] == PROMPT_LAST_CHAR:
        setStatus ENUM_CONFMODE
        return true

    if status == ENUM_ENTER_DATMODE:
      if recMessage[0] == PROMPT_FIRST_CHAR and recMessage[recMessage.size-1] == PROMPT_LAST_CHAR:
        setStatus ENUM_DATAMODE
        return true
    return false

  setStatus statusToSet:
    if ENUM_ENTER_DATMODE == statusToSet:
      print "[setStatus]Status set to: ENTER_DATMODE"
    else if ENUM_DATAMODE == statusToSet:
      print "[setStatus]Status set to: DATAMODE"
    else if ENUM_ENTER_CONFMODE == statusToSet:
      print "[setStatus]Status set to: ENTER_CONFMODE"
    else if ENUM_CONFMODE == statusToSet:
      print "[setStatus]Status set to: CONFMODE"
    else:
      print "Error [setStatus]: Not able to update status. Mode: $statusToSet is unknown"
      return false
    status = statusToSet
    return true

  setAddress address:
    bleAddress  = address
    debugPrint "[setAddress] Address assigned to $address"
    return true

  validateInputHexData data/string -> bool:
    range := [[48, 57], [65, 70], [97, 102]]
    char := ""
    out_of_range := true
    data.do:
      char = it
      out_of_range = true
      range.do:
        if it[0] <= char and char <= it[1]:
          out_of_range = false
      if out_of_range:
        return false
    return true

// ---------------------------------------- Public section ----------------------------------------    
    
  // Reset
  pinReboot ->bool:
    reset_pin_.set 0
    sleep --ms=50
    reset_pin_.set 1
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    if result == REBOOT_EVENT:
      sleep --ms=STATUS_CHANGE_TIMEOUT
      print "[pinReboot] Reboot successfull"
      return true
    else:
      print "[pinReboot] Reboot failure"
      return false    

  startBLE userRA=null:
    if enterConfigurationMode == false:
      return false

    if assignRandomAddress userRA == false:
      return false

    if enterDataMode == false:
      return false

    return true

  enterConfigurationMode ->bool:
    // Command mode
    setStatus ENUM_ENTER_CONFMODE
    sendData CONF_COMMAND
    result := readForTime --ms=STATUS_CHANGE_TIMEOUT
    if result == PROMPT or result == "CMD":
      print "[enterConfigurationMode] Command mode set up"
      setStatus ENUM_CONFMODE
      return true   
    else:
      print "[enterConfigurationMode] Failed to set command mode"
      return false
  
  enterDataMode ->bool:
    setStatus ENUM_ENTER_DATMODE
    antenna.write EXIT_CONF
    result := answerOrTimeout --timeout=STATUS_CHANGE_TIMEOUT
    if readData == PROMPT_END:
      setStatus ENUM_DATAMODE
    return result

  factoryReset: 
    // if not in configuration mode enter immediately
    if status != ENUM_CONFMODE:
      if not enterConfigurationMode:
        return false
    sendCommand FACTORY_RESET
    result := answerOrTimeout --timeout=STATUS_CHANGE_TIMEOUT
    sleep --ms=STATUS_CHANGE_TIMEOUT
    return result

  assignRandomAddress userRA=null ->bool:
    if status == ENUM_CONFMODE:
      timeout := 0
      if null == userRA:
        sendCommand AUTO_RANDOM_ADDRESS
      else:
        sendCommand AUTO_RANDOM_ADDRESS
      
      if answerOrTimeout == true:
        setAddress popData.trim.to_byte_array
        return true
      else:
        return false
    else:
      return false

  setName newName:
    if status != ENUM_CONFMODE:
      return false

    if newName.size > MAX_DEVICE_NAME_LEN:
      print "Error [setName]: The name is too long"
      return false
    sendCommand SET_NAME + newName
    return expectedResult AOK_RESP

  getName:
    if status != ENUM_CONFMODE:
      return "Error [getName]: Not in the CONFMODE"
    sendCommand GET_DEVICE_NAME
    return extractResult readForTime

  getFwVersion:
    if status != ENUM_CONFMODE:
      return false

    sendCommand DISPLAY_FW_VERSION
    answerOrTimeout
    return popData

  getSwVersion:
    if status != ENUM_CONFMODE:
      return false

    sendCommand GET_SWVERSION
    answerOrTimeout
    return popData

  getHwVersion:
    if status != ENUM_CONFMODE:
      return false

    sendCommand GET_HWVERSION
    answerOrTimeout
    return popData

  // *********************************************************************************
  // Set UART communication baudrate
  // *********************************************************************************
  // Selects the UART communication baudrate from the list of available settings.
  // Input : value from BAUDRATE map
  // Output: bool true if successfully executed
  // *********************************************************************************
  setBaudRate param/string -> bool:
    if status != ENUM_CONFMODE:
      return false    
    setting := lookupKey BAUDRATES param

    if setting == "":
      print "Error: Value: $param is not in BAUDRATE commands set"
      return false
    debugPrint "[setBaudRate]: The baudrate is being set to $setting with the command: $SET_BAUDRATE$param"
    sendCommand "$SET_BAUDRATE$param"
    return expectedResult AOK_RESP

  getBaudRate -> string:
    if status != ENUM_CONFMODE:
      print "Error: Not in Configuration mode"
      return ""

    sendCommand GET_BAUDRATE
    answerOrTimeout
    return popData

  getSN -> string:
    if status != ENUM_CONFMODE:
      print "Error [getSN]: Not in Configuration mode"
      return ""

    sendCommand GET_SERIALNUM
    answerOrTimeout
    return popData

  setPowerSave powerSave/bool:
    // if not in configuration mode enter immediately
    if status != ENUM_CONFMODE:
      if not enterConfigurationMode:
        print "Error [setPowerSave]: Cannot enter Configuration mode"
        return ""

    // write command to buffer
    if powerSave:
      sendCommand SET_LOW_POWER_ON
      print "[setPowerSave] Low power ON"
    else:
      sendCommand SET_LOW_POWER_OFF
      print "[setPowerSave] Low power OFF"

    result := answerOrTimeout
    return result
  
  getConStatus -> string:
    if status != ENUM_CONFMODE:
      print "Error [getConStatus]: Not in Configuration mode"
      return ""

    sendCommand GET_CONNECTION_STATUS
    answerOrTimeout
    return popData

  getPowerSave:
    if status != ENUM_CONFMODE:
        return false
    sendCommand GET_POWERSAVE
    answerOrTimeout
    return popData

  devInfo -> string:
    sendCommand GET_DEVICE_INFO
    return readForTime

  // *********************************************************************************
  // Set supported features
  // *********************************************************************************
  // Selects the features that are supported by the device
  // Input : string value from FEATURES map
  // Output: bool true if successfully executed
  // *********************************************************************************
  setSupFeatures feature/string:
    key := lookupKey FEATURES feature
    if key == "":
      print "Error [setSupFeatures]: Feature: $feature is not in supported features set"
      return false
    debugPrint "[setSupFeatures]: The supported feature $key is set with the command: $SET_SUPPORTED_FEATURES$feature"
    sendCommand SET_SUPPORTED_FEATURES+feature
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Set default services
  // *********************************************************************************
  // This command sets the default services to be supported by the RN4870 in the GAP
  // server role.
  // Input : string value from SERVICES map
  // Output: bool true if successfully executed
  // *********************************************************************************
  setDefServices service:
    key := lookupKey SERVICES service
    if key == "":
      print "Error [setDefServices]: Value: $service is not a default service"
      return false
    debugPrint "[setDefServices]: The default service $key is set with the command: $SET_DEFAULT_SERVICES$service"
    sendCommand SET_DEFAULT_SERVICES+service
    return expectedResult AOK_RESP
  
  // *********************************************************************************
  // Clear all services
  // *********************************************************************************
  // Clears all settings of services and characteristics.
  // A power cycle is required afterwards to make the changes effective.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearAllServices:
    debugPrint "[cleanAllServices]"
    sendCommand CLEAR_ALL_SERVICES
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Start Advertisement
  // *********************************************************************************
  // The advertisement is undirect connectable.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  startAdvertising:
    debugPrint "[startAdvertising]"
    sendCommand(START_DEFAULT_ADV)
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Stops Advertisement
  // *********************************************************************************
  // Stops advertisement started by the startAdvertising method.
  // Input : void
  // Output: bool true if successfully executed
  //*********************************************************************************
  stopAdvertising:
    debugPrint "[stopAdvertising]"
    sendCommand(STOP_ADV)
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Clear the advertising structure Immediately
  // *********************************************************************************
  // Make the changes immediately effective without a reboot.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearImmediateAdvertising:
    debugPrint "[clearImmediateAdvertising]"
    sendCommand(CLEAR_IMMEDIATE_ADV)
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Clear the advertising structure in a permanent way
  // *********************************************************************************
  // The changes are saved into NVM only if other procedures require permanent
  // configuration changes. A reboot is requested after executing this method.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearPermanentAdvertising:
    debugPrint "[clearPermanentAdvertising]"
    sendCommand CLEAR_PERMANENT_ADV
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Clear the Beacon structure Immediately
  // *********************************************************************************
  // Make the changes immediately effective without a reboot.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearImmediateBeacon:
    debugPrint "[clearImmediateBeacon]"
    sendCommand CLEAR_IMMEDIATE_BEACON
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Clear the Beacon structure in a permanent way
  // *********************************************************************************
  // The changes are saved into NVM only if other procedures require permanent
  // configuration changes. A reboot is requested after executing this method.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearPermanentBeacon:
    debugPrint "[clearPermanentBeacon]"
    sendCommand CLEAR_PERMANENT_BEACON
    return expectedResult AOK_RESP


  // *********************************************************************************
  // Start Advertising immediatly
  // *********************************************************************************
  // Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string adData is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  startImmediateAdvertising adType/string adData/string ->bool:    
    typeName := lookupKey AD_TYPES adType
    if typeName == "":
      print "Error [startImmediateAdvertising]: adType $adType is not one of accepted types"
      return false
    debugPrint "[startImmediateAdvertising]: type $typeName, data $adData "
    adData = convertWordToHexString adData
    debugPrint "Send command: $START_IMMEDIATE_ADV$adType,$adData"
    sendCommand "$START_IMMEDIATE_ADV$adType,$adData"
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Start Advertising permanently
  // *********************************************************************************
  // A reboot is needed after issuing this method
  // Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string adData is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  startPermanentAdvertising adType/string adData/string ->bool:    
    typeName := lookupKey AD_TYPES adType
    if typeName == "":
      print "Error [startImmediateAdvertising]: adType $adType is not one of accepted types"
      return false
    debugPrint "[startPermanentAdvertising]: type $typeName, data $adData "
    adData = convertWordToHexString adData
    debugPrint "Send command: $START_PERMANENT_ADV$adType,$adData"
    sendCommand "$START_PERMANENT_ADV$adType,$adData"
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Start Beacon adv immediatly
  // *********************************************************************************
  // Input : Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string adData is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  startImmediateBeacon adType/string adData/string ->bool:
    typeName := lookupKey AD_TYPES adType
    if typeName == "":
      print "Error [startImmediateBeacon]: adType $adType is not one of accepted types"
      return false
    debugPrint "[startImmediateBeacon]: type $typeName, data $adData "
    adData = convertWordToHexString adData
    debugPrint "Send command: $START_IMMEDIATE_BEACON$adType,$adData"
    sendCommand "$START_IMMEDIATE_BEACON$adType,$adData"    
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Start Beacon adv permanently
  // *********************************************************************************
  // A reboot is needed after issuing this method
  // Input : Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string adData is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  startPermanentBeacon adType/string adData/string ->bool:
    typeName := lookupKey AD_TYPES adType
    if typeName == "":
      print "Error [startPermanentBeacon]: adType $adType is not one of accepted types"
      return false
    debugPrint "[startPermanentBeacon]: type $typeName, data $adData "
    adData = convertWordToHexString adData
    debugPrint "Send command: $START_PERMANENT_BEACON$adType,$adData"
    sendCommand "$START_PERMANENT_BEACON$adType,$adData" 
    return expectedResult AOK_RESP

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
  // Input2 : int scan interval value (must be >= scan window)
  //          int scan window value
  // Output: bool true if successfully executed
  // *********************************************************************************
  startScanning --scanInterval_ms/int=0 --scanWindow_ms/int=0 -> bool:
    if scanInterval_ms*scanWindow_ms != 0:
      values := [2.5, scanInterval_ms, scanInterval_ms, 1024].sort

      if values.first == 2.5 and values.last == 1024:
        scanInterval :=  (scanInterval_ms / 0.625).to_int.stringify 16
        scanWindow :=  (scanWindow_ms / 0.625).to_int.stringify 16
        debugPrint "[startScanning] Custom scanning\nSend Command: $START_CUSTOM_SCAN$scanInterval,$scanWindow"
        sendCommand "$START_CUSTOM_SCAN$scanInterval,$scanWindow"
      else:
        print "Error [startScanning]: input values out of range"
    else:
      debugPrint "[startScanning] Default scanning"
      sendCommand START_DEFAULT_SCAN
    return expectedResult SCANNING_RESP

  // *********************************************************************************
  // Stop Scanning
  // *********************************************************************************
  // Stops scan process started by startScanning() method
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  stopScanning -> bool:
    debugPrint "[stopScanning]"
    sendCommand STOP_SCAN
    return expectedResult AOK_RESP

  
  // *********************************************************************************
  // Add a MAC address to the white list
  // *********************************************************************************
  // Once one device is added to the white list, the white list feature is enabled.
  // With the white list feature enabled, when performing a scan, any device not
  // included in the white list does not appear in the scan results.
  // As a peripheral, any device not listed in the white list cannot be connected
  // with a local device. RN4870/71 supports up to 16 addresses in the white list.
  // A random address stored in the white list cannot be resolved. If the peer 
  // device does not change the random address, it is valid in the white list. 
  // If the random address is changed, this device is no longer considered to be on 
  // the white list.
  // Input : string addrType = 0 if following address is public (=1 for private)
  //         string addr 6-byte address in hex format
  // Output: bool true if successfully executed
  // *********************************************************************************

  addMacAddrWhiteList --addrType/string --adData/string ->bool:    
    [PUBLIC_ADDRESS_TYPE, PRIVATE_ADDRESS_TYPE].do:
      if it == addrType:
        debugPrint "[addMacAddrWhiteList]: Send Command: $ADD_WHITE_LIST$addrType,$adData"
        sendCommand "$ADD_WHITE_LIST$addrType,$adData"
        return expectedResult AOK_RESP
      else:
        print "Error [addMacAddrWhiteList]: received faulty input, $ADD_WHITE_LIST$addrType,$adData"
    return false
      
  // *********************************************************************************
  // Add all currently bonded devices to the white list
  // *********************************************************************************
  // The random address in the white list can be resolved with this method for 
  // connection purpose. If the peer device changes its resolvable random address, 
  // the RN4870/71 is still able to detect that the different random addresses are 
  // from the same physical device, therefore, allows connection from such peer 
  // device. This feature is particularly useful if the peer device is a iOS or 
  // Android device which uses resolvable random.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  addBondedWhiteList:
    debugPrint "[addBondedWhiteList]"
    sendCommand ADD_BONDED_WHITE_LIST
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Clear the white list
  // *********************************************************************************
  // Once the white list is cleared, white list feature is disabled.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clearWhiteList:
    debugPrint "[clearWhiteList]"
    sendCommand CLEAR_WHITE_LIST
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Kill the active connection
  // *********************************************************************************
  // Disconnect the active BTLE link. It can be used in central or peripheral role.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  killConnection:
    debugPrint "[killConnection]"
    sendCommand KILL_CONNECTION
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Get the RSSI level
  // *********************************************************************************
  // Get the signal strength in dBm of the last communication with the peer device. 
  // The signal strength is used to estimate the distance between the device and its
  // remote peer.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  getRSSI -> string:
    debugPrint "[getRSSI]"
    sendCommand GET_RSSI_LEVEL
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    debugPrint "Received RSSI is: $result"
    return result

  // *********************************************************************************
  // Reboot the module
  // *********************************************************************************
  // Forces a complete device reboot (similar to a power cycle).
  // After rebooting RN487x, all prior made setting changes takes effect.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  reboot -> bool:
    debugPrint "[reboot]"
    sendCommand REBOOT
    if expectedResult REBOOTING_RESP:
      sleep --ms=STATUS_CHANGE_TIMEOUT
      debugPrint "[reboot] Software reboot succesful"
      return true
    else:
      sleep --ms=STATUS_CHANGE_TIMEOUT
      debugPrint "[reboot] Software reboot failed"
      return false

  // *********************************************************************************
  // Sets the service UUID
  // *********************************************************************************
  // Sets the UUID of the public or the private service.
  // This method must be called before the setCharactUUID() method.
  // 
  // Input : string uuid containing hex ID
  //         can be either a 16-bit UUID for public service
  //         or a 128-bit UUID for private service
  // Output: bool true if successfully executed
  // *********************************************************************************
  setServiceUUID uuid/string -> bool:
    if not validateInputHexData uuid:
      print "Error [setServiceUUID]: $uuid is not a valid hex value"
      return false
    if (uuid.size == PRIVATE_SERVICE_LEN):
      debugPrint("[setServiceUUID]: Set public UUID")
    else if (uuid.size == PUBLIC_SERVICE_LEN):
      debugPrint("[setServiceUUID]: Set private UUID")
    else:
      print("Error [setServiceUUID]: received wrong UUID length. Should be 16 or 128 bit hexidecimal number\nExample: PS,010203040506070809000A0B0C0D0E0F")
      return false
    debugPrint "[setServiceUUID] Send command: $DEFINE_SERVICE_UUID$uuid"  
    sendCommand "$DEFINE_SERVICE_UUID$uuid"  
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Sets the private characteristic.
  // *********************************************************************************
  // Command PC must be called after service UUID is set by command PS.“PS,<hex16/hex128>” 
  // for command PS. If service UUID is set to be a 16-bit public UUID in command PS, 
  // then the UUID input parameter for command PC must also be a 16-bit public UUID. 
  // Similarly, if service UUID is set to be a 128-bit privateUUID by command PS, 
  // then the UUID input parameter must also be a 128-bit private UUID by command PC. 
  // Calling this command adds one characteristic to the service at
  // a time. Calling this command later does not overwrite the previous settings, but adds
  // another characteristic instead.
  // *********************************************************************************
  // Input : string uuid:
  //         can be either a 16-bit UUID for public service
  //         or a 128-bit UUID for private service
  //         list propertyList:
  //         is a list of hex values from CHAR_PROPS map, they can be put
  //         in any order 
  //         octetLenInt is an integer value that indicates the maximum data size
  //         in octet where the value of the characteristics holds in the range
  //         from 1 to 20 (0x01 to 0x14)
  //         *string propertyHex:
  //         can be used instead of the list by inputing the hex value directly (not recommended)
  //         *string ocetetLenHex:
  //         can be used instead of the integer value (not recommended)
  // Output: bool true if successfully executed
  // *********************************************************************************
  setCharactUUID --uuid/string --octetLenInt/int=-1 --propertyList/List --propertyHex/string="00" --octetLenHex/string="EMPTY"-> bool:
    if octetLenHex=="EMPTY" and octetLenInt!=-1:
      octetLenHex = octetLenInt.stringify 16
      if octetLenHex.size == 1:
        octetLenHex = "0"+octetLenHex
  
    else if octetLenHex!="EMPTY" and octetLenInt==-1:
      octetLenInt = int.parse octetLenHex --radix=16
    else:
      print "Error [setCharactUUID]: You have to input either integer or hex value of octetLen"
      return false
    
    tempProp := 0
    propertyList.do:
      if (lookupKey CHAR_PROPS it) == "":
        print "Error [setCharactUUID]: received unknown property $it"
        return false
      else:    
        tempProp = tempProp + it
    propertyHex = tempProp.stringify 16

    [uuid, propertyHex, octetLenHex].do:
      if not validateInputHexData it:
        print "Error [setCharactUUID]: Value $it is not in correct hex format"
        return false
  
    if octetLenInt < 1 or octetLenInt > 20:
      print "Error [setCharactUUID]: octetLenHex 0x$octetLenHex is out of range, should be between 0x1 and 0x14 in hex format " 
      return false
    else if not validateInputHexData uuid:
      print "Error [setCharactUUID]: $uuid is not a valid hex value"
      return false
    
    if uuid.size == PRIVATE_SERVICE_LEN:
      debugPrint "[setCharactUUID]: Set public UUID"
    else if uuid.size == PUBLIC_SERVICE_LEN:
      debugPrint "[setCharactUUID]: Set private UUID"
    else:
      print "Error [setCharactUUID]: received wrong UUID length. Should be 16 or 128 bit hexidecimal number)"
      return false

    debugPrint "[setCharactUUID]: Send command $DEFINE_CHARACT_UUID$uuid,$propertyHex,$octetLenHex"    
    sendCommand "$DEFINE_CHARACT_UUID$uuid,$propertyHex,$octetLenHex"  
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Write local characteristic value as server
  // *********************************************************************************
  // Writes content of characteristic in Server Service to local device by addressing
  // its handle
  // Input :  string handle which corresponds to the characteristic of the server service
  //          string value is the content to be written to the characteristic
  // Output: bool true if successfully executed
  // *********************************************************************************
  writeLocalCharacteristic --handle/string --value/string -> bool:
    debugPrint "[writeLocalCharacteristic]: Send command $WRITE_LOCAL_CHARACT$handle,$value"
    sendCommand "$WRITE_LOCAL_CHARACT$handle,$value"
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Read local characteristic value as server
  // *********************************************************************************
  // Reads the content of the server service characteristic on the local device
  // by addresiing its handle. 
  // This method is effective with or without an active connection.
  // Input : string handle which corresponds to the characteristic of the server service
  // Output: string with result
  // *********************************************************************************
  readLocalCharacteristic --handle/string -> string:
    debugPrint "[readLocalCharacteristic]: Send command $READ_LOCAL_CHARACT$handle "
    sendCommand "$READ_LOCAL_CHARACT$handle"
    result := extractResult readForTime
    return result

  // *********************************************************************************
  // Get the current connection status
  // *********************************************************************************
  // If the RN4870/71 is not connected, the output is none.
  // If the RN4870/71 is connected, the buffer must contains the information:
  // <Peer BT Address>,<Address Type>,<Connection Type>
  // where <Peer BT Address> is the 6-byte hex address of the peer device; 
  //       <Address Type> is either 0 for public address or 1 for random address; 
  //       <Connection Type> specifies if the connection enables UART Transparent 
  // feature, where 1 indicates UART Transparent is enabled and 0 indicates 
  // UART Transparent is disabled
  // Input : *time_ms - istening time for UART, 10000 by default
  // Output: string with result
  // *********************************************************************************
  getConnectionStatus --time_ms=10000 -> string:
    debugPrint "[getConnectionStatus]: Send command $GET_CONNECTION_STATUS"
    sendCommand GET_CONNECTION_STATUS
    result := extractResult (readForTime --ms=time_ms)
    if result == NONE_RESP:
      debugPrint "[getConnectionStatus]: $NONE_RESP"
    else if result == "":
      print "Error: [getConnectionStatus] connection timeout"
    return result

// ---------------------------------------- Private section ----------------------------------------

  // *********************************************************************************
  // Set and get settings
  // *********************************************************************************
  // The Set command starts with character “S” and followed by one or two character 
  // configuration identifier. All Set commands take at least one parameter 
  // that is separated from the command by a comma. Set commands change configurations 
  // and take effect after rebooting either via R,1 command, Hard Reset, or power cycle.
  // Most Set commands have a corresponding Get command to retrieve and output the
  // current configurations via the UART. Get commands have the same command
  // identifiers as Set commands but without parameters.
  // *********************************************************************************
  setSettings --addr/string --value/string -> bool:
    // Manual insertion of settings
    debugPrint "[setSettings]: Send command $SET_SETTINGS$addr,$value"
    sendCommand "$SET_SETTINGS$addr,$value"
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Configures the Beacon Feature
  // *********************************************************************************
  // Input : 
  // Output: return true if successfully executed
  // *********************************************************************************
  setBeaconFeatures value/string -> bool:
    setting := lookupKey BEACON_SETTINGS value
    if setting == "":
      print "Error [setBeaconFeatures]: Value $value is not in beacon commands set"
      return false
    else:
      debugPrint "[setBeaconFeatures]: set the Beacon Feature to $setting"
      sendCommand SET_BEACON_FEATURES+value
      return expectedResult AOK_RESP

  getSettings addr/string -> string:
    // Manual insertion of setting address
    debugPrint "[getSettings]: Send command $GET_SETTINGS$addr"
    sendCommand GET_SETTINGS + addr
    answerOrTimeout
    return popData
  
  setAdvPower value/int -> bool:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT
    debugPrint "[setAdvPower]: Send command $SET_ADV_POWER$value"
    sendCommand "$SET_ADV_POWER$value"
    return expectedResult AOK_RESP

  setConnPower value/int -> bool:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT
    debugPrint "[setAdvPower]: Send command $SET_CONN_POWER$value"
    sendCommand "$SET_CONN_POWER$value"
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Set the module to Dormant
  // *********************************************************************************
  // Immediately forces the device into lowest power mode possible.
  // Removing the device from Dormant mode requires power reset.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  dormantMode -> none:
    debugPrint "[dormantMode]"
    sendCommand SET_DORMANT_MODE
    sleep --ms=INTERNAL_CMD_TIMEOUT
