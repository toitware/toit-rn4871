// Copyright (C) 2021 Toitware ApS. All rights reserved.

// Driver for RN4871 bluetooth module

import binary
import serial.device
import serial.registers
import serial.ports.uart
import gpio
import .constants show *
import serialization


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
    
  // Reset
  pinReboot ->bool:
    reset_pin_.set 0
    sleep --ms=50
    reset_pin_.set 1
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    if result == REBOOT_EVENT:
      sleep --ms=STATUS_CHANGE_TIMEOUT
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
    
    if exception != null:  
      return false

    return true
    

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
    
    if status != ENUM_DATAMODE:
      if uartBuffer.last == endStreamChar:
        validateAnswer
        return ENUM_COMPLETE_ANSWER
    else:
      return ENUM_DATA_ANSWER

    if recMessage.size > uartBufferLen:
      return ENUM_PARTIAL_ANSWER

    return ENUM_NO_ANSWER

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

  sendData message/string:
    answerLen = 0 // Reset Answer Counter
    antenna.write message
    print "Message sent: $message" 

  setName newName:
    if status != ENUM_CONFMODE:
      return false

    if newName.size > MAX_DEVICE_NAME_LEN:
      print "Error: The name is too long"
      return false
    sendCommand SET_NAME + newName
    return expectedResult AOK_RESP

  getName:
    if status != ENUM_CONFMODE:
      return "Error: Not in the CONFMODE"
    sendCommand GET_DEVICE_NAME
    return extractResult readForTime
  
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
      print "Error: Not in Configuration mode"
      return ""

    sendCommand GET_SERIALNUM
    answerOrTimeout
    return popData

  setPowerSave powerSave/bool:
    // if not in configuration mode enter immediately
    if status != ENUM_CONFMODE:
      if not enterConfigurationMode:
        print "Error: Cannot enter Configuration mode"
        return ""

    // write command to buffer
    if powerSave:
      sendCommand SET_LOW_POWER_ON
      print "Low power ON"
    else:
      sendCommand SET_LOW_POWER_OFF
      print "Low power OFF"

    result := answerOrTimeout
    return result
  
  getConStatus -> string:
    if status != ENUM_CONFMODE:
      print "Error: Not in Configuration mode"
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
      print "Status set to: ENTER_DATMODE"
    else if ENUM_DATAMODE == statusToSet:
      print "Status set to: DATAMODE"
    else if ENUM_ENTER_CONFMODE == statusToSet:
      print "Status set to: ENTER_CONFMODE"
    else if ENUM_CONFMODE == statusToSet:
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

  readForTime --ms/int=INTERNAL_CMD_TIMEOUT ->string:
    dur := Duration --ms=ms
    start := Time.now
    result := ""
    while start.to_now < dur:
      answerOrTimeout
      result = result + popData
    return result

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
      print "Error: Feature: $feature is not in supported features set"
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
      print "Error: Value: $service is not a default service"
      return false
    debugPrint "[setDefServices]: The default service $key is set with the command: $SET_DEFAULT_SERVICES$service"
    sendCommand SET_DEFAULT_SERVICES+service
    return expectedResult AOK_RESP

  // *********************************************************************************
  // Listen to UART line for specific time
  // *********************************************************************************
  // Prints to the console the data from UART line that comes from RN4871 device
  // Input : int value representing amount of ms that the MCU should be listening
  // Output: none
  // *********************************************************************************
  listenToUart --ms/int=INTERNAL_CMD_TIMEOUT -> none:
    dur := Duration --ms=ms
    start := Time.now
    print "Begin to listen to UART\n"
    while start.to_now < dur:
      exception := catch: 
        with_timeout --ms=ms: 
          uartBuffer = antenna.read
          recMessage = uartBuffer.to_string.trim  
      if(exception == null):  
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
  // Input : value from AD_TYPES map -Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string adData is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  startImmediateAdvertising adType/string adData/string ->bool:    
    typeName := lookupKey AD_TYPES adType
    if typeName == "":
      print "startImmediateAdvertising failed: adType $adType is not one of accepted types"
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
  // Input : value from AD_TYPES map -Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string adData is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  startPermanentAdvertising adType/string adData/string ->bool:    
    typeName := lookupKey AD_TYPES adType
    if typeName == "":
      print "startPermanentAdvertising failed: adType $adType is not one of accepted types"
      return false
    debugPrint "[startPermanentAdvertising]: type $typeName, data $adData "
    adData = convertWordToHexString adData
    debugPrint "Send command: $START_PERMANENT_ADV$adType,$adData"
    sendCommand "$START_PERMANENT_ADV$adType,$adData"
    return expectedResult AOK_RESP

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

    debugPrint "[startImmediateBeacon]: type $typeName, data $adData "
    sendCommand START_IMMEDIATE_BEACON+adType+","+adData
    return expectedResult AOK_RESP

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

    debugPrint "[startPermanentBeacon]: type $typeName, data $adData "
    sendCommand START_PERMANENT_BEACON+adType+","+adData
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
// Input2 : uint16_t scan interval value (must be >= scan window)
//         uint16_t scan window value
// Output: bool true if successfully executed
// *********************************************************************************
  startScanning --scanInterval_ms/int=0 --scanWindow_ms/int=0:
    if scanInterval_ms*scanWindow_ms != 0:
      values := [2.5, scanInterval_ms, scanInterval_ms, 10.24].sort

      if values.first == 2.5 and values.last == 10.24:
        scanInterval := (scanInterval_ms / 0.625).to_int
        scanWindow := (scanWindow_ms / 0.625).to_int
        debugPrint "[startScanning] Custom scanning"
        sendCommand "$START_CUSTOM_SCAN$scanInterval,$scanWindow"
      else:
        print "Error: [startScanning] input values out of range"
    else:
      debugPrint "[startScanning] Default scanning"
      sendCommand START_DEFAULT_SCAN
    
    answerOrTimeout
    return popData == SCANNING_RESP

// *********************************************************************************
// Stop Scanning
// *********************************************************************************
// Stops scan process started by startScanning() method
// Input : void
// Output: bool true if successfully executed
// *********************************************************************************
  stopScanning:
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
// Input : bool addrType = 0 if following address is public (=1 for private)
//         const char *addr 6-byte address in hex format
// Output: bool true if successfully executed
// *********************************************************************************

  addMacAddrWhiteList addrType adData ->bool:    
    typeName := ""
    PUBLIC_ADDRESS_TYPE
    PRIVATE_ADDRESS_TYPE
    is_correct := false
    catch:
      try:
        addrType = addrType.stringify
      finally:
        [PUBLIC_ADDRESS_TYPE, PRIVATE_ADDRESS_TYPE].do:
          if it == addrType:
            is_correct = true
    if is_correct:
      sendCommand "$ADD_WHITE_LIST,$addrType,$adData"
    else:
      print "Error: [addMacAddrWhiteList] received faulty input"
      return false
    
    return expectedResult AOK_RESP
      
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
    print("[addBondedWhiteList]")
    
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
    print "clearWhiteList"
    sendCommand CLEAR_WHITE_LIST
    return expectedResult AOK_RESP

  expectedResult resp/string --ms=INTERNAL_CMD_TIMEOUT -> bool:
    result := extractResult(readForTime --ms=INTERNAL_CMD_TIMEOUT)
    return result == resp

  debugPrint text/string:
    if (debug == true):
      print text

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
    debugPrint("[reboot]")
    sendCommand(REBOOT)
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
// Input : const char *uuid 
//         can be either a 16-bit UUID for public service
//         or a 128-bit UUID for private service
// Output: bool true if successfully executed
// *********************************************************************************
  setServiceUUID uuid/string -> bool:
    
    if (uuid.size == PRIVATE_SERVICE_LEN):
      debugPrint("[setServiceUUID]: Set public UUID")
    else if (uuid.size == PUBLIC_SERVICE_LEN):
      debugPrint("[setServiceUUID]: Set private UUID")
    else:
      print("Error: [setServiceUUID] received wrong UUID length. Should be 16 or 128 bit hexidecimal number\nExample: PS,010203040506070809000A0B0C0D0E0F")
      return false
    sendCommand "$DEFINE_SERVICE_UUID,$uuid"  
    return expectedResult AOK_RESP

// Input : string uuid 
//         can be either a 16-bit UUID for public service
//         or a 128-bit UUID for private service
//         uint8_t property is a 8-bit property bitmap of the characteristics
//         uint8_t octetLen is an 8-bit value that indicates the maximum data size
//         in octet where the value of the characteristics holds in the range
//         from 1 to 20 (0x01 to 0x14)
// Output: bool true if successfully executed
// *********************************************************************************
  setCharactUUID --uuid/string --property/string --octetLen-> bool:
    catch:
      try:
        octetLen = octetLen.stringify
      finally:
        tab := ["1", octetLen, "20"].sort
        if tab.first != "1" or tab.last != "20":
          print "Error: [setCharactUUID] octetLen is too long, should be between 1 and 20" 
          return false
        
    
    if uuid.size == PRIVATE_SERVICE_LEN:
      debugPrint "[setCharactUUID]: Set public UUID"
    else if uuid.size == PUBLIC_SERVICE_LEN:
      debugPrint "[setCharactUUID]: Set private UUID"
    else:
      print "Error: [setCharactUUID] received wrong UUID length. Should be 16 or 128 bit hexidecimal number)"
      return false
    
    propertyName := ""
    CHAR_PROPS.filter:
      if CHAR_PROPS[it] == property:
        propertyName = it

    if(propertyName == ""):
      print "Error: [setCharactUUID] received unknown property $property"
      return false
    
    sendCommand "$DEFINE_CHARACT_UUID,$uuid,$property,$octetLen"  
    return expectedResult AOK_RESP

// *********************************************************************************
// Write local characteristic value as server
// *********************************************************************************
// Writes content of characteristic in Server Service to local device by addressing
// its handle
// Input : uint16_t handle which corresponds to the characteristic of the server service
//         const unsigned char value[] is the content to be written to the characteristic
// Output: bool true if successfully executed
// *********************************************************************************
  writeLocalCharacteristic --handle --value -> bool:
    debugPrint "[writeLocalCharacteristic]"
    sendCommand "$WRITE_LOCAL_CHARACT,$handle,$value"
    return expectedResult AOK_RESP

// *********************************************************************************
// Read local characteristic value as server
// *********************************************************************************
// Reads the content of the server service characteristic on the local device
// by addresiing its handle. 
// This method is effective with or without an active connection.
// Input : uint16_t handle which corresponds to the characteristic of the server service
// Output: string with result
// *********************************************************************************

  readLocalCharacteristic --handle/string -> string:
    debugPrint "[readLocalCharacteristic]"
    sendCommand "$READ_LOCAL_CHARACT,$handle"
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
// Input : void
// Output: string with result
// *********************************************************************************

  getConnectionStatus:
    sendCommand GET_CONNECTION_STATUS
    result := extractResult (readForTime --ms=10000)
    if result == "none":
      debugPrint "[getConnectionStatus]: none"
    else if result == "":
      print "Error: [getConnectionStatus] connection timeout"
    return result

// ---------------------------------------- Private section ----------------------------------------

// *********************************************************************************
// Configures the Beacon Feature
// *********************************************************************************
// Input : 
// Output: return true if successfully executed
// *********************************************************************************

  setBeaconFeatures value/string:
    setting := lookupKey BEACON_SETTINGS value
      
    if setting == "":
      print "Error: Value: $value is not in beacon commands set"
      return false
    else:
      debugPrint "[setBeaconFeatures]: set the Beacon Feature to $setting"
      sendCommand SET_BEACON_FEATURES+value
      return expectedResult AOK_RESP


  getSettings addr/string -> string:
    uartBuffer = GET_SETTINGS + addr
    sendCommand uartBuffer
    answerOrTimeout
    return popData

  setSettings addr/string value/string:
    // Manual insertion of settings
    sendCommand SET_SETTINGS+addr+","+value
    return expectedResult AOK_RESP
  
  setAdvPower value/int:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT

    sendCommand SET_ADV_POWER + "$value"
    return expectedResult AOK_RESP

  setConnPower value/int:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT

    sendCommand SET_CONN_POWER + "$value"
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

  lookupKey paramsMap/Map param/string -> string:
    key := ""
    paramsMap.filter:
      if paramsMap[it] == param:
        key = it
    return key
    
  convertWordToHexString input/string -> string:
    output := ""
    input.to_byte_array.do:
      output = output + (convertNumberToHexString it)
    return output

  convertNumberToHexString num/int -> string:
    if num < 0:
      print "Error: [convertNumberToHexString] the number $num is negative"
      return ""
    else if num < 10:
      return "$num"
    else if num == 10:
      return "A"
    else if num == 11:
      return "B"
    else if num == 12:
      return "C"
    else if num == 13:
      return "D"
    else if num == 14:
      return "E"
    else if num == 15:
      return "F"
    else:      
      return (convertNumberToHexString num/16) +(num % 16).stringify
