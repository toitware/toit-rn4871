DELAY_INTERNAL_CMD ::= 5
INTERNAL_CMD_TIMEOUT ::= 300 // 1000 mSec = 1Sec.
STATUS_CHANGE_TIMEOUT ::= 1000
SMALL_ANSWER_DATA_LEN::= 20


// ------------------- Response -----------------------
PROMPT          ::=      "CMD>"  // exact prompt is "CMD> " (last char is a space)
PROMPT_END      ::=      "END"

//-- Response
AOK_RESP          ::=    "AOK"
ERR_RESP          ::=    "Err"
FACTORY_RESET_RESP  ::=  "Reboot after Factory Reset"
DEVICE_MODEL      ::=    "RN"
REBOOTING_RESP     ::=   "Rebooting"
NONE_RESP          ::=   "none"
SCANNING_RESP      ::=   "Scanning"		

//-- Events
REBOOT_EVENT      ::=    "%REBOOT%"
PROMPT_FIRST_CHAR::= 'C'
PROMPT_LAST_CHAR ::= '>'
PROMPT_LEN ::= 4
PROMPT_END_FIST_CHAR ::= 'E'
PROMPT_END_LAST_CHAR ::= 'D'
PROMPT_ERROR ::= "Err"

CRLF  ::=                "\r\n"
CR ::=                   "\r"
LF ::=                   "\n"

CONF_COMMAND::= "\$\$\$"

// commands
FACTORY_RESET::= "SF,1"
EXIT_CONF ::="---\r"

AUTO_RANDOM_ADDRESS::= "&R"
USER_RANDOM_ADDRESS::= "&,"

SET_NAME ::="SN,"
//GET_NAME ::="GDM"

SET_BAUDRATE ::="SB,"
GET_BAUDRATE ::="GB"

GET_POWERSAVE ::="GO"

GET_HWVERSION ::="GDH"
GET_SWVERSION ::="GDR"
GET_SERIALNUM ::="GDS"
GET_DEVICE_INFO ::= "D"
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
ENUM_BAUDRATE_4800 ::= 10
ENUM_BAUDRATE_2400 ::= 11

// Added from new repo
// ------------------- Commands -----------------------

// --- Set Commands
SET_BEACON_FEATURES  ::= "SC,"

BEACON_SETTINGS := {\
"OFF"  :  "0",\
"ON"    :  "1",\
"ADV_ON":  "2"\
}

SET_ADV_POWER  ::=       "SGA,"
SET_CONN_POWER  ::=      "SGC,"
MIN_POWER_OUTPUT::=  0
MAX_POWER_OUTPUT::= 5
SET_SERIALIZED_NAME::="S-,"
MAX_SERIALIZED_NAME_LEN ::= 15
SET_DEVICE_NAME::="SN,"
MAX_DEVICE_NAME_LEN::=20
SET_LOW_POWER_ON::=   "SO,1"
SET_LOW_POWER_OFF::=  "SO,0"
SET_DORMANT_MODE::=   "O,0"
SET_SETTINGS::=       "S"

SET_SUPPORTED_FEATURES ::= "SR,"
// > Bitmap of supported features
FEATURE_NO_BEACON_SCAN::= "4096"
FEATURE_NO_CONNECT_SCAN::="2048"
FEATURE_NO_DUPLICATE_SCAN::="1024"
FEATURE_PASSIVE_SCAN::=   "512"
FEATURE_UART_TRANSP_NO_ACK::="256"
FEATURE_MLDP_SUPPORT::=   "32"

SET_DEFAULT_SERVICES::="SS,"
// > Bitmap of services
SERVICE_NO_SERVICE::=          "0"
SERVICE_DEVICE_INFO_SERVICE::= "128"//0x80
SERVICE_UART_TRANSP_SERVICE::= "64"//0x40
SERVICE_BEACON_SERVICE::=      "32"//0x20
SERVICE_AIRPATCH_SERVICE::=    "16"//0x10

//-- Get Commands
GET_SETTINGS::=        "G"
GET_DEVICE_NAME::=     "GN"
GET_CONNECTION_STATUS::="GK"

//--- Action Commands
START_DEFAULT_ADV::=   "A"
START_CUSTOM_ADV::=    "A,"
STOP_ADV::=            "Y"
CLEAR_IMMEDIATE_ADV::= "IA,Z"
CLEAR_PERMANENT_ADV::=   "NA,Z"
CLEAR_IMMEDIATE_BEACON ::="IB,Z"
CLEAR_PERMANENT_BEACON::= "NB,Z"
START_IMMEDIATE_ADV ::=  "IA,"
START_PERMANENT_ADV ::=  "NA,"
START_IMMEDIATE_BEACON ::="IB,"
START_PERMANENT_BEACON ::="NB,"
/*
AD_TYPE_FLAGS ::=        "1"//0x01
AD_TYPE_INCOMPLETE_16_UUID ::="2"//0x02
AD_TYPE_COMPLETE_16_UUID::= "3"//0x03
AD_TYPE_INCOMPLETE_32_UUID::= "4"//0x04
AD_TYPE_COMPLETE_32_UUID ::="5"//0x05
AD_TYPE_INCOMPLETE_128_UUID ::="6"//0x06
AD_TYPE_COMPLETE_128_UUID ::="7"//0x07
AD_TYPE_SHORTENED_LOCAL_NAME::= "8"//0x08
AD_TYPE_COMPLETE_LOCAL_NAME ::="9"//0x09
AD_TYPE_TX_POWER_LEVEL ::="10"//0x0A
AD_TYPE_CLASS_OF_DEVICE::= "13"//0x0D
AD_TYPE_SIMPLE_PAIRING_HASH ::="14"//0x0E
AD_TYPE_SIMPLE_PAIRING_RANDOMIZER::= "15"//0x0F
AD_TYPE_TK_VALUE ::="16"//0x10
AD_TYPE_SECURITY_OOB_FLAG::= "17"//0x11
AD_TYPE_SLAVE_CONNECTION_INTERVAL ::="18"//0x12
AD_TYPE_LIST_16_SERVICE_UUID::= "20"//0x14
AD_TYPE_LIST_128_SERVICE_UUID::= "21"//0x15
AD_TYPE_SERVICE_DATA::= "22"//0x16
AD_TYPE_MANUFACTURE_SPECIFIC_DATA ::="255"//0xFF
*/
AD_TYPES := {\
"FLAGS":"1",\
"INCOMPLETE_16_UUID":"2",\
"COMPLETE_16_UUID":"3",\
"INCOMPLETE_32_UUID":"4",\
"COMPLETE_32_UUID":"5",\
"INCOMPLETE_128_UUID":"6",\
"COMPLETE_128_UUID":"7",\
"SHORTENED_LOCAL_NAME":"8",\
"COMPLETE_LOCAL_NAME":"9",\
"TX_POWER_LEVEL":"10",\
"CLASS_OF_DEVICE":"13",\
"SIMPLE_PAIRING_HASH":"14",\
"SIMPLE_PAIRING_RANDOMIZER":"15",\
"TK_VALUE":"16",\
"SECURITY_OOB_FLAG":"17",\
"SLAVE_CONNECTION_INTERVAL":"18",\
"LIST_16_SERVICE_UUID":"20",\
"LIST_128_SERVICE_UUID":"21",\
"SERVICE_DATA":"22",\
"MANUFACTURE_SPECIFIC_DATA":"255"}



START_DEFAULT_SCAN   ::= "F"
START_CUSTOM_SCAN  ::=   "F,"
STOP_SCAN          ::=   "X"
ADD_WHITE_LIST     ::=   "JA,"
MAX_WHITE_LIST_SIZE  ::= 16
MAC_ADDRESS_LEN     ::=  12
PUBLIC_ADDRESS_TYPE  ::= "0"
PRIVATE_ADDRESS_TYPE ::= "1"
ADD_BONDED_WHITE_LIST::= "JB"
CLEAR_WHITE_LIST  ::=    "JC"
KILL_CONNECTION   ::=    "K,1"
GET_RSSI_LEVEL    ::=    "M"
REBOOT            ::=    "R,1"
DISPLAY_FW_VERSION  ::=  "V"

// --- List Commands

// --- Service Definition
DEFINE_CHARACT_UUID ::=  "PC,"
DEFINE_SERVICE_UUID ::=  "PS,"
CLEAR_ALL_SERVICES  ::=  "PZ"
PRIVATE_SERVICE_LEN  ::= 32  // 128-bit
PUBLIC_SERVICE_LEN   ::= 4   // 16-bit
//Characteristic properties
CHAR_PROPS := {\
"INDICATE":"32",\
"NOTIFY":"16",\
"WRITE":"8",\
"WRITE_NO_RESP":"4",\
"READ": "2"}

// --- Characteristic Access
READ_REMOTE_CHARACT  ::= "CHR,"
WRITE_REMOTE_CHARACT ::= "CHW,"
DISCOVER_REMOTE    ::=   "CI"  // start client role
READ_LOCAL_CHARACT  ::=  "SHR,"
WRITE_LOCAL_CHARACT ::=  "SHW,"




