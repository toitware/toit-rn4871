import serial.ports.uart
import gpio

RX_PIN ::= 32
TX_PIN ::= 33
RESET_PIN ::= 25



main:
    tx_pin := gpio.Pin TX_PIN
    rx_pin := gpio.Pin RX_PIN 
    rst_pin := gpio.Pin RESET_PIN --input=false --output=true --pull_up=true --pull_down=false
    port4871 := serial.Port --tx=tx_pin --rx=rx_pin --baud_rate=115200
    message := ""

    // Reset
    rst_pin.set 0
    sleep --ms=50
    rst_pin.set 1
    sleep --ms=100
    
    // Read the reboot message
    response1 := port4871.read.to_string

    // Turn on the command mode
    message = "\$\$\$"
    port4871.write message
    response2 := port4871.read.to_string
    print response1
    print response2
    message = "GA\n"
    port4871.write message
    response3 := port4871.read.to_string
    print response3