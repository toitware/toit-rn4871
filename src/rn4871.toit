// Copyright 2021 Toitware ApS.
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

  rec-message_ := ""
  port_/serial.Port
  status_/int := STATUS-DATAMODE
  uart-buffer_ := []
  rx-pin_/gpio.Pin
  tx-pin_/gpio.Pin
  reset-pin_/gpio.Pin
  ble-address_ := []
  debug_ := false

  /**
  Constructs a RN4871 driver.
  The RN4871 device must be connected on the UART specified with the $tx and $rx pins.
  The $reset-pin must be connected to the device's reset pin.
  */
  constructor --tx/gpio.Pin --rx/gpio.Pin --reset-pin/gpio.Pin --baud-rate/int --debug-mode/bool=false:
    rx-pin_ = rx
    tx-pin_ = tx
    reset-pin_ = reset-pin
    port_ = serial.Port --tx=tx --rx=rx --baud-rate=baud-rate
    status_ = STATUS-DATAMODE
    debug_ = debug-mode

// ---------------------------------------Utility Methods ----------------------------------------

  convert-string-to-hex_ input/string -> string:
    output := ""
    input.to-byte-array.do:
      output += it.stringify 16
    return output

  is-expected-result_ resp/string --ms=INTERNAL-CMD-TIMEOUT-MS -> bool:
    result := extract-result(read-for-time --ms=INTERNAL-CMD-TIMEOUT-MS)
    return result == resp

  debug-print_ text/string:
    if (debug_ == true):
      print text

  read-for-time --ms/int=INTERNAL-CMD-TIMEOUT-MS -> string:
    dur := Duration --ms=ms
    start := Time.now
    result := ""
    while start.to-now < dur:
      answer-or-timeout_
      result = result + pop-data
    return result

  pop-data -> string:
    result := rec-message_
    rec-message_ = ""
    return result

  read-data -> string:
    return rec-message_

  answer-or-timeout_ --timeout=INTERNAL-CMD-TIMEOUT-MS-> bool:
    exception := catch:
      with-timeout --ms=timeout:
        uart-buffer_ = port_.read
        rec-message_ = uart-buffer_.to-string.trim

    if exception != null:
      return false

    return true

  extract-result name/string="" list/List=[] first-iteration=true -> string:
    if first-iteration:
      if name == "":
        return name
      temp-list := name.split "\n"
      temp-list.map:
        list = list + (it.split " ")
    if list == []:
      return ""

    elem := list.remove-last.trim
    if  elem != "CMD>" and elem != "," and elem !="":
      return elem
    return extract-result "" list false

  send-data message/string:
    port_.write message
    debug-print_ "[send_data]: $message"

  send-command stream/string->none:
    port_.write (stream.trim+CR)

  set-status status-to-set:
    if STATUS-ENTER-DATAMODE == status-to-set:
      print "[set_status]Status set to: ENTER_DATAMODE"
    else if STATUS-DATAMODE == status-to-set:
      print "[set_status]Status set to: DATAMODE"
    else if STATUS-ENTER-CONFMODE == status-to-set:
      print "[set_status]Status set to: ENTER_CONFMODE"
    else if STATUS-CONFMODE == status-to-set:
      print "[set_status]Status set to: CONFMODE"
    else:
      print "Error [set_status]: Not able to update status. Mode: $status-to-set is unknown"
      return false
    status_ = status-to-set
    return true

  set-address address:
    ble-address_  = address
    debug-print_ "[set_address] Address assigned to $address"
    return true

  validate-input-hex-data_ data/string -> bool:
    data.do:
      if not ('0' <= it <= '9' or 'a' <= it <= 'f' or 'A' <= it <= 'F'): return false
    return data != ""

// ---------------------------------------- Public section ----------------------------------------

  /// # Resets device with a hardware method
  pin-reboot ->bool:
    reset-pin_.set 0
    sleep --ms=50
    reset-pin_.set 1
    result := extract-result(read-for-time --ms=INTERNAL-CMD-TIMEOUT-MS)
    if result == REBOOT-EVENT:
      sleep --ms=STATUS-CHANGE-TIMEOUT-MS
      print "[pin_reboot] Reboot successfull"
      return true
    else:
      print "[pin_reboot] Reboot failure"
      return false

  start-BLE:
    if not enter-configuration-mode: return false

    if assign-random-address == false:
      return false

    if not enter-data-mode: return false

    return true

  /// # Command mode
  enter-configuration-mode ->bool:
    set-status STATUS-ENTER-CONFMODE
    sleep --ms=100
    send-data CONF-COMMAND
    result := read-for-time --ms=STATUS-CHANGE-TIMEOUT-MS
    if result == PROMPT or result == "CMD":
      print "[enter_configuration_mode] Command mode set up"
      set-status STATUS-CONFMODE
      return true
    else:
      print "[enter_configuration_mode] Failed to set command mode"
      return false

  enter-data-mode ->bool:
    set-status STATUS-ENTER-DATAMODE
    port_.write EXIT-COMMAND
    result := answer-or-timeout_ --timeout=STATUS-CHANGE-TIMEOUT-MS
    if pop-data == PROMPT-END:
      set-status STATUS-DATAMODE
    return result

  factory-reset:
    if status_ != STATUS-CONFMODE:
      if not enter-configuration-mode:
        return false
    send-command FACTORY-RESET
    result := answer-or-timeout_ --timeout=STATUS-CHANGE-TIMEOUT-MS
    sleep --ms=STATUS-CHANGE-TIMEOUT-MS
    pop-data
    return result

  assign-random-address -> bool:
    if status_ == STATUS-CONFMODE:
      send-command AUTO-RANDOM-ADDRESS

      if answer-or-timeout_:
        set-address pop-data.trim.to-byte-array
        return true
      else:
        return false
    else:
      return false

  set-name new-name/string -> bool:
    if status_ != STATUS-CONFMODE:
      return false

    if new-name.size > MAX-DEVICE-NAME-LEN:
      print "Error [set_name]: The name is too long"
      return false
    send-command SET-NAME + new-name
    return is-expected-result_ AOK-RESP

  get-name -> string:
    if status_ != STATUS-CONFMODE:
      debug-print_ "Error [get_name]: Not in the CONFMODE"
    send-command GET-DEVICE-NAME
    return extract-result read-for-time

  get-fw-version:
    if status_ != STATUS-CONFMODE:
      return false

    send-command DISPLAY-FW-VERSION
    answer-or-timeout_
    return pop-data

  get-sw-version:
    if status_ != STATUS-CONFMODE:
      return false

    send-command GET-SWVERSION
    answer-or-timeout_
    return pop-data

  get-hw-version:
    if status_ != STATUS-CONFMODE:
      return false

    send-command GET-HWVERSION
    answer-or-timeout_
    return pop-data

  /**
  Sets UART communication baudrate

  Selects the UART communication baudrate from the list of available settings.
  Input : param string
  Output: bool true if successfully executed
  */
  set-baud-rate param/string -> bool:
    if status_ != STATUS-CONFMODE:
      return false

    is-valid := [BAUDRATES-460800,\
    BAUDRATES-921600,\
    BAUDRATES-230400,\
    BAUDRATES-115200,\
    BAUDRATES-57600,\
    BAUDRATES-38400,\
    BAUDRATES-28800,\
    BAUDRATES-19200,\
    BAUDRATES-14400,\
    BAUDRATES-9600,\
    BAUDRATES-4800,\
    BAUDRATES-2400].contains param

    if not is-valid:
      print "Error: Value: $param is not in BAUDRATE commands set"
      return false
    else:
      debug-print_ "[set_baud_rate]: The baudrate is being set with command: $SET-BAUDRATE$param"
      send-command "$SET-BAUDRATE$param"
      return is-expected-result_ AOK-RESP

  get-baud-rate -> string:
    if status_ != STATUS-CONFMODE:
      debug-print_ "Error: Not in Configuration mode"
      return ""

    send-command GET-BAUDRATE
    answer-or-timeout_
    return pop-data

  get-serial-number -> string:
    if status_ != STATUS-CONFMODE:
      debug-print_ "Error [get_serial_number]: Not in Configuration mode"
      return ""

    send-command GET-SERIALNUM
    answer-or-timeout_
    return pop-data

  set-power-save power-save/bool:
    if status_ != STATUS-CONFMODE:
      if not enter-configuration-mode:
        debug-print_ "Error [set_power_save]: Cannot enter Configuration mode"
        return ""

    if power-save:
      send-command SET-LOW-POWER-ON
      print "[set_power_save] Low power ON"
    else:
      send-command SET-LOW-POWER-OFF
      print "[set_power_save] Low power OFF"

    result := answer-or-timeout_
    pop-data
    return result

  get-con-status -> string:
    if status_ != STATUS-CONFMODE:
      debug-print_ "Error [get_con_status]: Not in Configuration mode"
      return ""

    send-command GET-CONNECTION-STATUS
    answer-or-timeout_
    return pop-data

  get-power-save:
    if status_ != STATUS-CONFMODE:
        return false
    send-command GET-POWERSAVE
    answer-or-timeout_
    return pop-data

  dev-info -> string:
    send-command GET-DEVICE-INFO
    return read-for-time


  /**
  Sets supported features

  Selects the features that are supported by the device.
  The $feature parameter must be ...

  Returns whether the operation was successful.
  */
  set-sup-features feature/string:
    is-valid := [FEATURE-ENABLE-FLOW-CONTROL,\
    FEATURE-NO-PROMPT          ,\
    FEATURE-FAST-MODE          ,\
    FEATURE-NO-BEACON-SCAN     ,\
    FEATURE-NO-CONNECT-SCAN    ,\
    FEATURE-NO-DUPLICATE-SCAN  ,\
    FEATURE-PASSIVE-SCAN       ,\
    FEATURE-UART-TRANSP-NO-ACK ,\
    FEATURE-MLDP-SUPPORT       ,\
    FEATURE-SCRIPT-ON-POWER-ON ,\
    FEATURE-RN4020-MLDP-STREAM ,\
    FEATURE-COMMAND-MODE-GUARD ].contains feature

    if not is-valid:
      print "Error [set_sup_features]: Feature: $feature is not in supported features set"
      return false
    else:
      debug-print_ "[set_sup_features]: The supported feature $feature is set with the command: $SET-SUPPORTED-FEATURES$feature"
      send-command SET-SUPPORTED-FEATURES+feature
      return is-expected-result_ AOK-RESP


  /**
  Sets default services

  This command sets the default services to be supported by the RN4870 in the GAP
  server role.
  Input : string value from SERVICES map
  Output: bool true if successfully executed
  */
  set-def-services service/string -> bool:
    is-valid := [SERVICES-UART-AND-BEACON,\
    SERVICES-NO-SERVICE,\
    SERVICES-DEVICE-INFO-SERVICE,\
    SERVICES-UART-TRANSP-SERVICE,\
    SERVICES-BEACON-SERVICE,\
    SERVICES-AIRPATCH-SERVICE].contains service

    if not is-valid:
      print "Error [set_def_services]: Value: $service is not a default service"
      return false
    else:
      debug-print_ "[set_def_services]: The default service $service is set with the command: $SET-DEFAULT-SERVICES$service"
      send-command SET-DEFAULT-SERVICES+service
      return is-expected-result_ AOK-RESP


  /**
  Clears all services

  Clears all settings of services and characteristics.
  A power cycle is required afterwards to make the changes effective.

  */
  clear-all-services:
    debug-print_ "[clear_all_services]"
    send-command CLEAR-ALL-SERVICES
    return is-expected-result_ AOK-RESP


  /**
  Starts Advertisement

  The controller is configured to send undirected connectable advertising events.

  */
  start-advertising:
    debug-print_ "[start_advertising]"
    send-command(START-DEFAULT-ADV)
    return is-expected-result_ AOK-RESP


  /**
  Stops Advertisement

  Stops advertisement started by the start_advertising method.

  */
  stop-advertising:
    debug-print_ "[stop_advertising]"
    send-command(STOP-ADV)
    return is-expected-result_ AOK-RESP


  /**
  Clears the advertising structure Immediately

  Makes the changes immediately effective without a reboot.

  */
  clear-immediate-advertising:
    debug-print_ "[clear_immediate_advertising]"
    send-command(CLEAR-IMMEDIATE-ADV)
    return is-expected-result_ AOK-RESP


  /**
  Clears the advertising structure in a permanent way

  The changes are saved into NVM only if other procedures require permanent
  configuration changes. A reboot is requested after executing this method.

  */
  clear-permanent-advertising:
    debug-print_ "[clear_permanent_advertising]"
    send-command CLEAR-PERMANENT-ADV
    return is-expected-result_ AOK-RESP


  /**
  Clears the Beacon structure immediately.

  Makes the changes immediately effective without a reboot.

  */
  clear-immediate-beacon:
    debug-print_ "[clear_immediate_beacon]"
    send-command CLEAR-IMMEDIATE-BEACON
    return is-expected-result_ AOK-RESP


  /**
  Clears the Beacon structure in a permanent way

  The changes are saved into NVM only if other procedures require permanent
  configuration changes. A reboot is requested after executing this method.

  */
  clear-permanent-beacon:
    debug-print_ "[clear_permanent_beacon]"
    send-command CLEAR-PERMANENT-BEACON
    return is-expected-result_ AOK-RESP



  /**
  Starts Advertising immediatly

  Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned
          number list in the Core Specification
          string ad_data is the string message to be advertised. The message is
          converted to the chain of hex ASCII values
  Output: bool true if successfully executed
  */
  start-immediate-advertising ad-type/string ad-data/string ->bool:
    is-valid := [AD-TYPES-FLAGS,\
    AD-TYPES-INCOMPLETE-16-UUID,\
    AD-TYPES-COMPLETE-16-UUID,\
    AD-TYPES-INCOMPLETE-32-UUID,\
    AD-TYPES-COMPLETE-32-UUID,\
    AD-TYPES-INCOMPLETE-128-UUID,\
    AD-TYPES-COMPLETE-128-UUID,\
    AD-TYPES-SHORTENED-LOCAL-NAME,\
    AD-TYPES-COMPLETE-LOCAL-NAME,\
    AD-TYPES-TX-POWER-LEVEL,\
    AD-TYPES-CLASS-OF-DEVICE,\
    AD-TYPES-SIMPLE-PAIRING-HASH,\
    AD-TYPES-SIMPLE-PAIRING-RANDOMIZER,\
    AD-TYPES-TK-VALUE,\
    AD-TYPES-SECURITY-OOB-FLAG,\
    AD-TYPES-SLAVE-CONNECTION-INTERVAL,\
    AD-TYPES-LIST-16-SERVICE-UUID,\
    AD-TYPES-LIST-128-SERVICE-UUID,\
    AD-TYPES-SERVICE-DATA,\
    AD-TYPES-MANUFACTURE-SPECIFIC-DATA].contains ad-type

    if not is-valid:
      print "Error [start_immediate_advertising]: ad_type $ad-type is not one of accepted types"
      return false
    else:
      debug-print_ "[start_immediate_advertising]: type $ad-type, data $ad-data "
      ad-data = convert-string-to-hex_ ad-data
      debug-print_ "Send command: $START-IMMEDIATE-ADV$ad-type,$ad-data"
      send-command "$START-IMMEDIATE-ADV$ad-type,$ad-data"
      return is-expected-result_ AOK-RESP


  /**
  Starts Advertising permanently

  A reboot is needed after issuing this method
  Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned
          number list in the Core Specification
          string ad_data is the string message to be advertised. The message is
          converted to the chain of hex ASCII values
  Output: bool true if successfully executed
  */
  start-permanent-advertising ad-type/string ad-data/string ->bool:
    is-valid := [AD-TYPES-FLAGS,\
    AD-TYPES-INCOMPLETE-16-UUID,\
    AD-TYPES-COMPLETE-16-UUID,\
    AD-TYPES-INCOMPLETE-32-UUID,\
    AD-TYPES-COMPLETE-32-UUID,\
    AD-TYPES-INCOMPLETE-128-UUID,\
    AD-TYPES-COMPLETE-128-UUID,\
    AD-TYPES-SHORTENED-LOCAL-NAME,\
    AD-TYPES-COMPLETE-LOCAL-NAME,\
    AD-TYPES-TX-POWER-LEVEL,\
    AD-TYPES-CLASS-OF-DEVICE,\
    AD-TYPES-SIMPLE-PAIRING-HASH,\
    AD-TYPES-SIMPLE-PAIRING-RANDOMIZER,\
    AD-TYPES-TK-VALUE,\
    AD-TYPES-SECURITY-OOB-FLAG,\
    AD-TYPES-SLAVE-CONNECTION-INTERVAL,\
    AD-TYPES-LIST-16-SERVICE-UUID,\
    AD-TYPES-LIST-128-SERVICE-UUID,\
    AD-TYPES-SERVICE-DATA,\
    AD-TYPES-MANUFACTURE-SPECIFIC-DATA].contains ad-type

    if not is-valid:
      print "Error [start_immediate_advertising]: ad_type $ad-type is not one of accepted types"
      return false
    else:
      debug-print_ "[start_permanent_advertising]: type $ad-type, data $ad-data "
      ad-data = convert-string-to-hex_ ad-data
      debug-print_ "Send command: $START-PERMANENT-ADV$ad-type,$ad-data"
      send-command "$START-PERMANENT-ADV$ad-type,$ad-data"
      return is-expected-result_ AOK-RESP


  /**
  Starts Beacon adv immediatly

  Input : Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned
          number list in the Core Specification
          string ad_data is the string message to be advertised. The message is
          converted to the chain of hex ASCII values
  Output: bool true if successfully executed
  */
  start-immediate-beacon ad-type/string ad-data/string ->bool:

    is-valid := [AD-TYPES-FLAGS,\
    AD-TYPES-INCOMPLETE-16-UUID,\
    AD-TYPES-COMPLETE-16-UUID,\
    AD-TYPES-INCOMPLETE-32-UUID,\
    AD-TYPES-COMPLETE-32-UUID,\
    AD-TYPES-INCOMPLETE-128-UUID,\
    AD-TYPES-COMPLETE-128-UUID,\
    AD-TYPES-SHORTENED-LOCAL-NAME,\
    AD-TYPES-COMPLETE-LOCAL-NAME,\
    AD-TYPES-TX-POWER-LEVEL,\
    AD-TYPES-CLASS-OF-DEVICE,\
    AD-TYPES-SIMPLE-PAIRING-HASH,\
    AD-TYPES-SIMPLE-PAIRING-RANDOMIZER,\
    AD-TYPES-TK-VALUE,\
    AD-TYPES-SECURITY-OOB-FLAG,\
    AD-TYPES-SLAVE-CONNECTION-INTERVAL,\
    AD-TYPES-LIST-16-SERVICE-UUID,\
    AD-TYPES-LIST-128-SERVICE-UUID,\
    AD-TYPES-SERVICE-DATA,\
    AD-TYPES-MANUFACTURE-SPECIFIC-DATA].contains ad-type

    if not is-valid:
      print "Error [start_immediate_beacon]: ad_type $ad-type is not one of accepted types"
      return false
    else:
      debug-print_ "[start_immediate_beacon]: type $ad-type, data $ad-data "
      ad-data = convert-string-to-hex_ ad-data
      debug-print_ "Send command: $START-IMMEDIATE-BEACON$ad-type,$ad-data"
      send-command "$START-IMMEDIATE-BEACON$ad-type,$ad-data"
      return is-expected-result_ AOK-RESP


  /**
  Starts Beacon adv permanently

  A reboot is needed after issuing this method
  Input : Input : value from AD_TYPES map - Bluetooth SIG defines AD types in the assigned
          number list in the Core Specification
          string ad_data is the string message to be advertised. The message is
          converted to the chain of hex ASCII values
  Output: bool true if successfully executed
  */
  start-permanent-beacon ad-type/string ad-data/string ->bool:
    is-valid := [AD-TYPES-FLAGS,\
    AD-TYPES-INCOMPLETE-16-UUID,\
    AD-TYPES-COMPLETE-16-UUID,\
    AD-TYPES-INCOMPLETE-32-UUID,\
    AD-TYPES-COMPLETE-32-UUID,\
    AD-TYPES-INCOMPLETE-128-UUID,\
    AD-TYPES-COMPLETE-128-UUID,\
    AD-TYPES-SHORTENED-LOCAL-NAME,\
    AD-TYPES-COMPLETE-LOCAL-NAME,\
    AD-TYPES-TX-POWER-LEVEL,\
    AD-TYPES-CLASS-OF-DEVICE,\
    AD-TYPES-SIMPLE-PAIRING-HASH,\
    AD-TYPES-SIMPLE-PAIRING-RANDOMIZER,\
    AD-TYPES-TK-VALUE,\
    AD-TYPES-SECURITY-OOB-FLAG,\
    AD-TYPES-SLAVE-CONNECTION-INTERVAL,\
    AD-TYPES-LIST-16-SERVICE-UUID,\
    AD-TYPES-LIST-128-SERVICE-UUID,\
    AD-TYPES-SERVICE-DATA,\
    AD-TYPES-MANUFACTURE-SPECIFIC-DATA].contains ad-type

    if not is-valid:
      print "Error [start_permanent_beacon]: ad_type $ad-type is not one of accepted types"
      return false
    else:
      debug-print_ "[start_permanent_beacon]: type $ad-type, data $ad-data "
      ad-data = convert-string-to-hex_ ad-data
      debug-print_ "Send command: $START-PERMANENT-BEACON$ad-type,$ad-data"
      send-command "$START-PERMANENT-BEACON$ad-type,$ad-data"
      return is-expected-result_ AOK-RESP


  /**
  Starts Scanning

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
  start-scanning --scan-interval-ms/int=0 --scan-window-ms/int=0 -> bool:
    if scan-interval-ms*scan-window-ms != 0:
      values := [2.5, scan-interval-ms, scan-interval-ms, 1024].sort

      if values.first == 2.5 and values.last == 1024:
        scan-interval :=  (scan-interval-ms / 0.625).to-int.stringify 16
        scan-window :=  (scan-window-ms / 0.625).to-int.stringify 16
        debug-print_ "[start_scanning] Custom scanning\nSend Command: $START-CUSTOM-SCAN$scan-interval,$scan-window"
        send-command "$START-CUSTOM-SCAN$scan-interval,$scan-window"
      else:
        print "Error [start_scanning]: input values out of range"
    else:
      debug-print_ "[start_scanning] Default scanning"
      send-command START-DEFAULT-SCAN
    return is-expected-result_ SCANNING-RESP


  /**
  Stops Scanning

  Stops scan process started by start_scanning() method

  */
  stop-scanning -> bool:
    debug-print_ "[stop_scanning]"
    send-command STOP-SCAN
    return is-expected-result_ AOK-RESP



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
  add-mac-addr-white-list --addr-type/string --ad-data/string ->bool:
    [PUBLIC-ADDRESS-TYPE, PRIVATE-ADDRESS-TYPE].do:
      if it == addr-type:
        debug-print_ "[add_mac_addr_white_list]: Send Command: $ADD-WHITE-LIST$addr-type,$ad-data"
        send-command "$ADD-WHITE-LIST$addr-type,$ad-data"
        return is-expected-result_ AOK-RESP

    print "Error [add_mac_addr_white_list]: received faulty input, $ADD-WHITE-LIST$addr-type,$ad-data"
    return false


  /**
  # Adds all currently bonded devices to the white list

  The random address in the white list can be resolved with this method for
  connection purpose. If the peer device changes its resolvable random address,
  the RN4870/71 is still able to detect that the different random addresses are
  from the same physical device, therefore, allows connection from such peer
  device. This feature is particularly useful if the peer device is a iOS or
  Android device which uses resolvable random.

  */
  add-bonded-white-list:
    debug-print_ "[add_bonded_white_list]"
    send-command ADD-BONDED-WHITE-LIST
    return is-expected-result_ AOK-RESP


  /**
  Clears the white list

  Once the white list is cleared, white list feature is disabled.

  */
  clear-white-list:
    debug-print_ "[clear_white_list]"
    send-command CLEAR-WHITE-LIST
    return is-expected-result_ AOK-RESP


  /**
  # Kills the active connection

  Disconnect the active BTLE link. It can be used in central or peripheral role.

  */
  kill-connection:
    debug-print_ "[kill_connection]"
    send-command KILL-CONNECTION
    return is-expected-result_ AOK-RESP


  /**
Gets the RSSI level.

  Get the signal strength in dBm of the last communication with the peer device.
  The signal strength is used to estimate the distance between the device and its
  remote peer.

  */
  get-RSSI -> string:
    debug-print_ "[get_RSSI]"
    send-command GET-RSSI-LEVEL
    result := extract-result(read-for-time --ms=INTERNAL-CMD-TIMEOUT-MS)
    return result


  /**
  Reboots the module with a software method

  Forces a complete device reboot (similar to a power cycle).
  After rebooting RN487x, all prior made setting changes takes effect.

  */
  reboot -> bool:
    send-command REBOOT
    if is-expected-result_ REBOOTING-RESP:
      sleep --ms=STATUS-CHANGE-TIMEOUT-MS
      debug-print_ "[reboot] Software reboot succesfull"
      return true
    else:
      sleep --ms=STATUS-CHANGE-TIMEOUT-MS
      debug-print_ "[reboot] Software reboot failed"
      return false


  /**
  Sets the service UUID

  Sets the UUID of the public or the private service.
  This method must be called before the $set-charact-UUID method.

  The $uuid string contains the hex ID, which can be either a 16-bit UUID for
  public service or a 128-bit UUID for private service.
  */
  set-service-UUID uuid/string -> bool:
    if not validate-input-hex-data_ uuid:
      print "Error [set_service_UUID]: $uuid is not a valid hex value"
      return false
    if (uuid.size == PRIVATE-SERVICE-LEN):
      debug-print_("[set_service_UUID]: Set public UUID")
    else if (uuid.size == PUBLIC-SERVICE-LEN):
      debug-print_("[set_service_UUID]: Set private UUID")
    else:
      print("Error [set_service_UUID]: received wrong UUID length. Should be 16 or 128 bit hexidecimal number\nExample: PS,010203040506070809000A0B0C0D0E0F")
      return false
    debug-print_ "[set_service_UUID] Send command: $DEFINE-SERVICE-UUID$uuid"
    send-command "$DEFINE-SERVICE-UUID$uuid"
    return is-expected-result_ AOK-RESP


  /**
  Sets the private characteristic.

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
  set-charact-UUID --uuid/string --octet-len-int/int=-1 --property-list/List --property-hex/string="00" --octet-len-hex/string="EMPTY"-> bool:
    if octet-len-hex=="EMPTY" and octet-len-int!=-1:
      octet-len-hex = octet-len-int.stringify 16
      if octet-len-hex.size == 1:
        octet-len-hex = "0"+octet-len-hex

    else if octet-len-hex!="EMPTY" and octet-len-int==-1:
      octet-len-int = int.parse octet-len-hex --radix=16
    else:
      print "Error [set_charact_UUID]: You have to input either integer or hex value of octetLen"
      return false

    tempProp := 0
    property-list.do:
      if not [CHAR-PROPS-INDICATE, CHAR-PROPS-NOTIFY, CHAR-PROPS-WRITE, CHAR-PROPS-WRITE-NO-RESP, CHAR-PROPS-READ].contains it:
        print "Error [set_charact_UUID]: received unknown property $it"
        return false
      else:
        tempProp = tempProp + it
    property-hex = tempProp.stringify 16

    [uuid, property-hex, octet-len-hex].do:
      if not validate-input-hex-data_ it:
        print "Error [set_charact_UUID]: Value $it is not in correct hex format"
        return false

    if not  1 <= octet-len-int <= 20:
      print "Error [set_charact_UUID]: octet_len_hex 0x$octet-len-hex is out of range, should be between 0x1 and 0x14 in hex format "
      return false
    else if not validate-input-hex-data_ uuid:
      print "Error [set_charact_UUID]: $uuid is not a valid hex value"
      return false

    if uuid.size == PRIVATE-SERVICE-LEN:
      debug-print_ "[set_charact_UUID]: Set public UUID"
    else if uuid.size == PUBLIC-SERVICE-LEN:
      debug-print_ "[set_charact_UUID]: Set private UUID"
    else:
      print "Error [set_charact_UUID]: received wrong UUID length. Should be 16 or 128 bit hexidecimal number)"
      return false

    debug-print_ "[set_charact_UUID]: Send command $DEFINE-CHARACT-UUID$uuid,$property-hex,$octet-len-hex"
    send-command "$DEFINE-CHARACT-UUID$uuid,$property-hex,$octet-len-hex"
    return is-expected-result_ AOK-RESP


  /**
  # Writes local characteristic value as server

  Writes content of characteristic in Server Service to local device by addressing
  its handle
  Input :  string handle which corresponds to the characteristic of the server service
           string value is the content to be written to the characteristic
  Output: bool true if successfully executed
  */
  write-local-characteristic --handle/string --value/string -> bool:
    debug-print_ "[write_local_characteristic]: Send command $WRITE-LOCAL-CHARACT$handle,$value"
    send-command "$WRITE-LOCAL-CHARACT$handle,$value"
    return is-expected-result_ AOK-RESP


  /**
  # Reads local characteristic value as server

  Reads the content of the server service characteristic on the local device
    by addressing its handle.
  This method is effective with or without an active connection.
  Input : string handle which corresponds to the characteristic of the server service
  Output: string with result
  */
  read-local-characteristic --handle/string -> string:
    debug-print_ "[read_local_characteristic]: Send command $READ-LOCAL-CHARACT$handle "
    send-command "$READ-LOCAL-CHARACT$handle"
    result := extract-result read-for-time
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
  get-connection-status --time-ms=10000 -> string:
    debug-print_ "[get_connection_status]: Send command $GET-CONNECTION-STATUS"
    send-command GET-CONNECTION-STATUS
    result := extract-result (read-for-time --ms=time-ms)
    if result == NONE-RESP:
      debug-print_ "[get_connection_status]: $NONE-RESP"
    else if result == "":
      print "Error: [get_connection_status] connection timeout"
    return result

// ---------------------------------------- Private section ----------------------------------------


  /**
  Sets and get settings

  The Set command starts with character “S” and followed by one or two character
  configuration identifier. All Set commands take at least one parameter
  that is separated from the command by a comma. Set commands change configurations
  and take effect after rebooting either via R,1 command, Hard Reset, or power cycle.
  Most Set commands have a corresponding Get command to retrieve and output the
  current configurations via the UART. Get commands have the same command
  identifiers as Set commands but without parameters.
  */
  set-settings --addr/string --value/string -> bool:
    // Manual insertion of settings
    debug-print_ "[set_settings]: Send command $SET-SETTINGS$addr,$value"
    send-command "$SET-SETTINGS$addr,$value"
    return is-expected-result_ AOK-RESP


  /**
  # Configures the Beacon Feature

  Input : string value from BEACON_SETTINGS map
  Output: return true if successfully executed
  */
  set-beacon-features value/string -> bool:
    is-valid := [BEACON-SETTINGS-ADV-ON, BEACON-SETTINGS-OFF, BEACON-SETTINGS-OFF].contains value

    if is-valid:
      debug-print_ "[set_beacon_features]: set the Beacon Feature to $value"
      send-command SET-BEACON-FEATURES+value
      return is-expected-result_ AOK-RESP
    else:
      print "Error [set_beacon_features]: Value $value is not in beacon commands set"
      return false


  /// # Gets setting from selected address
  get-settings addr/string -> string:
    debug-print_ "[get_settings]: Send command $GET-SETTINGS$addr"
    send-command GET-SETTINGS + addr
    answer-or-timeout_
    return pop-data

  set-adv-power value/int -> bool:
    if value > MAX-POWER-OUTPUT:
      value = MAX-POWER-OUTPUT
    else if value < MIN-POWER-OUTPUT:
      value = MIN-POWER-OUTPUT
    debug-print_ "[set_adv_power]: Send command $SET-ADV-POWER$value"
    send-command "$SET-ADV-POWER$value"
    return is-expected-result_ AOK-RESP

  set-conn-power value/int -> bool:
    if value > MAX-POWER-OUTPUT:
      value = MAX-POWER-OUTPUT
    else if value < MIN-POWER-OUTPUT:
      value = MIN-POWER-OUTPUT
    debug-print_ "[set_conn_power]: Send command $SET-CONN-POWER$value"
    send-command "$SET-CONN-POWER$value"
    return is-expected-result_ AOK-RESP


  /**
  Sets the module to Dormant

  Immediately forces the device into lowest power mode possible.
  Removing the device from Dormant mode requires power reset.

  */
  dormant-mode -> none:
    debug-print_ "[dormant_mode]"
    send-command SET-DORMANT-MODE
    sleep --ms=INTERNAL-CMD-TIMEOUT-MS
