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
  
  rec_message := ""
  antenna/serial.Port
  status/int := ENUM_DATAMODE
  answer_len/int := 0
  uart_buffer := []
  rx_pin_/gpio.Pin
  tx_pin_/gpio.Pin
  reset_pin_/gpio.Pin
  ble_address := []
  debug := false

  // UART constructor
  constructor --tx/gpio.Pin --rx/gpio.Pin --reset_pin/gpio.Pin --baud_rate/int --debug_mode/bool=false:
    rx_pin_ = rx
    tx_pin_ = tx
    reset_pin_ = reset_pin
    antenna = serial.Port --tx=tx --rx=rx --baud_rate=baud_rate
    status = ENUM_DATAMODE
    answer_len = 0
    debug = debug_mode
    print "Device object created"

// ---------------------------------------Utility Methods ----------------------------------------

  lookup_key params_map/Map param/any -> string:
    params_map.do:
      if params_map[it] == param:
        return it
    return ""
    
  convert_string_to_hex input/string -> string:
    output := ""
    input.to_byte_array.do:
      output += it.stringify 16
    return output

  expected_result resp/string --ms=INTERNAL_CMD_TIMEOUT -> bool:
    result := extract_result(read_for_time --ms=INTERNAL_CMD_TIMEOUT)
    return result == resp

  debug_print text/string:
    if (debug == true):
      print text

  read_for_time --ms/int=INTERNAL_CMD_TIMEOUT -> string:
    dur := Duration --ms=ms
    start := Time.now
    result := ""
    while start.to_now < dur:
      answer_or_timeout
      result = result + pop_data
    return result

  listenToUart --ms/int=INTERNAL_CMD_TIMEOUT -> none:
    dur := Duration --ms=ms
    start := Time.now
    print "Begin listening to UART\n"
    while start.to_now < dur:
      exception := catch: 
        with_timeout --ms=ms: 
          uart_buffer = antenna.read
          rec_message = uart_buffer.to_string.trim  
      if(exception == null):  
        print pop_data

  pop_data -> string:
    result := rec_message
    rec_message = ""
    answer_len =0
    return result
  
  read_data -> string:
    return rec_message

  answer_or_timeout --timeout=INTERNAL_CMD_TIMEOUT-> bool:
    exception := catch: 
      with_timeout --ms=timeout: 
        uart_buffer = antenna.read
        rec_message = uart_buffer.to_string.trim
        answer_len = rec_message.size
    
    if exception != null:  
      return false

    return true

  extract_result name/string="" lis/List=[] first_iteration=true-> string:
    if first_iteration:
      if name == "":
        return name
      temp_list := name.split "\n"
      temp_list.map:
        lis = lis + (it.split " ")
    if lis == []:
      return ""
        
    elem := lis.remove_last.trim
    if  elem != "CMD>" and elem != "," and elem !="":
      return elem
    return extract_result "" lis false

  send_data message/string:
    answer_len = 0 // Reset Answer Counter
    antenna.write message
    print "Message sent: $message" 

  send_command stream/string->none:
    answer_len = 0
    antenna.write (stream.trim+CR)

  validate_answer:
    if status == ENUM_ENTER_CONFMODE:
      if rec_message[0] == PROMPT_FIRST_CHAR and rec_message[rec_message.size-1] == PROMPT_LAST_CHAR:
        set_status ENUM_CONFMODE
        return true

    if status == ENUM_ENTER_DATMODE:
      if rec_message[0] == PROMPT_FIRST_CHAR and rec_message[rec_message.size-1] == PROMPT_LAST_CHAR:
        set_status ENUM_DATAMODE
        return true
    return false

  set_status status_to_set:
    if ENUM_ENTER_DATMODE == status_to_set:
      print "[set_status]Status set to: ENTER_DATMODE"
    else if ENUM_DATAMODE == status_to_set:
      print "[set_status]Status set to: DATAMODE"
    else if ENUM_ENTER_CONFMODE == status_to_set:
      print "[set_status]Status set to: ENTER_CONFMODE"
    else if ENUM_CONFMODE == status_to_set:
      print "[set_status]Status set to: CONFMODE"
    else:
      print "Error [set_status]: Not able to update status. Mode: $status_to_set is unknown"
      return false
    status = status_to_set
    return true

  set_address address:
    ble_address  = address
    debug_print "[set_address] Address assigned to $address"
    return true

  validate_input_hex_data data/string -> bool:
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
  pin_reboot ->bool:
    reset_pin_.set 0
    sleep --ms=50
    reset_pin_.set 1
    result := extract_result(read_for_time --ms=INTERNAL_CMD_TIMEOUT)
    if result == REBOOT_EVENT:
      sleep --ms=STATUS_CHANGE_TIMEOUT
      print "[pin_reboot] Reboot successfull"
      return true
    else:
      print "[pin_reboot] Reboot failure"
      return false    

  start_BLE user_RA=null:
    if enter_configuration_mode == false:
      return false

    if assign_random_address user_RA == false:
      return false

    if enter_data_mode == false:
      return false

    return true

  enter_configuration_mode ->bool:
    // Command mode
    set_status ENUM_ENTER_CONFMODE
    send_data CONF_COMMAND
    result := read_for_time --ms=STATUS_CHANGE_TIMEOUT
    if result == PROMPT or result == "CMD":
      print "[enter_configuration_mode] Command mode set up"
      set_status ENUM_CONFMODE
      return true   
    else:
      print "[enter_configuration_mode] Failed to set command mode"
      return false
  
  enter_data_mode ->bool:
    set_status ENUM_ENTER_DATMODE
    antenna.write EXIT_CONF
    result := answer_or_timeout --timeout=STATUS_CHANGE_TIMEOUT
    if read_data == PROMPT_END:
      set_status ENUM_DATAMODE
    return result

  factory_reset: 
    // if not in configuration mode enter immediately
    if status != ENUM_CONFMODE:
      if not enter_configuration_mode:
        return false
    send_command FACTORY_RESET
    result := answer_or_timeout --timeout=STATUS_CHANGE_TIMEOUT
    sleep --ms=STATUS_CHANGE_TIMEOUT
    return result

  assign_random_address user_RA=null -> bool:
    if status == ENUM_CONFMODE:
      timeout := 0
      if user_RA == null:
        send_command AUTO_RANDOM_ADDRESS
      else:
        send_command AUTO_RANDOM_ADDRESS
      
      if answer_or_timeout == true:
        set_address pop_data.trim.to_byte_array
        return true
      else:
        return false
    else:
      return false

  set_name new_name:
    if status != ENUM_CONFMODE:
      return false

    if new_name.size > MAX_DEVICE_NAME_LEN:
      print "Error [set_name]: The name is too long"
      return false
    send_command SET_NAME + new_name
    return expected_result AOK_RESP

  get_name:
    if status != ENUM_CONFMODE:
      return "Error [get_name]: Not in the CONFMODE"
    send_command GET_DEVICE_NAME
    return extract_result read_for_time

  get_fw_version:
    if status != ENUM_CONFMODE:
      return false

    send_command DISPLAY_FW_VERSION
    answer_or_timeout
    return pop_data

  get_sw_version:
    if status != ENUM_CONFMODE:
      return false

    send_command GET_SWVERSION
    answer_or_timeout
    return pop_data

  get_hw_version:
    if status != ENUM_CONFMODE:
      return false

    send_command GET_HWVERSION
    answer_or_timeout
    return pop_data

  // *********************************************************************************
  // Set UART communication baudrate
  // *********************************************************************************
  // Selects the UART communication baudrate from the list of available settings.
  // Input : value from BAUDRATE map
  // Output: bool true if successfully executed
  // *********************************************************************************
  set_baud_rate param/string -> bool:
    if status != ENUM_CONFMODE:
      return false    
    setting := lookup_key BAUDRATES param

    if setting == "":
      print "Error: Value: $param is not in BAUDRATE commands set"
      return false
    debug_print "[set_baud_rate]: The baudrate is being set to $setting with the command: $SET_BAUDRATE$param"
    send_command "$SET_BAUDRATE$param"
    return expected_result AOK_RESP

  get_baud_rate -> string:
    if status != ENUM_CONFMODE:
      print "Error: Not in Configuration mode"
      return ""

    send_command GET_BAUDRATE
    answer_or_timeout
    return pop_data

  get_serial_number -> string:
    if status != ENUM_CONFMODE:
      print "Error [get_serial_number]: Not in Configuration mode"
      return ""

    send_command GET_SERIALNUM
    answer_or_timeout
    return pop_data

  set_power_save power_save/bool:
    // if not in configuration mode enter immediately
    if status != ENUM_CONFMODE:
      if not enter_configuration_mode:
        print "Error [set_power_save]: Cannot enter Configuration mode"
        return ""

    // write command to buffer
    if power_save:
      send_command SET_LOW_POWER_ON
      print "[set_power_save] Low power ON"
    else:
      send_command SET_LOW_POWER_OFF
      print "[set_power_save] Low power OFF"

    result := answer_or_timeout
    return result
  
  get_con_status -> string:
    if status != ENUM_CONFMODE:
      print "Error [get_con_status]: Not in Configuration mode"
      return ""

    send_command GET_CONNECTION_STATUS
    answer_or_timeout
    return pop_data

  get_power_save:
    if status != ENUM_CONFMODE:
        return false
    send_command GET_POWERSAVE
    answer_or_timeout
    return pop_data

  dev_info -> string:
    send_command GET_DEVICE_INFO
    return read_for_time

  // *********************************************************************************
  // Set supported features
  // *********************************************************************************
  // Selects the features that are supported by the device
  // Input : string value from FEATURES map
  // Output: bool true if successfully executed
  // *********************************************************************************
  set_sup_features feature/string:
    key := lookup_key FEATURES feature
    if key == "":
      print "Error [set_sup_features]: Feature: $feature is not in supported features set"
      return false
    debug_print "[set_sup_features]: The supported feature $key is set with the command: $SET_SUPPORTED_FEATURES$feature"
    send_command SET_SUPPORTED_FEATURES+feature
    return expected_result AOK_RESP

  // *********************************************************************************
  // Set default services
  // *********************************************************************************
  // This command sets the default services to be supported by the RN4870 in the GAP
  // server role.
  // Input : string value from SERVICES map
  // Output: bool true if successfully executed
  // *********************************************************************************
  set_def_services service:
    key := lookup_key SERVICES service
    if key == "":
      print "Error [set_def_services]: Value: $service is not a default service"
      return false
    debug_print "[set_def_services]: The default service $key is set with the command: $SET_DEFAULT_SERVICES$service"
    send_command SET_DEFAULT_SERVICES+service
    return expected_result AOK_RESP
  
  // *********************************************************************************
  // Clear all services
  // *********************************************************************************
  // Clears all settings of services and characteristics.
  // A power cycle is required afterwards to make the changes effective.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clear_all_services:
    debug_print "[clear_all_services]"
    send_command CLEAR_ALL_SERVICES
    return expected_result AOK_RESP

  // *********************************************************************************
  // Start Advertisement
  // *********************************************************************************
  // The advertisement is undirect connectable.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  start_advertising:
    debug_print "[start_advertising]"
    send_command(START_DEFAULT_ADV)
    return expected_result AOK_RESP

  // *********************************************************************************
  // Stops Advertisement
  // *********************************************************************************
  // Stops advertisement started by the start_advertising method.
  // Input : void
  // Output: bool true if successfully executed
  //*********************************************************************************
  stop_advertising:
    debug_print "[stop_advertising]"
    send_command(STOP_ADV)
    return expected_result AOK_RESP

  // *********************************************************************************
  // Clear the advertising structure Immediately
  // *********************************************************************************
  // Make the changes immediately effective without a reboot.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clear_immediate_advertising:
    debug_print "[clear_immediate_advertising]"
    send_command(CLEAR_IMMEDIATE_ADV)
    return expected_result AOK_RESP

  // *********************************************************************************
  // Clear the advertising structure in a permanent way
  // *********************************************************************************
  // The changes are saved into NVM only if other procedures require permanent
  // configuration changes. A reboot is requested after executing this method.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clear_permanent_advertising:
    debug_print "[clear_permanent_advertising]"
    send_command CLEAR_PERMANENT_ADV
    return expected_result AOK_RESP

  // *********************************************************************************
  // Clear the Beacon structure Immediately
  // *********************************************************************************
  // Make the changes immediately effective without a reboot.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clear_immediate_beacon:
    debug_print "[clear_immediate_beacon]"
    send_command CLEAR_IMMEDIATE_BEACON
    return expected_result AOK_RESP

  // *********************************************************************************
  // Clear the Beacon structure in a permanent way
  // *********************************************************************************
  // The changes are saved into NVM only if other procedures require permanent
  // configuration changes. A reboot is requested after executing this method.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clear_permanent_beacon:
    debug_print "[clear_permanent_beacon]"
    send_command CLEAR_PERMANENT_BEACON
    return expected_result AOK_RESP


  // *********************************************************************************
  // Start Advertising immediatly
  // *********************************************************************************
  // Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string ad_data is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  start_immediate_advertising ad_type/string ad_data/string ->bool:    
    type_name := lookup_key AD_TYPES ad_type
    if type_name == "":
      print "Error [start_immediate_advertising]: ad_type $ad_type is not one of accepted types"
      return false
    debug_print "[start_immediate_advertising]: type $type_name, data $ad_data "
    ad_data = convert_string_to_hex ad_data
    debug_print "Send command: $START_IMMEDIATE_ADV$ad_type,$ad_data"
    send_command "$START_IMMEDIATE_ADV$ad_type,$ad_data"
    return expected_result AOK_RESP

  // *********************************************************************************
  // Start Advertising permanently
  // *********************************************************************************
  // A reboot is needed after issuing this method
  // Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string ad_data is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  start_permanent_advertising ad_type/string ad_data/string ->bool:    
    type_name := lookup_key AD_TYPES ad_type
    if type_name == "":
      print "Error [start_immediate_advertising]: ad_type $ad_type is not one of accepted types"
      return false
    debug_print "[start_permanent_advertising]: type $type_name, data $ad_data "
    ad_data = convert_string_to_hex ad_data
    debug_print "Send command: $START_PERMANENT_ADV$ad_type,$ad_data"
    send_command "$START_PERMANENT_ADV$ad_type,$ad_data"
    return expected_result AOK_RESP

  // *********************************************************************************
  // Start Beacon adv immediatly
  // *********************************************************************************
  // Input : Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string ad_data is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  start_immediate_beacon ad_type/string ad_data/string ->bool:
    type_name := lookup_key AD_TYPES ad_type
    if type_name == "":
      print "Error [start_immediate_beacon]: ad_type $ad_type is not one of accepted types"
      return false
    debug_print "[start_immediate_beacon]: type $type_name, data $ad_data "
    ad_data = convert_string_to_hex ad_data
    debug_print "Send command: $START_IMMEDIATE_BEACON$ad_type,$ad_data"
    send_command "$START_IMMEDIATE_BEACON$ad_type,$ad_data"    
    return expected_result AOK_RESP

  // *********************************************************************************
  // Start Beacon adv permanently
  // *********************************************************************************
  // A reboot is needed after issuing this method
  // Input : Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
  //         number list in the Core Specification 
  //         string ad_data is the string message to be advertised. The message is 
  //         converted to the chain of hex ASCII values
  // Output: bool true if successfully executed
  // *********************************************************************************
  start_permanent_beacon ad_type/string ad_data/string ->bool:
    type_name := lookup_key AD_TYPES ad_type
    if type_name == "":
      print "Error [start_permanent_beacon]: ad_type $ad_type is not one of accepted types"
      return false
    debug_print "[start_permanent_beacon]: type $type_name, data $ad_data "
    ad_data = convert_string_to_hex ad_data
    debug_print "Send command: $START_PERMANENT_BEACON$ad_type,$ad_data"
    send_command "$START_PERMANENT_BEACON$ad_type,$ad_data" 
    return expected_result AOK_RESP

  // *********************************************************************************
  // Start Scanning
  // *********************************************************************************
  // Method available only when the module is set as a Central (GAP) device and is
  // ready for scan before establishing connection.
  // By default, scan interval of 375 milliseconds and scan window of 250 milliseconds
  // Use stop_scanning() method to stop an active scan
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
  start_scanning --scan_interval_ms/int=0 --scan_window_ms/int=0 -> bool:
    if scan_interval_ms*scan_window_ms != 0:
      values := [2.5, scan_interval_ms, scan_interval_ms, 1024].sort

      if values.first == 2.5 and values.last == 1024:
        scan_interval :=  (scan_interval_ms / 0.625).to_int.stringify 16
        scan_window :=  (scan_window_ms / 0.625).to_int.stringify 16
        debug_print "[start_scanning] Custom scanning\nSend Command: $START_CUSTOM_SCAN$scan_interval,$scan_window"
        send_command "$START_CUSTOM_SCAN$scan_interval,$scan_window"
      else:
        print "Error [start_scanning]: input values out of range"
    else:
      debug_print "[start_scanning] Default scanning"
      send_command START_DEFAULT_SCAN
    return expected_result SCANNING_RESP

  // *********************************************************************************
  // Stop Scanning
  // *********************************************************************************
  // Stops scan process started by start_scanning() method
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  stop_scanning -> bool:
    debug_print "[stop_scanning]"
    send_command STOP_SCAN
    return expected_result AOK_RESP

  
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
  // Input : string addr_type = 0 if following address is public (=1 for private)
  //         string addr 6-byte address in hex format
  // Output: bool true if successfully executed
  // *********************************************************************************

  add_mac_addr_white_list --addr_type/string --ad_data/string ->bool:    
    [PUBLIC_ADDRESS_TYPE, PRIVATE_ADDRESS_TYPE].do:
      if it == addr_type:
        debug_print "[add_mac_addr_white_list]: Send Command: $ADD_WHITE_LIST$addr_type,$ad_data"
        send_command "$ADD_WHITE_LIST$addr_type,$ad_data"
        return expected_result AOK_RESP
      else:
        print "Error [add_mac_addr_white_list]: received faulty input, $ADD_WHITE_LIST$addr_type,$ad_data"
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
  add_bonded_white_list:
    debug_print "[add_bonded_white_list]"
    send_command ADD_BONDED_WHITE_LIST
    return expected_result AOK_RESP

  // *********************************************************************************
  // Clear the white list
  // *********************************************************************************
  // Once the white list is cleared, white list feature is disabled.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  clear_white_list:
    debug_print "[clear_white_list]"
    send_command CLEAR_WHITE_LIST
    return expected_result AOK_RESP

  // *********************************************************************************
  // Kill the active connection
  // *********************************************************************************
  // Disconnect the active BTLE link. It can be used in central or peripheral role.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  kill_connection:
    debug_print "[kill_connection]"
    send_command KILL_CONNECTION
    return expected_result AOK_RESP

  // *********************************************************************************
  // Get the RSSI level
  // *********************************************************************************
  // Get the signal strength in dBm of the last communication with the peer device. 
  // The signal strength is used to estimate the distance between the device and its
  // remote peer.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  get_RSSI -> string:
    debug_print "[get_RSSI]"
    send_command GET_RSSI_LEVEL
    result := extract_result(read_for_time --ms=INTERNAL_CMD_TIMEOUT)
    debug_print "Received RSSI is: $result"
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
    debug_print "[reboot]"
    send_command REBOOT
    if expected_result REBOOTING_RESP:
      sleep --ms=STATUS_CHANGE_TIMEOUT
      debug_print "[reboot] Software reboot succesful"
      return true
    else:
      sleep --ms=STATUS_CHANGE_TIMEOUT
      debug_print "[reboot] Software reboot failed"
      return false

  // *********************************************************************************
  // Sets the service UUID
  // *********************************************************************************
  // Sets the UUID of the public or the private service.
  // This method must be called before the set_charact_UUID() method.
  // 
  // Input : string uuid containing hex ID
  //         can be either a 16-bit UUID for public service
  //         or a 128-bit UUID for private service
  // Output: bool true if successfully executed
  // *********************************************************************************
  set_service_UUID uuid/string -> bool:
    if not validate_input_hex_data uuid:
      print "Error [set_service_UUID]: $uuid is not a valid hex value"
      return false
    if (uuid.size == PRIVATE_SERVICE_LEN):
      debug_print("[set_service_UUID]: Set public UUID")
    else if (uuid.size == PUBLIC_SERVICE_LEN):
      debug_print("[set_service_UUID]: Set private UUID")
    else:
      print("Error [set_service_UUID]: received wrong UUID length. Should be 16 or 128 bit hexidecimal number\nExample: PS,010203040506070809000A0B0C0D0E0F")
      return false
    debug_print "[set_service_UUID] Send command: $DEFINE_SERVICE_UUID$uuid"  
    send_command "$DEFINE_SERVICE_UUID$uuid"  
    return expected_result AOK_RESP

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
  //         list property_list:
  //         is a list of hex values from CHAR_PROPS map, they can be put
  //         in any order 
  //         octet_len_int is an integer value that indicates the maximum data size
  //         in octet where the value of the characteristics holds in the range
  //         from 1 to 20 (0x01 to 0x14)
  //         *string property_hex:
  //         can be used instead of the list by inputing the hex value directly (not recommended)
  //         *string ocetetLenHex:
  //         can be used instead of the integer value (not recommended)
  // Output: bool true if successfully executed
  // *********************************************************************************
  set_charact_UUID --uuid/string --octet_len_int/int=-1 --property_list/List --property_hex/string="00" --octet_len_hex/string="EMPTY"-> bool:
    if octet_len_hex=="EMPTY" and octet_len_int!=-1:
      octet_len_hex = octet_len_int.stringify 16
      if octet_len_hex.size == 1:
        octet_len_hex = "0"+octet_len_hex
  
    else if octet_len_hex!="EMPTY" and octet_len_int==-1:
      octet_len_int = int.parse octet_len_hex --radix=16
    else:
      print "Error [set_charact_UUID]: You have to input either integer or hex value of octetLen"
      return false
    
    tempProp := 0
    property_list.do:
      if (lookup_key CHAR_PROPS it) == "":
        print "Error [set_charact_UUID]: received unknown property $it"
        return false
      else:    
        tempProp = tempProp + it
    property_hex = tempProp.stringify 16

    [uuid, property_hex, octet_len_hex].do:
      if not validate_input_hex_data it:
        print "Error [set_charact_UUID]: Value $it is not in correct hex format"
        return false
  
    if octet_len_int < 1 or octet_len_int > 20:
      print "Error [set_charact_UUID]: octet_len_hex 0x$octet_len_hex is out of range, should be between 0x1 and 0x14 in hex format " 
      return false
    else if not validate_input_hex_data uuid:
      print "Error [set_charact_UUID]: $uuid is not a valid hex value"
      return false
    
    if uuid.size == PRIVATE_SERVICE_LEN:
      debug_print "[set_charact_UUID]: Set public UUID"
    else if uuid.size == PUBLIC_SERVICE_LEN:
      debug_print "[set_charact_UUID]: Set private UUID"
    else:
      print "Error [set_charact_UUID]: received wrong UUID length. Should be 16 or 128 bit hexidecimal number)"
      return false

    debug_print "[set_charact_UUID]: Send command $DEFINE_CHARACT_UUID$uuid,$property_hex,$octet_len_hex"    
    send_command "$DEFINE_CHARACT_UUID$uuid,$property_hex,$octet_len_hex"  
    return expected_result AOK_RESP

  // *********************************************************************************
  // Write local characteristic value as server
  // *********************************************************************************
  // Writes content of characteristic in Server Service to local device by addressing
  // its handle
  // Input :  string handle which corresponds to the characteristic of the server service
  //          string value is the content to be written to the characteristic
  // Output: bool true if successfully executed
  // *********************************************************************************
  write_local_characteristic --handle/string --value/string -> bool:
    debug_print "[write_local_characteristic]: Send command $WRITE_LOCAL_CHARACT$handle,$value"
    send_command "$WRITE_LOCAL_CHARACT$handle,$value"
    return expected_result AOK_RESP

  // *********************************************************************************
  // Read local characteristic value as server
  // *********************************************************************************
  // Reads the content of the server service characteristic on the local device
  // by addresiing its handle. 
  // This method is effective with or without an active connection.
  // Input : string handle which corresponds to the characteristic of the server service
  // Output: string with result
  // *********************************************************************************
  read_local_characteristic --handle/string -> string:
    debug_print "[read_local_characteristic]: Send command $READ_LOCAL_CHARACT$handle "
    send_command "$READ_LOCAL_CHARACT$handle"
    result := extract_result read_for_time
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
  get_connection_status --time_ms=10000 -> string:
    debug_print "[get_connection_status]: Send command $GET_CONNECTION_STATUS"
    send_command GET_CONNECTION_STATUS
    result := extract_result (read_for_time --ms=time_ms)
    if result == NONE_RESP:
      debug_print "[get_connection_status]: $NONE_RESP"
    else if result == "":
      print "Error: [get_connection_status] connection timeout"
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
  set_settings --addr/string --value/string -> bool:
    // Manual insertion of settings
    debug_print "[set_settings]: Send command $SET_SETTINGS$addr,$value"
    send_command "$SET_SETTINGS$addr,$value"
    return expected_result AOK_RESP

  // *********************************************************************************
  // Configures the Beacon Feature
  // *********************************************************************************
  // Input : 
  // Output: return true if successfully executed
  // *********************************************************************************
  set_beacon_features value/string -> bool:
    setting := lookup_key BEACON_SETTINGS value
    if setting == "":
      print "Error [set_beacon_features]: Value $value is not in beacon commands set"
      return false
    else:
      debug_print "[set_beacon_features]: set the Beacon Feature to $setting"
      send_command SET_BEACON_FEATURES+value
      return expected_result AOK_RESP

  get_settings addr/string -> string:
    // Manual insertion of setting address
    debug_print "[get_settings]: Send command $GET_SETTINGS$addr"
    send_command GET_SETTINGS + addr
    answer_or_timeout
    return pop_data
  
  set_adv_power value/int -> bool:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT
    debug_print "[set_adv_power]: Send command $SET_ADV_POWER$value"
    send_command "$SET_ADV_POWER$value"
    return expected_result AOK_RESP

  set_conn_power value/int -> bool:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT
    debug_print "[set_conn_power]: Send command $SET_CONN_POWER$value"
    send_command "$SET_CONN_POWER$value"
    return expected_result AOK_RESP

  // *********************************************************************************
  // Set the module to Dormant
  // *********************************************************************************
  // Immediately forces the device into lowest power mode possible.
  // Removing the device from Dormant mode requires power reset.
  // Input : void
  // Output: bool true if successfully executed
  // *********************************************************************************
  dormant_mode -> none:
    debug_print "[dormant_mode]"
    send_command SET_DORMANT_MODE
    sleep --ms=INTERNAL_CMD_TIMEOUT
