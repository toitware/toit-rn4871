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
GET_MODEL_NUMBER ::="GDM"

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
BAUDRATES :={
    "460800" : "01",
    "921600" : "00",
    "230400" : "02",
    "115200" : "03",
    "57600"  : "04",
    "38400"  : "05",
    "28800"  : "06",
    "19200"  : "07",
    "14400"  : "08",
    "9600"   : "09",
    "4800"   : "0A",
    "2400"   : "0B"
    }
// Added from new repo
// ------------------- Commands -----------------------

// --- Set Commands
SET_BEACON_FEATURES  ::= "SC,"

BEACON_SETTINGS := {
    "OFF"  :  "0",
    "ON"    :  "1",
    "ADV_ON":  "2"}

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
// > Map of supported features
FEATURES := {
    "ENABLE_FLOW_CONTROL":"8000",
    "NO_PROMPT"          :"4000",
    "FAST_MODE"          :"2000",
    "NO_BEACON_SCAN"     :"1000",
    "NO_CONNECT_SCAN"    :"0800",
    "NO_DUPLICATE_SCAN"  :"0400",
    "PASSIVE_SCAN"       :"0200",
    "UART_TRANSP_NO_ACK" :"0100",
    "MLDP_SUPPORT"       :"0080",
    "SCRIPT_ON_POWER_ON" :"0040",
    "RN4020_MLDP_STREAM" :"0020",
    "COMMAND_MODE_GUARD" :"0008"
    }

SET_DEFAULT_SERVICES::="SS,"
// > Bitmap of services
SERVICES := {
    "UART_AND_BEACON"    : "C0",
    "NO_SERVICE"         : "00",
    "DEVICE_INFO_SERVICE": "80",//0x80
    "UART_TRANSP_SERVICE": "40",//0x40
    "BEACON_SERVICE"     : "20",//0x20
    "AIRPATCH_SERVICE"   : "10"//0x10
    }

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

AD_TYPES := {
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
    "MANUFACTURE_SPECIFIC_DATA" :"FF"}



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
CHAR_PROPS := {
    "INDICATE"      :0x20,
    "NOTIFY"        :0x10,
    "WRITE"         :0x08,
    "WRITE_NO_RESP" :0x04,
    "READ"          :0x02
    }

// --- Characteristic Access
READ_REMOTE_CHARACT  ::= "CHR,"
WRITE_REMOTE_CHARACT ::= "CHW,"
DISCOVER_REMOTE    ::=   "CI"  // start client role
READ_LOCAL_CHARACT  ::=  "SHR,"
WRITE_LOCAL_CHARACT ::=  "SHW,"
