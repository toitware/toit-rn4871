// Copyright 2021 Krzysztof Mróz. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

INTERNAL_CMD_TIMEOUT_MS    ::= 300 // 1000 mSec = 1Sec.
STATUS_CHANGE_TIMEOUT_MS   ::= 1000


// ------------------- Response -----------------------
PROMPT                  ::= "CMD>"  // exact prompt is "CMD> " (last char is a space)
PROMPT_END              ::= "END"

//-- Response
AOK_RESP                ::= "AOK"
ERR_RESP                ::= "Err"
FACTORY_RESET_RESP      ::= "Reboot after Factory Reset"
DEVICE_MODEL            ::= "RN"
REBOOTING_RESP          ::= "Rebooting"
NONE_RESP               ::= "none"
SCANNING_RESP           ::= "Scanning"		

//-- Events
REBOOT_EVENT            ::= "%REBOOT%"
PROMPT_FIRST_CHAR       ::= 'C'
PROMPT_LAST_CHAR        ::= '>'
PROMPT_LEN              ::=  4
PROMPT_END_FIST_CHAR    ::= 'E'
PROMPT_END_LAST_CHAR    ::= 'D'
PROMPT_ERROR            ::= "Err"

CRLF                    ::= "\r\n"
CR                      ::= "\r"
LF                      ::= "\n"
CONF_COMMAND            ::= "\$\$\$"

// -- Commands
FACTORY_RESET           ::= "SF,1"
EXIT_COMMAND            ::= "---\r"

AUTO_RANDOM_ADDRESS     ::= "&R"
USER_RANDOM_ADDRESS     ::= "&,"

SET_NAME                ::= "SN,"
GET_MODEL_NUMBER        ::= "GDM"
 
SET_BAUDRATE            ::= "SB,"
GET_BAUDRATE            ::= "GB"
 
GET_POWERSAVE           ::= "GO"
 
GET_HWVERSION           ::= "GDH"
GET_SWVERSION           ::= "GDR"
GET_SERIALNUM           ::= "GDS"
GET_DEVICE_INFO         ::= "D"

// -- Status enums
STATUS_ENTER_DATAMODE      ::= 0
STATUS_DATAMODE           ::= 1
STATUS_ENTER_CONFMODE     ::= 2
STATUS_CONFMODE           ::= 3

// -- Answers enums    
ANSWER_NONE       ::= 1
ANSWER_PARTIAL    ::= 2
ANSWER_COMPLETE   ::= 3
ANSWER_DATA       ::= 4

// Baudrate settings
BAUDRATES_460800 ::= "01"
BAUDRATES_921600 ::= "00"
BAUDRATES_230400 ::= "02"
BAUDRATES_115200 ::= "03"
BAUDRATES_57600  ::= "04"
BAUDRATES_38400  ::= "05"
BAUDRATES_28800  ::= "06"
BAUDRATES_19200  ::= "07"
BAUDRATES_14400  ::= "08"
BAUDRATES_9600   ::= "09"
BAUDRATES_4800   ::= "0A"
BAUDRATES_2400   ::= "0B"


// -- Set Commands
SET_BEACON_FEATURES  ::= "SC,"

BEACON_SETTINGS_OFF ::= "0"
BEACON_SETTINGS_ON ::= "1"
BEACON_SETTINGS_ADV_ON ::= "2"

SET_ADV_POWER           ::=  "SGA,"
SET_CONN_POWER          ::=  "SGC,"
MIN_POWER_OUTPUT        ::=   0
MAX_POWER_OUTPUT        ::=   5
SET_SERIALIZED_NAME     ::=  "S-,"
MAX_SERIALIZED_NAME_LEN ::=  15
SET_DEVICE_NAME         ::= "SN,"
MAX_DEVICE_NAME_LEN     ::=  20
SET_LOW_POWER_ON        ::= "SO,1"
SET_LOW_POWER_OFF       ::= "SO,0"
SET_DORMANT_MODE        ::= "O,0"
SET_SETTINGS            ::= "S"

SET_SUPPORTED_FEATURES ::= "SR,"
// > Map of supported features
FEATURE_ENABLE_FLOW_CONTROL ::= "8000"
FEATURE_NO_PROMPT           ::= "4000"
FEATURE_FAST_MODE           ::= "2000"
FEATURE_NO_BEACON_SCAN      ::= "1000"
FEATURE_NO_CONNECT_SCAN     ::= "0800"
FEATURE_NO_DUPLICATE_SCAN   ::= "0400"
FEATURE_PASSIVE_SCAN        ::= "0200"
FEATURE_UART_TRANSP_NO_ACK  ::= "0100"
FEATURE_MLDP_SUPPORT        ::= "0080"
FEATURE_SCRIPT_ON_POWER_ON  ::= "0040"
FEATURE_RN4020_MLDP_STREAM  ::= "0020"
FEATURE_COMMAND_MODE_GUARD  ::= "0008"

SET_DEFAULT_SERVICES::="SS,"
// > Bitmap of services
SERVICES_UART_AND_BEACON     ::=  "C0"
SERVICES_NO_SERVICE          ::=  "00"
SERVICES_DEVICE_INFO_SERVICE ::=  "80"//0x80
SERVICES_UART_TRANSP_SERVICE ::=  "40"//0x40
SERVICES_BEACON_SERVICE      ::=  "20"//0x20
SERVICES_AIRPATCH_SERVICE    ::=  "10"//0x10
    
//-- Get Commands
GET_SETTINGS          ::= "G"
GET_DEVICE_NAME       ::= "GN"
GET_CONNECTION_STATUS ::= "GK"

//-- Action Commands
START_DEFAULT_ADV       ::= "A"
START_CUSTOM_ADV        ::= "A,"
STOP_ADV                ::= "Y"
CLEAR_IMMEDIATE_ADV     ::= "IA,Z"
CLEAR_PERMANENT_ADV     ::= "NA,Z"
CLEAR_IMMEDIATE_BEACON  ::= "IB,Z"
CLEAR_PERMANENT_BEACON  ::= "NB,Z"
START_IMMEDIATE_ADV     ::= "IA,"
START_PERMANENT_ADV     ::= "NA,"
START_IMMEDIATE_BEACON  ::= "IB,"
START_PERMANENT_BEACON  ::= "NB,"

AD_TYPES ::= {
    "FLAGS"                     :"01",
    "INCOMPLETE_16_UUID"        :"02",
    "COMPLETE_16_UUID"          :"03",
    "INCOMPLETE_32_UUID"        :"04",
    "COMPLETE_32_UUID"          :"05",
    "INCOMPLETE_128_UUID"       :"06",
    "COMPLETE_128_UUID"         :"07",
    "SHORTENED_LOCAL_NAME"      :"08",
    "COMPLETE_LOCAL_NAME"       :"09",
    "TX_POWER_LEVEL"            :"0A",
    "CLASS_OF_DEVICE"           :"0D",
    "SIMPLE_PAIRING_HASH"       :"0E",
    "SIMPLE_PAIRING_RANDOMIZER" :"0F",
    "TK_VALUE"                  :"10",
    "SECURITY_OOB_FLAG"         :"11",
    "SLAVE_CONNECTION_INTERVAL" :"12",
    "LIST_16_SERVICE_UUID"      :"14",
    "LIST_128_SERVICE_UUID"     :"15",
    "SERVICE_DATA"              :"16",
    "MANUFACTURE_SPECIFIC_DATA" :"FF"
    }



START_DEFAULT_SCAN   ::= "F"
START_CUSTOM_SCAN    ::= "F,"
STOP_SCAN            ::= "X"
ADD_WHITE_LIST       ::= "JA,"
MAX_WHITE_LIST_SIZE  ::=  16
MAC_ADDRESS_LEN      ::=  12
PUBLIC_ADDRESS_TYPE  ::= "0"
PRIVATE_ADDRESS_TYPE ::= "1"
ADD_BONDED_WHITE_LIST::= "JB"
CLEAR_WHITE_LIST     ::= "JC"
KILL_CONNECTION      ::= "K,1"
GET_RSSI_LEVEL       ::= "M"
REBOOT               ::= "R,1"
DISPLAY_FW_VERSION   ::= "V"

// --- Service Definition
DEFINE_CHARACT_UUID  ::= "PC,"
DEFINE_SERVICE_UUID  ::= "PS,"
CLEAR_ALL_SERVICES   ::= "PZ"
PRIVATE_SERVICE_LEN  ::=  32  // 128-bit
PUBLIC_SERVICE_LEN   ::=  4   // 16-bit

// -- Characteristic properties
CHAR_PROPS ::= {
    "INDICATE"      : 0x20,
    "NOTIFY"        : 0x10,
    "WRITE"         : 0x08,
    "WRITE_NO_RESP" : 0x04,
    "READ"          : 0x02
    }

// -- Characteristic Access
READ_REMOTE_CHARACT  ::= "CHR,"
WRITE_REMOTE_CHARACT ::= "CHW,"
DISCOVER_REMOTE      ::= "CI"  // start client role
READ_LOCAL_CHARACT   ::= "SHR,"
WRITE_LOCAL_CHARACT  ::= "SHW,"
