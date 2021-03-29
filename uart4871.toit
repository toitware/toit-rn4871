import serial.ports.uart show Port
import gpio

main:
    tx_pin := gpio.Pin 33
    rx_pin:= gpio.Pin 32 
    port4871 := Port --tx=tx_pin --rx=rx_pin --baud_rate=115200

    message := "\$\$\$"

    port4871.write message
    response := port4871.read.to_string

    print response