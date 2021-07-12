// Copyright 2021 Krzysztof Mróz. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import binary
import serial.device
import serial.registers
import serial.ports.uart
import gpio
import .constants show *
import encoding.hex


class RN4871:
  
  rec_message_ := ""
  port_/serial.Port
  status_/int := STATUS_DATAMODE
  uart_buffer_ := []
  rx_pin_/gpio.Pin
  tx_pin_/gpio.Pin
  reset_pin_/gpio.Pin
  ble_address_ := []
  debug_ := false

  /**
  Constructs a RN4871 driver.
  The RN4871 device must be connected on the UART specified with the $tx and $rx pins.
  The $reset_pin must be connected to the device's reset pin.
  */
  constructor --tx/gpio.Pin --rx/gpio.Pin --reset_pin/gpio.Pin --baud_rate/int --debug_mode/bool=false:
    rx_pin_ = rx
    tx_pin_ = tx
    reset_pin_ = reset_pin
    port_ = serial.Port --tx=tx --rx=rx --baud_rate=baud_rate
    status_ = STATUS_DATAMODE
    debug_ = debug_mode

// ---------------------------------------Utility Methods ----------------------------------------
    
  convert_string_to_hex_ input/string -> string:
    output := ""
    input.to_byte_array.do:
      output += it.stringify 16
    return output

  is_expected_result_ resp/string --ms=INTERNAL_CMD_TIMEOUT_MS -> bool:
    result := extract_result(read_for_time --ms=INTERNAL_CMD_TIMEOUT_MS)
    return result == resp

  debug_print text/string:
    if (debug_ == true):
      print text

  read_for_time --ms/int=INTERNAL_CMD_TIMEOUT_MS -> string:
    dur := Duration --ms=ms
    start := Time.now
    result := ""
    while start.to_now < dur:
      answer_or_timeout_
      result = result + pop_data
    return result

  pop_data -> string:
    result := rec_message_
    rec_message_ = ""
    return result
  
  read_data -> string:
    return rec_message_

  answer_or_timeout_ --timeout=INTERNAL_CMD_TIMEOUT_MS-> bool:
    exception := catch: 
      with_timeout --ms=timeout: 
        uart_buffer_ = port_.read
        rec_message_ = uart_buffer_.to_string.trim
    
    if exception != null:  
      return false

    return true

  extract_result name/string="" list/List=[] first_iteration=true -> string:
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
    port_.write message
    print "Message sent: $message" 

  send_command stream/string->none:
    port_.write (stream.trim+CR)

  validate_answer:
    if status_ == STATUS_ENTER_CONFMODE:
      if rec_message_[0] == PROMPT_FIRST_CHAR and rec_message_[rec_message_.size-1] == PROMPT_LAST_CHAR:
        set_status STATUS_CONFMODE
        return true

    if status_ == STATUS_ENTER_DATAMODE:
      if rec_message_[0] == PROMPT_FIRST_CHAR and rec_message_[rec_message_.size-1] == PROMPT_LAST_CHAR:
        set_status STATUS_DATAMODE
        return true
    return false

  set_status status_to_set:
    if STATUS_ENTER_DATAMODE == status_to_set:
      print "[set_status]Status set to: ENTER_DATMODE"
    else if STATUS_DATAMODE == status_to_set:
      print "[set_status]Status set to: DATAMODE"
    else if STATUS_ENTER_CONFMODE == status_to_set:
      print "[set_status]Status set to: ENTER_CONFMODE"
    else if STATUS_CONFMODE == status_to_set:
      print "[set_status]Status set to: CONFMODE"
    else:
      print "Error [set_status]: Not able to update status. Mode: $status_to_set is unknown"
      return false
    status_ = status_to_set
    return true

  set_address address:
    ble_address_  = address
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
    
  /// # Resets device with a hardware method
  pin_reboot ->bool:
    reset_pin_.set 0
    sleep --ms=50
    reset_pin_.set 1
    result := extract_result(read_for_time --ms=INTERNAL_CMD_TIMEOUT_MS)
    if result == REBOOT_EVENT:
      sleep --ms=STATUS_CHANGE_TIMEOUT_MS
      print "[pin_reboot] Reboot successfull"
      return true
    else:
      print "[pin_reboot] Reboot failure"
      return false    

  start_BLE:
    if not enter_configuration_mode: return false

    if assign_random_address == false:
      return false

    if not enter_data_mode: return false

    return true

  /// # Command mode
  enter_configuration_mode ->bool:
    set_status STATUS_ENTER_CONFMODE
    send_data CONF_COMMAND
    result := read_for_time --ms=STATUS_CHANGE_TIMEOUT_MS
    if result == PROMPT or result == "CMD":
      print "[enter_configuration_mode] Command mode set up"
      set_status STATUS_CONFMODE
      return true   
    else:
      print "[enter_configuration_mode] Failed to set command mode"
      return false
  
  enter_data_mode ->bool:
    set_status STATUS_ENTER_DATAMODE
    port_.write EXIT_COMMAND
    result := answer_or_timeout_ --timeout=STATUS_CHANGE_TIMEOUT_MS
    if pop_data == PROMPT_END:
      set_status STATUS_DATAMODE
    return result

  factory_reset: 
    if status_ != STATUS_CONFMODE:
      if not enter_configuration_mode:
        return false
    send_command FACTORY_RESET
    result := answer_or_timeout_ --timeout=STATUS_CHANGE_TIMEOUT_MS
    sleep --ms=STATUS_CHANGE_TIMEOUT_MS
    pop_data
    return result

  assign_random_address -> bool:
    if status_ == STATUS_CONFMODE:
      send_command AUTO_RANDOM_ADDRESS
      
      if answer_or_timeout_:
        set_address pop_data.trim.to_byte_array
        return true
      else:
        return false
    else:
      return false

  set_name new_name/string -> bool:
    if status_ != STATUS_CONFMODE:
      return false

    if new_name.size > MAX_DEVICE_NAME_LEN:
      print "Error [set_name]: The name is too long"
      return false
    send_command SET_NAME + new_name
    return is_expected_result_ AOK_RESP

  get_name:
    if status_ != STATUS_CONFMODE:
      return "Error [get_name]: Not in the CONFMODE"
    send_command GET_DEVICE_NAME
    return extract_result read_for_time

  get_fw_version:
    if status_ != STATUS_CONFMODE:
      return false

    send_command DISPLAY_FW_VERSION
    answer_or_timeout_
    return pop_data

  get_sw_version:
    if status_ != STATUS_CONFMODE:
      return false

    send_command GET_SWVERSION
    answer_or_timeout_
    return pop_data

  get_hw_version:
    if status_ != STATUS_CONFMODE:
      return false

    send_command GET_HWVERSION
    answer_or_timeout_
    return pop_data

  /**
  # Sets UART communication baudrate

  Selects the UART communication baudrate from the list of available settings.
  Input : value from BAUDRATE map
  Output: bool true if successfully executed
  */
  set_baud_rate param/string -> bool:
    if status_ != STATUS_CONFMODE:
      return false    
    
    is_valid := [BAUDRATES_460800,\
    BAUDRATES_921600,\
    BAUDRATES_230400,\
    BAUDRATES_115200,\
    BAUDRATES_57600,\
    BAUDRATES_38400,\
    BAUDRATES_28800,\
    BAUDRATES_19200,\
    BAUDRATES_14400,\
    BAUDRATES_9600,\
    BAUDRATES_4800,\
    BAUDRATES_2400].contains param

    if not is_valid:
      print "Error: Value: $param is not in BAUDRATE commands set"
      return false
    else:
      debug_print "[set_baud_rate]: The baudrate is being set with command: $SET_BAUDRATE$param"
      send_command "$SET_BAUDRATE$param"
      return is_expected_result_ AOK_RESP

  get_baud_rate -> string:
    if status_ != STATUS_CONFMODE:
      print "Error: Not in Configuration mode"
      return ""

    send_command GET_BAUDRATE
    answer_or_timeout_
    return pop_data

  get_serial_number -> string:
    if status_ != STATUS_CONFMODE:
      print "Error [get_serial_number]: Not in Configuration mode"
      return ""

    send_command GET_SERIALNUM
    answer_or_timeout_
    return pop_data

  set_power_save power_save/bool:
    if status_ != STATUS_CONFMODE:
      if not enter_configuration_mode:
        print "Error [set_power_save]: Cannot enter Configuration mode"
        return ""

    if power_save:
      send_command SET_LOW_POWER_ON
      print "[set_power_save] Low power ON"
    else:
      send_command SET_LOW_POWER_OFF
      print "[set_power_save] Low power OFF"

    result := answer_or_timeout_
    pop_data
    return result
  
  get_con_status -> string:
    if status_ != STATUS_CONFMODE:
      print "Error [get_con_status]: Not in Configuration mode"
      return ""

    send_command GET_CONNECTION_STATUS
    answer_or_timeout_
    return pop_data

  get_power_save:
    if status_ != STATUS_CONFMODE:
        return false
    send_command GET_POWERSAVE
    answer_or_timeout_
    return pop_data

  dev_info -> string:
    send_command GET_DEVICE_INFO
    return read_for_time

  
  /**
  # Sets supported features

  Selects the features that are supported by the device
  Input : string value from FEATURES map
  Output: bool true if successfully executed
  */
  set_sup_features feature/string:
    is_valid := [FEATURE_ENABLE_FLOW_CONTROL,\
    FEATURE_NO_PROMPT          ,\
    FEATURE_FAST_MODE          ,\
    FEATURE_NO_BEACON_SCAN     ,\
    FEATURE_NO_CONNECT_SCAN    ,\
    FEATURE_NO_DUPLICATE_SCAN  ,\
    FEATURE_PASSIVE_SCAN       ,\
    FEATURE_UART_TRANSP_NO_ACK ,\
    FEATURE_MLDP_SUPPORT       ,\
    FEATURE_SCRIPT_ON_POWER_ON ,\
    FEATURE_RN4020_MLDP_STREAM ,\
    FEATURE_COMMAND_MODE_GUARD ].contains feature

    if not is_valid:
      print "Error [set_sup_features]: Feature: $feature is not in supported features set"
      return false
    else:
      debug_print "[set_sup_features]: The supported feature $feature is set with the command: $SET_SUPPORTED_FEATURES$feature"
      send_command SET_SUPPORTED_FEATURES+feature
      return is_expected_result_ AOK_RESP

  
  /**
  # Sets default services

  This command sets the default services to be supported by the RN4870 in the GAP
  server role.
  Input : string value from SERVICES map
  Output: bool true if successfully executed
  */
  set_def_services service/string -> bool:
    is_valid := [SERVICES_UART_AND_BEACON,\
    SERVICES_NO_SERVICE,\
    SERVICES_DEVICE_INFO_SERVICE,\
    SERVICES_UART_TRANSP_SERVICE,\
    SERVICES_BEACON_SERVICE,\
    SERVICES_AIRPATCH_SERVICE].contains service    

    if not is_valid:
      print "Error [set_def_services]: Value: $service is not a default service"
      return false
    else:
      debug_print "[set_def_services]: The default service $service is set with the command: $SET_DEFAULT_SERVICES$service"
      send_command SET_DEFAULT_SERVICES+service
      return is_expected_result_ AOK_RESP
  
  
  /**
  # Clears all services
  
  Clears all settings of services and characteristics.
  A power cycle is required afterwards to make the changes effective.
  Input : void
  Output: bool true if successfully executed
  */
  clear_all_services:
    debug_print "[clear_all_services]"
    send_command CLEAR_ALL_SERVICES
    return is_expected_result_ AOK_RESP

  
  /**
  # Starts Advertisement
  
  The advertisement is undirect connectable.
  Input : void
  Output: bool true if successfully executed
  */
  start_advertising:
    debug_print "[start_advertising]"
    send_command(START_DEFAULT_ADV)
    return is_expected_result_ AOK_RESP

  
  /**
  # Stops Advertisement
  
  Stops advertisement started by the start_advertising method.
  Input : void
  Output: bool true if successfully executed
  */
  stop_advertising:
    debug_print "[stop_advertising]"
    send_command(STOP_ADV)
    return is_expected_result_ AOK_RESP

  
  /**
  # Clears the advertising structure Immediately
  
  Make the changes immediately effective without a reboot.
  Input : void
  Output: bool true if successfully executed
  */
  clear_immediate_advertising:
    debug_print "[clear_immediate_advertising]"
    send_command(CLEAR_IMMEDIATE_ADV)
    return is_expected_result_ AOK_RESP

  
  /**
  # Clears the advertising structure in a permanent way
  
  The changes are saved into NVM only if other procedures require permanent
  configuration changes. A reboot is requested after executing this method.
  Input : void
  Output: bool true if successfully executed
  */
  clear_permanent_advertising:
    debug_print "[clear_permanent_advertising]"
    send_command CLEAR_PERMANENT_ADV
    return is_expected_result_ AOK_RESP

  
  /**
  # Clears the Beacon structure Immediately
  
  Make the changes immediately effective without a reboot.
  Input : void
  Output: bool true if successfully executed
  */
  clear_immediate_beacon:
    debug_print "[clear_immediate_beacon]"
    send_command CLEAR_IMMEDIATE_BEACON
    return is_expected_result_ AOK_RESP

  
  /**
  # Clears the Beacon structure in a permanent way
  
  The changes are saved into NVM only if other procedures require permanent
  configuration changes. A reboot is requested after executing this method.
  Input : void
  Output: bool true if successfully executed
  */
  clear_permanent_beacon:
    debug_print "[clear_permanent_beacon]"
    send_command CLEAR_PERMANENT_BEACON
    return is_expected_result_ AOK_RESP


  
  /**
  # Starts Advertising immediatly
  
  Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
          number list in the Core Specification 
          string ad_data is the string message to be advertised. The message is 
          converted to the chain of hex ASCII values
  Output: bool true if successfully executed
  */
  start_immediate_advertising ad_type/string ad_data/string ->bool:
    is_valid := [AD_TYPES_FLAGS,\
    AD_TYPES_INCOMPLETE_16_UUID,\
    AD_TYPES_COMPLETE_16_UUID,\
    AD_TYPES_INCOMPLETE_32_UUID,\
    AD_TYPES_COMPLETE_32_UUID,\
    AD_TYPES_INCOMPLETE_128_UUID,\
    AD_TYPES_COMPLETE_128_UUID,\
    AD_TYPES_SHORTENED_LOCAL_NAME,\
    AD_TYPES_COMPLETE_LOCAL_NAME,\
    AD_TYPES_TX_POWER_LEVEL,\
    AD_TYPES_CLASS_OF_DEVICE,\
    AD_TYPES_SIMPLE_PAIRING_HASH,\
    AD_TYPES_SIMPLE_PAIRING_RANDOMIZER,\
    AD_TYPES_TK_VALUE,\
    AD_TYPES_SECURITY_OOB_FLAG,\
    AD_TYPES_SLAVE_CONNECTION_INTERVAL,\
    AD_TYPES_LIST_16_SERVICE_UUID,\
    AD_TYPES_LIST_128_SERVICE_UUID,\
    AD_TYPES_SERVICE_DATA,\
    AD_TYPES_MANUFACTURE_SPECIFIC_DATA].contains ad_type

    if not is_valid:
      print "Error [start_immediate_advertising]: ad_type $ad_type is not one of accepted types"
      return false
    else:
      debug_print "[start_immediate_advertising]: type $ad_type, data $ad_data "
      ad_data = convert_string_to_hex_ ad_data
      debug_print "Send command: $START_IMMEDIATE_ADV$ad_type,$ad_data"
      send_command "$START_IMMEDIATE_ADV$ad_type,$ad_data"
      return is_expected_result_ AOK_RESP

  
  /**
  # Starts Advertising permanently
  
  A reboot is needed after issuing this method
  Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
          number list in the Core Specification 
          string ad_data is the string message to be advertised. The message is 
          converted to the chain of hex ASCII values
  Output: bool true if successfully executed
  */
  start_permanent_advertising ad_type/string ad_data/string ->bool:    
    is_valid := [AD_TYPES_FLAGS,\
    AD_TYPES_INCOMPLETE_16_UUID,\
    AD_TYPES_COMPLETE_16_UUID,\
    AD_TYPES_INCOMPLETE_32_UUID,\
    AD_TYPES_COMPLETE_32_UUID,\
    AD_TYPES_INCOMPLETE_128_UUID,\
    AD_TYPES_COMPLETE_128_UUID,\
    AD_TYPES_SHORTENED_LOCAL_NAME,\
    AD_TYPES_COMPLETE_LOCAL_NAME,\
    AD_TYPES_TX_POWER_LEVEL,\
    AD_TYPES_CLASS_OF_DEVICE,\
    AD_TYPES_SIMPLE_PAIRING_HASH,\
    AD_TYPES_SIMPLE_PAIRING_RANDOMIZER,\
    AD_TYPES_TK_VALUE,\
    AD_TYPES_SECURITY_OOB_FLAG,\
    AD_TYPES_SLAVE_CONNECTION_INTERVAL,\
    AD_TYPES_LIST_16_SERVICE_UUID,\
    AD_TYPES_LIST_128_SERVICE_UUID,\
    AD_TYPES_SERVICE_DATA,\
    AD_TYPES_MANUFACTURE_SPECIFIC_DATA].contains ad_type

    if not is_valid:
      print "Error [start_immediate_advertising]: ad_type $ad_type is not one of accepted types"
      return false
    else:
      debug_print "[start_permanent_advertising]: type $ad_type, data $ad_data "
      ad_data = convert_string_to_hex_ ad_data
      debug_print "Send command: $START_PERMANENT_ADV$ad_type,$ad_data"
      send_command "$START_PERMANENT_ADV$ad_type,$ad_data"
      return is_expected_result_ AOK_RESP

  
  /**
  # Starts Beacon adv immediatly
  
  Input : Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
          number list in the Core Specification 
          string ad_data is the string message to be advertised. The message is 
          converted to the chain of hex ASCII values
  Output: bool true if successfully executed
  */
  start_immediate_beacon ad_type/string ad_data/string ->bool:
  
    is_valid := [AD_TYPES_FLAGS,\
    AD_TYPES_INCOMPLETE_16_UUID,\
    AD_TYPES_COMPLETE_16_UUID,\
    AD_TYPES_INCOMPLETE_32_UUID,\
    AD_TYPES_COMPLETE_32_UUID,\
    AD_TYPES_INCOMPLETE_128_UUID,\
    AD_TYPES_COMPLETE_128_UUID,\
    AD_TYPES_SHORTENED_LOCAL_NAME,\
    AD_TYPES_COMPLETE_LOCAL_NAME,\
    AD_TYPES_TX_POWER_LEVEL,\
    AD_TYPES_CLASS_OF_DEVICE,\
    AD_TYPES_SIMPLE_PAIRING_HASH,\
    AD_TYPES_SIMPLE_PAIRING_RANDOMIZER,\
    AD_TYPES_TK_VALUE,\
    AD_TYPES_SECURITY_OOB_FLAG,\
    AD_TYPES_SLAVE_CONNECTION_INTERVAL,\
    AD_TYPES_LIST_16_SERVICE_UUID,\
    AD_TYPES_LIST_128_SERVICE_UUID,\
    AD_TYPES_SERVICE_DATA,\
    AD_TYPES_MANUFACTURE_SPECIFIC_DATA].contains ad_type

    if not is_valid:
      print "Error [start_immediate_beacon]: ad_type $ad_type is not one of accepted types"
      return false
    else:
      debug_print "[start_immediate_beacon]: type $ad_type, data $ad_data "
      ad_data = convert_string_to_hex_ ad_data
      debug_print "Send command: $START_IMMEDIATE_BEACON$ad_type,$ad_data"
      send_command "$START_IMMEDIATE_BEACON$ad_type,$ad_data"    
      return is_expected_result_ AOK_RESP

  
  /**
  # Starts Beacon adv permanently
  
  A reboot is needed after issuing this method
  Input : Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned 
          number list in the Core Specification 
          string ad_data is the string message to be advertised. The message is 
          converted to the chain of hex ASCII values
  Output: bool true if successfully executed
  */
  start_permanent_beacon ad_type/string ad_data/string ->bool:
    is_valid := [AD_TYPES_FLAGS,\
    AD_TYPES_INCOMPLETE_16_UUID,\
    AD_TYPES_COMPLETE_16_UUID,\
    AD_TYPES_INCOMPLETE_32_UUID,\
    AD_TYPES_COMPLETE_32_UUID,\
    AD_TYPES_INCOMPLETE_128_UUID,\
    AD_TYPES_COMPLETE_128_UUID,\
    AD_TYPES_SHORTENED_LOCAL_NAME,\
    AD_TYPES_COMPLETE_LOCAL_NAME,\
    AD_TYPES_TX_POWER_LEVEL,\
    AD_TYPES_CLASS_OF_DEVICE,\
    AD_TYPES_SIMPLE_PAIRING_HASH,\
    AD_TYPES_SIMPLE_PAIRING_RANDOMIZER,\
    AD_TYPES_TK_VALUE,\
    AD_TYPES_SECURITY_OOB_FLAG,\
    AD_TYPES_SLAVE_CONNECTION_INTERVAL,\
    AD_TYPES_LIST_16_SERVICE_UUID,\
    AD_TYPES_LIST_128_SERVICE_UUID,\
    AD_TYPES_SERVICE_DATA,\
    AD_TYPES_MANUFACTURE_SPECIFIC_DATA].contains ad_type

    if not is_valid:
      print "Error [start_permanent_beacon]: ad_type $ad_type is not one of accepted types"
      return false
    else:
      debug_print "[start_permanent_beacon]: type $ad_type, data $ad_data "
      ad_data = convert_string_to_hex_ ad_data
      debug_print "Send command: $START_PERMANENT_BEACON$ad_type,$ad_data"
      send_command "$START_PERMANENT_BEACON$ad_type,$ad_data" 
      return is_expected_result_ AOK_RESP

  
  /**
  # Starts Scanning
  
  Method available only when the module is set as a Central (GAP) device and is
  ready for scan before establishing connection.
  By default, scan interval of 375 milliseconds and scan window of 250 milliseconds
  Use stop_scanning() method to stop an active scan
  The user has the option to specify the scan interval and scan window as first 
  and second parameter, respectively. Each unit is 0.625 millisecond. Scan interval
  must be larger or equal to scan window. The scan interval and the scan window
  values can range from 2.5 milliseconds to 10.24 seconds.
  Input1 : void
  or
  Input2 : int scan interval value (must be >= scan window)
           int scan window value
  Output: bool true if successfully executed
  */
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
    return is_expected_result_ SCANNING_RESP

  
  /**
  # Stops Scanning
  
  Stops scan process started by start_scanning() method
  Input : void
  Output: bool true if successfully executed
  */
  stop_scanning -> bool:
    debug_print "[stop_scanning]"
    send_command STOP_SCAN
    return is_expected_result_ AOK_RESP

  
  
  /**
  # Adds a MAC address to the white list
  
  Once one device is added to the white list, the white list feature is enabled.
  With the white list feature enabled, when performing a scan, any device not
  included in the white list does not appear in the scan results.
  As a peripheral, any device not listed in the white list cannot be connected
  with a local device. RN4870/71 supports up to 16 addresses in the white list.
  A random address stored in the white list cannot be resolved. If the peer 
  device does not change the random address, it is valid in the white list. 
  If the random address is changed, this device is no longer considered to be on 
  the white list.
  Input : string addr_type = 0 if following address is public (=1 for private)
          string addr 6-byte address in hex format
  Output: bool true if successfully executed
  */
  add_mac_addr_white_list --addr_type/string --ad_data/string ->bool:    
    [PUBLIC_ADDRESS_TYPE, PRIVATE_ADDRESS_TYPE].do:
      if it == addr_type:
        debug_print "[add_mac_addr_white_list]: Send Command: $ADD_WHITE_LIST$addr_type,$ad_data"
        send_command "$ADD_WHITE_LIST$addr_type,$ad_data"
        return is_expected_result_ AOK_RESP
      else:
        print "Error [add_mac_addr_white_list]: received faulty input, $ADD_WHITE_LIST$addr_type,$ad_data"
    return false
      
  
  /**
  # Adds all currently bonded devices to the white list
  
  The random address in the white list can be resolved with this method for 
  connection purpose. If the peer device changes its resolvable random address, 
  the RN4870/71 is still able to detect that the different random addresses are 
  from the same physical device, therefore, allows connection from such peer 
  device. This feature is particularly useful if the peer device is a iOS or 
  Android device which uses resolvable random.
  Input : void
  Output: bool true if successfully executed
  */
  add_bonded_white_list:
    debug_print "[add_bonded_white_list]"
    send_command ADD_BONDED_WHITE_LIST
    return is_expected_result_ AOK_RESP

  
  /**
  # Clears the white list
  
  Once the white list is cleared, white list feature is disabled.
  Input : void
  Output: bool true if successfully executed
  */
  clear_white_list:
    debug_print "[clear_white_list]"
    send_command CLEAR_WHITE_LIST
    return is_expected_result_ AOK_RESP

  
  /**
  # Kills the active connection
  
  Disconnect the active BTLE link. It can be used in central or peripheral role.
  Input : void
  Output: bool true if successfully executed
  */
  kill_connection:
    debug_print "[kill_connection]"
    send_command KILL_CONNECTION
    return is_expected_result_ AOK_RESP

  
  /**
  # Gets the RSSI level
  
  Get the signal strength in dBm of the last communication with the peer device. 
  The signal strength is used to estimate the distance between the device and its
  remote peer.
  Input : void
  Output: bool true if successfully executed
  */
  get_RSSI -> string:
    debug_print "[get_RSSI]"
    send_command GET_RSSI_LEVEL
    result := extract_result(read_for_time --ms=INTERNAL_CMD_TIMEOUT_MS)
    debug_print "Received RSSI is: $result"
    return result

  
  /**
  # Reboots the module with a software method
  
  Forces a complete device reboot (similar to a power cycle).
  After rebooting RN487x, all prior made setting changes takes effect.
  Input : void
  Output: bool true if successfully executed
  */
  reboot -> bool:
    debug_print "[reboot]"
    send_command REBOOT
    if is_expected_result_ REBOOTING_RESP:
      sleep --ms=STATUS_CHANGE_TIMEOUT_MS
      debug_print "[reboot] Software reboot succesful"
      return true
    else:
      sleep --ms=STATUS_CHANGE_TIMEOUT_MS
      debug_print "[reboot] Software reboot failed"
      return false

  
  /**
  # Sets the service UUID
  
  Sets the UUID of the public or the private service.
  This method must be called before the set_charact_UUID() method.
  
  Input : string uuid containing hex ID
          can be either a 16-bit UUID for public service
          or a 128-bit UUID for private service
  Output: bool true if successfully executed
  */
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
    return is_expected_result_ AOK_RESP

  
  /**
  # Sets the private characteristic.
  
  Command PC must be called after service UUID is set by command PS.“PS,<hex16/hex128>” 
  for command PS. If service UUID is set to be a 16-bit public UUID in command PS, 
  then the UUID input parameter for command PC must also be a 16-bit public UUID. 
  Similarly, if service UUID is set to be a 128-bit privateUUID by command PS, 
  then the UUID input parameter must also be a 128-bit private UUID by command PC. 
  Calling this command adds one characteristic to the service at
  a time. Calling this command later does not overwrite the previous settings, but adds
  another characteristic instead
  Input : string uuid:
          can be either a 16-bit UUID for public service
          or a 128-bit UUID for private service
          list property_list:
          is a list of hex values from CHAR_PROPS map, they can be put
          in any order 
          octet_len_int is an integer value that indicates the maximum data size
          in octet where the value of the characteristics holds in the range
          from 1 to 20 (0x01 to 0x14)
          *string property_hex:
          can be used instead of the list by inputing the hex value directly (not recommended)
          *string ocetetLenHex:
          can be used instead of the integer value (not recommended)
  Output: bool true if successfully executed
  */
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
      if not [CHAR_PROPS_INDICATE, CHAR_PROPS_NOTIFY, CHAR_PROPS_WRITE, CHAR_PROPS_WRITE_NO_RESP, CHAR_PROPS_READ].contains it:
        print "Error [set_charact_UUID]: received unknown property $it"
        return false
      else:    
        tempProp = tempProp + it
    property_hex = tempProp.stringify 16

    [uuid, property_hex, octet_len_hex].do:
      if not validate_input_hex_data it:
        print "Error [set_charact_UUID]: Value $it is not in correct hex format"
        return false
  
    if not  1 <= octet_len_int <= 20:
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
    return is_expected_result_ AOK_RESP

  
  /**
  # Writes local characteristic value as server
  
  Writes content of characteristic in Server Service to local device by addressing
  its handle
  Input :  string handle which corresponds to the characteristic of the server service
           string value is the content to be written to the characteristic
  Output: bool true if successfully executed
  */
  write_local_characteristic --handle/string --value/string -> bool:
    debug_print "[write_local_characteristic]: Send command $WRITE_LOCAL_CHARACT$handle,$value"
    send_command "$WRITE_LOCAL_CHARACT$handle,$value"
    return is_expected_result_ AOK_RESP

  
  /**
  # Reads local characteristic value as server
  
  Reads the content of the server service characteristic on the local device
    by addressing its handle. 
  This method is effective with or without an active connection.
  Input : string handle which corresponds to the characteristic of the server service
  Output: string with result
  */
  read_local_characteristic --handle/string -> string:
    debug_print "[read_local_characteristic]: Send command $READ_LOCAL_CHARACT$handle "
    send_command "$READ_LOCAL_CHARACT$handle"
    result := extract_result read_for_time
    return result

  
  /**
  # Gets the current connection status
  
  If the RN4870/71 is not connected, the output is none.
  If the RN4870/71 is connected, the buffer contains the information:
  <Peer BT Address>,<Address Type>,<Connection Type>
  where <Peer BT Address> is the 6-byte hex address of the peer device; 
        <Address Type> is either 0 for public address or 1 for random address; 
        <Connection Type> specifies if the connection enables UART Transparent 
  feature, where 1 indicates UART Transparent is enabled and 0 indicates 
  UART Transparent is disabled
  Input : *time_ms - istening time for UART, 10000 by default
  Output: string with result
  */
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

  
  /**
  # Sets and get settings
  
  The Set command starts with character “S” and followed by one or two character 
  configuration identifier. All Set commands take at least one parameter 
  that is separated from the command by a comma. Set commands change configurations 
  and take effect after rebooting either via R,1 command, Hard Reset, or power cycle.
  Most Set commands have a corresponding Get command to retrieve and output the
  current configurations via the UART. Get commands have the same command
  identifiers as Set commands but without parameters.
  */
  set_settings --addr/string --value/string -> bool:
    // Manual insertion of settings
    debug_print "[set_settings]: Send command $SET_SETTINGS$addr,$value"
    send_command "$SET_SETTINGS$addr,$value"
    return is_expected_result_ AOK_RESP

  
  /**
  # Configures the Beacon Feature
  
  Input : string value from BEACON_SETTINGS map 
  Output: return true if successfully executed
  */
  set_beacon_features value/string -> bool:
    is_valid := [BEACON_SETTINGS_ADV_ON, BEACON_SETTINGS_OFF, BEACON_SETTINGS_OFF].contains value

    if is_valid:
      debug_print "[set_beacon_features]: set the Beacon Feature to $value"
      send_command SET_BEACON_FEATURES+value
      return is_expected_result_ AOK_RESP
    else:
      print "Error [set_beacon_features]: Value $value is not in beacon commands set"
      return false


  /// # Gets setting from selected address
  get_settings addr/string -> string:
    debug_print "[get_settings]: Send command $GET_SETTINGS$addr"
    send_command GET_SETTINGS + addr
    answer_or_timeout_
    return pop_data
  
  set_adv_power value/int -> bool:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT
    debug_print "[set_adv_power]: Send command $SET_ADV_POWER$value"
    send_command "$SET_ADV_POWER$value"
    return is_expected_result_ AOK_RESP

  set_conn_power value/int -> bool:
    if value > MAX_POWER_OUTPUT:
      value = MAX_POWER_OUTPUT
    else if value < MIN_POWER_OUTPUT:
      value = MIN_POWER_OUTPUT
    debug_print "[set_conn_power]: Send command $SET_CONN_POWER$value"
    send_command "$SET_CONN_POWER$value"
    return is_expected_result_ AOK_RESP

  
  /**
  # Sets the module to Dormant
  
  Immediately forces the device into lowest power mode possible.
  Removing the device from Dormant mode requires power reset.
  Input : void
  Output: bool true if successfully executed
  */
  dormant_mode -> none:
    debug_print "[dormant_mode]"
    send_command SET_DORMANT_MODE
    sleep --ms=INTERNAL_CMD_TIMEOUT_MS
