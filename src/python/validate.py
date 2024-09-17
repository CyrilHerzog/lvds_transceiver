#---------------------------------------------------------------------------------------------------------------
#    File    : validate 
#    Version : 1.0
#    Author  : Herzog Cyril
#    Date    : 11.08.2024
#
#
#   pyserial red/write lsb first
#
#   info: 
#   define PATTERN_NUM = [1] to see the loop cycles for a transmission for single transaction layer packet 
#   define PATTERN_NUM [> 1 < 8] to see the loop cycles for transmission the transaction layer packets 
#                                as multiframe    
#   ref_idleaye_clk 200 = 78, 300 = 56   
#---------------------------------------------------------------------------------------------------------------

import serial
import random
import time

################################################################################################################
# constant's
SINGLE_WRITE = 0b00100000
MULTI_WRITE  = 0b00110000
SINGLE_READ  = 0b00000000
MULTI_READ   = 0b00010000
WRITE_BANK_P = 0b00001000
READ_BANK_L  = 0b00001000

# define numer of pattern's for transfered in loop
PATTERN_NUM = 7 # 0 - 7 => 0 = 1 pattern / 7 = 8 pattern

def reverse_bits(byte):
    """lsb => msb"""
    return int('{:08b}'.format(byte)[::-1], 2)


def generate_random_numbers(num_bytes=2):
    return [random.randint(0, 255) for _ in range(num_bytes)]



# uart - parameter
ser = serial.Serial(
    'COM3',      # define your com - port 
    115200,
    timeout=5,
    parity=serial.PARITY_EVEN,
    stopbits=serial.STOPBITS_ONE,
    bytesize=serial.EIGHTBITS
)


# all commands must be written in lsb first!
try:
    
    ############################################################################################################
    # echo - test write and read two random bytes
    random_bytes = generate_random_numbers(2)   
    print(f"send data (dec): {random_bytes}")
    ser.write(bytes([reverse_bits(SINGLE_WRITE) | 0b11100000])) 
    ser.write(bytes(random_bytes))  

    ser.write(bytes([reverse_bits(SINGLE_READ) | 0b11100000]))
    response = ser.read(2) 
    
    # check response
    dec_response = [byte for byte in response]
    print(f"receive data (dec): {dec_response}")
    if dec_response == random_bytes:
        print("test passed")
    else:
        print("test failed")

    # wait    
    time.sleep(1)

    ############################################################################################################
    # read edge tabs of both transceivers  

    # transceiver a
    ser.write(bytes([reverse_bits(SINGLE_READ) | 0b01000000])) # bank s address 2
    response = ser.read(2)
    
    if len(response) == 2:
        msb_converted = [reverse_bits(byte) for byte in response]
        msb_first_value = (msb_converted[0] << 8) | msb_converted[1]
        print(f"edge tabs - transceiver a (dec)): {msb_first_value}")
    else:
        print("error: read edge tabs - transceiver a")

    # wait    
    time.sleep(1)

    # transceiver b
    ser.write(bytes([reverse_bits(SINGLE_READ) | 0b00100000])) # bank s address 4
    response = ser.read(2)
    
    if len(response) == 2:
        msb_converted = [reverse_bits(byte) for byte in response]
        msb_first_value = (msb_converted[0] << 8) | msb_converted[1]
        print(f"edge tabs - transceiver b (dec)): {msb_first_value}")
    else:
        print("error: read edge tabs - transceiver b")

    # wait    
    time.sleep(1)


    ############################################################################################################
    # write pattern
    random_bytes = generate_random_numbers(56) 
    ser.write(bytes([reverse_bits(MULTI_WRITE) | reverse_bits(WRITE_BANK_P)]))
    
    
    # write pattern blockwise
    for i in range(0, len(random_bytes), 7):
        msg_split = random_bytes[i:i + 7]
        ser.write(bytes(msg_split))
        ser.flush() 
        time.sleep(0.1)  

    print(f"send pattern (dec): {random_bytes}")


    ##############################################################################################################
    # start single loop (transfer pattern from bank p to bank l by transceiver)
  
    ser.write(bytes([reverse_bits(SINGLE_WRITE) | 0b10000000])) # bank c address 1  
    ser.write(bytes([0b00000000]))
    ser.write(bytes([reverse_bits(PATTERN_NUM)])) # pattern num
    time.sleep(0.1)

    print("start single loop")
    ser.write(bytes([reverse_bits(SINGLE_WRITE) | 0b00000000])) # bank c address 0
    ser.write(bytes([0b00000000]))
    ser.write(bytes([0b10000000]))  # start single loop
    time.sleep(0.1)


    # read pattern 
    time.sleep(1.0) # wait
    ser.write(bytes([reverse_bits(MULTI_READ) | reverse_bits(READ_BANK_L)]))
    response = ser.read(56)
    dec_response = [byte for byte in response]
    print(f"received pattern (dec): {dec_response}")
    if dec_response == random_bytes:
        print("test passed")
    else:
        print("test failed")

    # read loop cycle
    time.sleep(1) # wait
    ser.write(bytes([reverse_bits(SINGLE_READ) | 0b10000000])) # bank s address 1
    response = ser.read(2)
    
    if len(response) == 2:
        msb_converted = [reverse_bits(byte) for byte in response]
        msb_first_value = (msb_converted[0] << 8) | msb_converted[1]
        print(f"loop cycle's (dec)): {msb_first_value}")
    else:
        print("error: read loop cycle's")

    
    ############################################################################################
    # continuous loop

    print("start continuous loop")
    ser.write(bytes([reverse_bits(SINGLE_WRITE) | 0b00000000])) # bank c address 0
    ser.write(bytes([0b00000000]))
    ser.write(bytes([0b01000000]))  # start continuous loop
    time.sleep(0.1)


    # read delay tabs while loop transfer


    for i in range(5):
        # transceiver a
        ser.write(bytes([reverse_bits(SINGLE_READ) | 0b11000000]))  # bank s address 3
        response = ser.read(2)

        if len(response) == 2:
            msb_converted = [reverse_bits(byte) for byte in response]
            msb_first_value = (msb_converted[0] << 8) | msb_converted[1]
            print(f"delay tabs - transceiver a (dec): {msb_first_value}")
        else:
            print("error: read delay tabs - transceiver a")

        # wait
        time.sleep(1)

        # transceiver b
        ser.write(bytes([reverse_bits(SINGLE_READ) | 0b10100000]))  # bank s address 5
        response = ser.read(2)

        if len(response) == 2:
            msb_converted = [reverse_bits(byte) for byte in response]
            msb_first_value = (msb_converted[0] << 8) | msb_converted[1]
            print(f"delay tabs - transceiver b (dec): {msb_first_value}")
        else:
            print("error: read delay tabs - transceiver b")

        # wait
        time.sleep(1)


    # stop loop
    print("stop continuous loop")
    ser.write(bytes([reverse_bits(SINGLE_WRITE) | 0b00000000])) # bank c address 0
    ser.write(bytes([0b00000000]))
    ser.write(bytes([0b00100000]))  # stop continuous loop
    time.sleep(0.1)


    # read pattern 
    time.sleep(1.0) # wait
    ser.write(bytes([reverse_bits(MULTI_READ) | reverse_bits(READ_BANK_L)]))
    response = ser.read(56)
    dec_response = [byte for byte in response]
    print(f"received pattern (dec): {dec_response}")
    if dec_response == random_bytes:
        print("test passed")
    else:
        print("test failed")

    # read loop cycle
    time.sleep(1) # wait
    ser.write(bytes([reverse_bits(SINGLE_READ) | 0b10000000])) # bank s address 1
    response = ser.read(2)
    
    if len(response) == 2:
        msb_converted = [reverse_bits(byte) for byte in response]
        msb_first_value = (msb_converted[0] << 8) | msb_converted[1]
        print(f"loop cycle's (dec)): {msb_first_value}")
    else:
        print("error: read loop cycle's")


    
finally:
    ser.close()















