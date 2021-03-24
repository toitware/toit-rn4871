import serial.protocols.spi
import gpio

main:
    // Pins on RN4871:
    // SPI NCS Bus: P3_1
    // SPI MISO Pin: P3_2
    // SPI MOSI Pin: P3_3
    // SPI SCLK Pin: P3_4
    miso_pin := gpio.Pin 
    spi_bus := serial.Bus 
