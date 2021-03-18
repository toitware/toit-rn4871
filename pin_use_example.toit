import gpio
import gpio.adc show Adc

main:
    test_digital_pin := gpio.Pin 34 --input=true
    value := test_digital_pin.get
    print value

    //test_analog_pin := gpio.Pin 33
    analog := Adc (gpio.Pin 33)

    while true:
        print analog.get
        sleep --ms=1000