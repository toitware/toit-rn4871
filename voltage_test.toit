import gpio
import gpio.adc show Adc

main:
    //test_analog_pin := gpio.Pin 33
    analog := Adc (gpio.Pin 33)
    initial_time := Time.now
    duration := Duration.since initial_time
    list := []
    initial_time = Time.now


    //while true:
    while true:
        20.repeat:
            duration = Duration.since initial_time
            list = list + [duration.in_ms, analog.get/1024.0]
            sleep --ms=7
        print list
        list =[]