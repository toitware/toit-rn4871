import gpio
import gpio.adc show Adc

main:
    //test_analog_pin := gpio.Pin 33
    henr1 := Adc (gpio.Pin 34)
    henr0_460 := Adc (gpio.Pin 35)
    initial_time := Time.now
    duration := Duration.since initial_time
    list := []
    initial_time = Time.now


    //while true:
    while true:
        5.repeat:
            duration = Duration.since initial_time
            list = list + [duration.in_ms/1000.0, henr1.get/1024.0, henr0_460.get/1024.0]
            
            sleep --ms=7
        print list
        list =[]