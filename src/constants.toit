// Copyright 2021 Toitware ApS.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

INTERNAL-CMD-TIMEOUT-MS    ::= 300 // 1000 mSec = 1Sec.
STATUS-CHANGE-TIMEOUT-MS   ::= 1000


// ------------------- Response -----------------------
PROMPT                  ::= "CMD>"  // exact prompt is "CMD> " (last char is a space)
PROMPT-END              ::= "END"

//-- Response
AOK-RESP                ::= "AOK"
ERR-RESP                ::= "Err"
FACTORY-RESET-RESP      ::= "Reboot after Factory Reset"
DEVICE-MODEL            ::= "RN"
REBOOTING-RESP          ::= "Rebooting"
NONE-RESP               ::= "none"
SCANNING-RESP           ::= "Scanning"

//-- Events
REBOOT-EVENT            ::= "%REBOOT%"

PROMPT-FIRST-CHAR       ::= 'C'
PROMPT-LAST-CHAR        ::= '>'
PROMPT-LEN              ::=  4
PROMPT-END-FIST-CHAR    ::= 'E'
PROMPT-END-LAST-CHAR    ::= 'D'
PROMPT-ERROR            ::= "Err"

CRLF                    ::= "\r\n"
CR                      ::= "\r"
LF                      ::= "\n"
CONF-COMMAND            ::= "\$\$\$"

// -- Commands
FACTORY-RESET           ::= "SF,1"
EXIT-COMMAND            ::= "---\r"

AUTO-RANDOM-ADDRESS     ::= "&R"
USER-RANDOM-ADDRESS     ::= "&,"

SET-NAME                ::= "SN,"
GET-MODEL-NUMBER        ::= "GDM"

SET-BAUDRATE            ::= "SB,"
GET-BAUDRATE            ::= "GB"

GET-POWERSAVE           ::= "GO"

GET-HWVERSION           ::= "GDH"
GET-SWVERSION           ::= "GDR"
GET-SERIALNUM           ::= "GDS"
GET-DEVICE-INFO         ::= "D"

// -- Status enums
STATUS-ENTER-DATAMODE      ::= 0
STATUS-DATAMODE           ::= 1
STATUS-ENTER-CONFMODE     ::= 2
STATUS-CONFMODE           ::= 3

// -- Answers enums
ANSWER-NONE       ::= 1
ANSWER-PARTIAL    ::= 2
ANSWER-COMPLETE   ::= 3
ANSWER-DATA       ::= 4

// Baudrate settings
BAUDRATES-460800 ::= "01"
BAUDRATES-921600 ::= "00"
BAUDRATES-230400 ::= "02"
BAUDRATES-115200 ::= "03"
BAUDRATES-57600  ::= "04"
BAUDRATES-38400  ::= "05"
BAUDRATES-28800  ::= "06"
BAUDRATES-19200  ::= "07"
BAUDRATES-14400  ::= "08"
BAUDRATES-9600   ::= "09"
BAUDRATES-4800   ::= "0A"
BAUDRATES-2400   ::= "0B"


// -- Set Commands
SET-BEACON-FEATURES  ::= "SC,"

BEACON-SETTINGS-OFF ::= "0"
BEACON-SETTINGS-ON ::= "1"
BEACON-SETTINGS-ADV-ON ::= "2"

SET-ADV-POWER           ::=  "SGA,"
SET-CONN-POWER          ::=  "SGC,"
MIN-POWER-OUTPUT        ::=   0
MAX-POWER-OUTPUT        ::=   5
SET-SERIALIZED-NAME     ::=  "S-,"
MAX-SERIALIZED-NAME-LEN ::=  15
SET-DEVICE-NAME         ::= "SN,"
MAX-DEVICE-NAME-LEN     ::=  20
SET-LOW-POWER-ON        ::= "SO,1"
SET-LOW-POWER-OFF       ::= "SO,0"
SET-DORMANT-MODE        ::= "O,0"
SET-SETTINGS            ::= "S"

SET-SUPPORTED-FEATURES ::= "SR,"
// > Map of supported features
FEATURE-ENABLE-FLOW-CONTROL ::= "8000"
FEATURE-NO-PROMPT           ::= "4000"
FEATURE-FAST-MODE           ::= "2000"
FEATURE-NO-BEACON-SCAN      ::= "1000"
FEATURE-NO-CONNECT-SCAN     ::= "0800"
FEATURE-NO-DUPLICATE-SCAN   ::= "0400"
FEATURE-PASSIVE-SCAN        ::= "0200"
FEATURE-UART-TRANSP-NO-ACK  ::= "0100"
FEATURE-MLDP-SUPPORT        ::= "0080"
FEATURE-SCRIPT-ON-POWER-ON  ::= "0040"
FEATURE-RN4020-MLDP-STREAM  ::= "0020"
FEATURE-COMMAND-MODE-GUARD  ::= "0008"

SET-DEFAULT-SERVICES::="SS,"
// > Bitmap of services
SERVICES-UART-AND-BEACON     ::=  "C0"
SERVICES-NO-SERVICE          ::=  "00"
SERVICES-DEVICE-INFO-SERVICE ::=  "80"//0x80
SERVICES-UART-TRANSP-SERVICE ::=  "40"//0x40
SERVICES-BEACON-SERVICE      ::=  "20"//0x20
SERVICES-AIRPATCH-SERVICE    ::=  "10"//0x10

//-- Get Commands
GET-SETTINGS          ::= "G"
GET-DEVICE-NAME       ::= "GN"
GET-CONNECTION-STATUS ::= "GK"

//-- Action Commands
START-DEFAULT-ADV       ::= "A"
START-CUSTOM-ADV        ::= "A,"
STOP-ADV                ::= "Y"
CLEAR-IMMEDIATE-ADV     ::= "IA,Z"
CLEAR-PERMANENT-ADV     ::= "NA,Z"
CLEAR-IMMEDIATE-BEACON  ::= "IB,Z"
CLEAR-PERMANENT-BEACON  ::= "NB,Z"
START-IMMEDIATE-ADV     ::= "IA,"
START-PERMANENT-ADV     ::= "NA,"
START-IMMEDIATE-BEACON  ::= "IB,"
START-PERMANENT-BEACON  ::= "NB,"

// > Map of supported advertisement types
AD-TYPES-FLAGS                     ::= "01"
AD-TYPES-INCOMPLETE-16-UUID        ::= "02"
AD-TYPES-COMPLETE-16-UUID          ::= "03"
AD-TYPES-INCOMPLETE-32-UUID        ::= "04"
AD-TYPES-COMPLETE-32-UUID          ::= "05"
AD-TYPES-INCOMPLETE-128-UUID       ::= "06"
AD-TYPES-COMPLETE-128-UUID         ::= "07"
AD-TYPES-SHORTENED-LOCAL-NAME      ::= "08"
AD-TYPES-COMPLETE-LOCAL-NAME       ::= "09"
AD-TYPES-TX-POWER-LEVEL            ::= "0A"
AD-TYPES-CLASS-OF-DEVICE           ::= "0D"
AD-TYPES-SIMPLE-PAIRING-HASH       ::= "0E"
AD-TYPES-SIMPLE-PAIRING-RANDOMIZER ::= "0F"
AD-TYPES-TK-VALUE                  ::= "10"
AD-TYPES-SECURITY-OOB-FLAG         ::= "11"
AD-TYPES-SLAVE-CONNECTION-INTERVAL ::= "12"
AD-TYPES-LIST-16-SERVICE-UUID      ::= "14"
AD-TYPES-LIST-128-SERVICE-UUID     ::= "15"
AD-TYPES-SERVICE-DATA              ::= "16"
AD-TYPES-MANUFACTURE-SPECIFIC-DATA ::= "FF"

START-DEFAULT-SCAN   ::= "F"
START-CUSTOM-SCAN    ::= "F,"
STOP-SCAN            ::= "X"
ADD-WHITE-LIST       ::= "JA,"
MAX-WHITE-LIST-SIZE  ::=  16
MAC-ADDRESS-LEN      ::=  12
PUBLIC-ADDRESS-TYPE  ::= "0"
PRIVATE-ADDRESS-TYPE ::= "1"
ADD-BONDED-WHITE-LIST::= "JB"
CLEAR-WHITE-LIST     ::= "JC"
KILL-CONNECTION      ::= "K,1"
GET-RSSI-LEVEL       ::= "M"
REBOOT               ::= "R,1"
DISPLAY-FW-VERSION   ::= "V"

// --- Service Definition
DEFINE-CHARACT-UUID  ::= "PC,"
DEFINE-SERVICE-UUID  ::= "PS,"
CLEAR-ALL-SERVICES   ::= "PZ"
PRIVATE-SERVICE-LEN  ::=  32  // 128-bit
PUBLIC-SERVICE-LEN   ::=  4   // 16-bit

// -- Characteristic properties

CHAR-PROPS-INDICATE      ::= 0x20
CHAR-PROPS-NOTIFY        ::= 0x10
CHAR-PROPS-WRITE         ::= 0x08
CHAR-PROPS-WRITE-NO-RESP ::= 0x04
CHAR-PROPS-READ          ::= 0x02

// -- Characteristic Access
READ-REMOTE-CHARACT  ::= "CHR,"
WRITE-REMOTE-CHARACT ::= "CHW,"
DISCOVER-REMOTE      ::= "CI"  // start client role
READ-LOCAL-CHARACT   ::= "SHR,"
WRITE-LOCAL-CHARACT  ::= "SHW,"
