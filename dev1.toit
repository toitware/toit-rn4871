import serial.ports.uart
import gpio
import .rn4871 show *
import .constants show *

RX_PIN ::= 32
TX_PIN ::= 33
RESET_PIN ::= 25



main:
  tx_pin := gpio.Pin TX_PIN
  rx_pin := gpio.Pin RX_PIN 
  rst_pin := gpio.Pin RESET_PIN --input=false --output=true --pull_up=true --pull_down=false
  
  device := RN4871 --tx=tx_pin --rx=rx_pin --reset_pin=rst_pin --baud_rate=115200 
  device.pinReboot
  device.enterConfigurationMode
  device.setConnPower 5
  device.setDefServices SERVICE_UART_TRANSP_SERVICE
  device.setBeaconFeatures BEACON_ADV_ON
  device.setSupFeatures FEATURE_UART_TRANSP_NO_ACK
  print device.devInfo
  device.enterDataMode
  //device.listenToUart --ms=20000