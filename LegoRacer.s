/*
 * 
 * Written by Vangjush Ziko and David Minin
 * 
 * Some code modules were re-used from lecture notes and from the UofT NIOS II 
 * reference pages found at www-ug.eecg.toronto.edu/msl/nios.html
 *
 */
.equ PS2_BASE, 0xFF200100
.equ PS2_CONTROL, 0xFF200104
.equ JP1_BASE, 0xFF200060
.equ JP1_EDGE, 0xFF20006C
.equ ADDR_JP1_IRQ, 0x800
.equ TIMER0_BASE, 0xFF202000
.equ TIMER0_STATUS, 0
.equ TIMER0_CONTROL, 4
.equ TIMER0_PERIODL, 8
.equ TIMER0_PERIODH, 12
.equ TIMER0_SNAPL, 16
.equ TIMER0_SNAPH, 20
.equ TICKS_PER_SEC, 1250000
.equ ADDR_AUDIOCFIFO, 0xFF203040
.equ BEEP_SOUND, 0x31000000
.equ ADDR_7SEG1, 0xFF200020
.equ ADDR_7SEG2, 0xFF200030
.equ ADDR_SLIDESWITCHES, 0xFF200040

.text
.section .exceptions, "ax"

ihandler:
  subi sp, sp, 12
  stw r9, 0(sp)
  stw r10, 4(sp)
  stw r11, 8(sp)
  
  rdctl et, ipending
  beq et, r0, iepilogue
  
  subi ea, ea, 4
  
  andi r9, et, ADDR_JP1_IRQ
  beq r9, r0, iepilogue

sensor_interrupt:
  # check which sensor triggered interrupt
  movia r9, JP1_EDGE
  ldwio et, 0(r9)
  movia r10, 0x20000
  and r10, et, r10
  beq r10, r0, iepilogue
  
  stwio r0, 0(r9)
  
iepilogue:
  ldw r11, 8(sp)
  ldw r10, 4(sp)
  ldw r9, 0(sp)
  addi sp, sp, 12
  
  eret

.global _start
_start:
  movia sp, 0x03FFFFFC
  movia r8, JP1_BASE
  movia r9, 0x07f557ff        # set direction for motors to all output
  stwio r9, 4(r8)
  movia r9, 0xffffffff        # disable motors
  stwio r9, 0(r8)

  # load sensors 0-3 setting their thresholds and enabling the sensor
  # sensor 0 (front button)
  movia  r9,  0xffbffbff       # set motors off and enable threshold load sensor 0
  stwio  r9,  0(r8)            
  movia  r9,  0x006fffff       # disable threshold register and enable state mode
  stwio  r9,  0(r8)

  # sensor 1 (back button)
  movia  r9,  0xffbfefff       
  stwio  r9,  0(r8)            
  movia  r9,  0x006fffff       
  stwio  r9,  0(r8)

  # sensor 2 (front distance)
  #movia  r9,  0xfabfbfff       
  #stwio  r9,  0(r8)            
  #movia  r9,  0x006fffff       
  #stwio  r9,  0(r8)

  # sensor 3 (back distance)
  #movia  r9,  0xfabeffff       
  #stwio  r9,  0(r8)            
  #movia  r9,  0x004fffff       
  #stwio  r9,  0(r8)

  # enable interrupts on sensors
  movia  r12, 0x30000000
  stwio  r12, 8(r8)

  # enable interrupt for GPIO JP1 (IRQ12)
  movia  r9, ADDR_JP1_IRQ
  wrctl  ienable, r9
  
  # enable interrupts
  movi r9, 0x1
  wrctl status, r9

  # initializes first 3 key codes to 0
  movia r14, KeyPressArray3
  stw r0, 0(r14)
  movia r14, KeyPressArray2
  stw r0, 0(r14)
  movia r14, KeyPressArray1
  stw r0, 0(r14)

main:
  # get switch values and display on 7 segment display
  movia r14, ADDR_SLIDESWITCHES
  ldwio r4, 0(r14)
  call displayseg
 
  movia r14, PS2_BASE
  ldwio r12, 0(r14)
  andi r16, r12, 0x00ff
  andi r12, r12, 0x08000      # check if valid field is set
  beq r12, r0, stop           # valid bit is not 0
  
  # keeps track of the last 3 key codes
  movia r14, KeyPressArray2
  ldw r18, 0(r14)
  movia r15, KeyPressArray1
  stw r18, 0(r15)
  movia r14, KeyPressArray3
  ldw r18, 0(r14)
  movia r15, KeyPressArray2
  stw r18, 0(r15)

  # forward movement
  movia r14, KeyPressArray3
  stw r16, 0(r14)
  movui r13, 0x075
  beq r16, r13, forward
  movia r14, KeyPressArray2
  ldw r18, 0(r14)
  beq r18, r13, forward
  movia r14, KeyPressArray1
  ldw r18, 0(r14)
  beq r18, r13, forward

  # backward movement
  movui r13, 0x072
  beq r16, r13, backward
  movia r14, KeyPressArray2
  ldw r18, 0(r14)
  beq r18, r13, backward
  movia r14, KeyPressArray1
  ldw r18, 0(r14)
  beq r18, r13, backward
  
  # right movement
  movui r13, 0x074
  beq r16, r13, turn_right
  movia r14, KeyPressArray2
  ldw r18, 0(r14)
  beq r18, r13, turn_right
  movia r14, KeyPressArray1
  ldw r18, 0(r14)
  beq r18, r13, turn_right

  # left movement
  movui r13, 0x06B
  beq r16, r13, turn_left
  movia r14, KeyPressArray2
  ldw r18, 0(r14)
  beq r18, r13, turn_left
  movia r14, KeyPressArray1
  ldw r18, 0(r14)
  beq r18, r13, turn_left
  
  br stop

beep:
  # makes a beeping sound, is used in place for a car engine sound
  subi sp, sp, 8
  stw r16, 0(sp)
  stw r17, 4(sp)
 
  movia r16, ADDR_AUDIOCFIFO
  movia r17, BEEP_SOUND
  stwio r17, 8(r16)           # left channel
  stwio r17, 12(r16)          # right channel
  
  ldw r16, 0(sp)
  ldw r17, 4(sp)
  addi sp, sp, 8
  ret
  
turn_left:
  # turn the car in place to the left
  movia r11, 0xffdfff2
  stwio r11, 0(r8)
  call pwm

  movia r14, PS2_BASE
  ldwio r12, 0(r14)
  andi r16, r12, 0x00ff
  
  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  movia r15, KeyPressArray4
  stw r18, 0(r15)
  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  movia r15, KeyPressArray5
  stw r18, 0(r15)
  movia r14, KeyPressArray6
  stw r16, 0(r14)

  # need to read one more key to clear buffer
  movui r13, 0xF0
  beq r16, r13, readonemore     

  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  beq r18, r13, readonemore

  movia r14, KeyPressArray4
  ldw r18, 0(r14)
  beq r18, r13, readonemore
  
  br turn_left


turn_right:
  # moves the car in place to the right
  movia r11, 0xffdfff8
  stwio r11, 0(r8)
  call pwm

  movia r14, PS2_BASE
  ldwio r12, 0(r14)
  andi r16, r12, 0x00ff

  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  movia r15, KeyPressArray4
  stw r18, 0(r15)
  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  movia r15, KeyPressArray5
  stw r18, 0(r15)
  movia r14, KeyPressArray6
  stw r16, 0(r14)
  
  # need to read one more key to clear buffer
  movui r13, 0xF0
  beq r16, r13, readonemore

  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  beq r18, r13, readonemore

  movia r14, KeyPressArray4
  ldw r18, 0(r14)
  beq r18, r13, readonemore
  
  br turn_right


forward:
  # moves the car forward
  movia r11, 0xffdfff0
  stwio r11, 0(r8)
  call pwm

  movia r14, PS2_BASE
  ldwio r12, 0(r14)
  andi r16, r12, 0x00ff

  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  movia r15, KeyPressArray4
  stw r18, 0(r15)
  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  movia r15, KeyPressArray5
  stw r18, 0(r15)
  movia r14, KeyPressArray6
  stw r16, 0(r14)

  # need to read one more key to clear buffer
  movui r13, 0xF0
  beq r16, r13, readonemore

  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  beq r18, r13, readonemore

  movia r14, KeyPressArray4
  ldw r18, 0(r14)
  beq r18, r13, readonemore

  br forward

backward:
  # moves the car backwards
  movia r11, 0xffdfffa
  stwio r11, 0(r8)
  call pwm
  
  movia r14, PS2_BASE
  ldwio r12, 0(r14)
  andi r16, r12, 0x00ff

  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  movia r15, KeyPressArray4
  stw r18, 0(r15)
  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  movia r15, KeyPressArray5
  stw r18, 0(r15)
  movia r14, KeyPressArray6
  stw r16, 0(r14)
  
  # need to read one more key to clear buffer
  movui r13, 0xF0
  beq r16, r13, readonemore

  movia r14, KeyPressArray5
  ldw r18, 0(r14)
  beq r18, r13, readonemore

  movia r14, KeyPressArray4
  ldw r18, 0(r14)
  beq r18, r13, readonemore

  br backward

stop:
  # stop occurs when a movement key is released
  movia r11, 0xffdffff
  stwio r11, 0(r8)
  br main

readonemore:
  # reads one more key code to clear the input buffer
  movia r14, KeyPressArray1
  stw r0, 0(r14)
  stw r0, 4(r14)
  stw r0, 8(r14)
  stw r0, 12(r14)
  stw r0, 16(r14)
  stw r0, 20(r14)
  movia r14, PS2_BASE
  ldwio r12, 0(r14)
  br stop

initialize_timer:
  # initializes the timer
  movia r8, TIMER0_BASE             # Lower 16 bits
  addi r9, r0, %lo(TICKS_PER_SEC)
  stwio r9, TIMER0_PERIODL(r8)      # Upper 16 bits
  addi r9, r0, %hi(TICKS_PER_SEC)
  stwio r9, TIMER0_PERIODH(r8)
  ret

stop_timer:
  # stops the timer from counting down any more
  movia r8, TIMER0_BASE
  movi r9, 0x8
  stwio r9, TIMER0_CONTROL(r8)
  ret

start_timer_once:
  # starts the timer
  movia r8, TIMER0_BASE
  movi r9, 0x4
  stwio r9, TIMER0_CONTROL(r8)
  ret

read_timer:
  movia r8, TIMER0_BASE
  
  # First we take a snapshot of the period registers
  stwio r0, TIMER0_SNAPL(r8)

  # Read the snapshot
  ldwio r9, TIMER0_SNAPL(r8)
  ldwio r10, TIMER0_SNAPH(r8)

  # Combine the lo and hi bits
  slli r10, r10, 16                 # Shift r10's bits to the upper-half
  or r2, r9, r10                    # Combine r9 and r10 into the return value

  ret

pwm:
  addi sp, sp, -16
  stw ra, 0(sp)
  stw r8, 4(sp)
  stw r9, 8(sp)
  stw r10, 12(sp)
  call stop_timer
  call initialize_timer
  call start_timer_once

onesec:
  # runs the timer for one second before returning
  movia r8, TIMER0_BASE
  ldwio r17, TIMER0_STATUS(r8)
  andi r17, r17, 0x1
 
  beq r17, r0, onesec
  movi r17, 0x0
  stwio r17, TIMER0_STATUS(r8)

  call beep
  
  ldw ra, 0(sp)
  ldw r8, 4(sp)
  ldw r9, 8(sp)
  ldw r10, 12(sp)
  addi sp, sp, 16
  ret

crashed:
  # car is crashed, must manually restart
  br crashed
  
displayseg:
  addi sp, sp, -8
  stw r9, 0(sp)
  stw r10, 4(sp)
  
  movia r9, ADDR_7SEG1
  
  movi r10, 0x4
  beq r4, r10, print3
  
  movi r10, 0x2
  beq r4, r10, print2
  
  movi r10, 0x1
  beq r4, r10, print1

print0:
  movia r10, segdata
  ldw r4, 0(r10)
  stwio r4, 0(r9)
  br endprint
  
print3:
  movia r10, segdata
  ldw r4, 12(r10)
  stwio r4, 0(r9)
  br endprint
  
print2:
  movia r10, segdata
  ldw r4, 8(r10)
  stwio r4, 0(r9)
  br endprint
  
print1:
  movia r10, segdata
  ldw r4, 4(r10)
  stwio r4, 0(r9)
  
endprint:
  movia r9, ADDR_7SEG2
  stwio r0, 0(r9)
  
  ldw r9, 0(sp)
  ldw r10, 4(sp)
  addi sp, sp, 8
  ret
  
.data
.align 2

KeyPressArray1:
.word 0

KeyPressArray2:
.word 0

KeyPressArray3:
.word 0

KeyPressArray4:
.word 0

KeyPressArray5:
.word 0

KeyPressArray6:
.word 0

segdata:
.word 0x3F # display 0
.word 0x06 # display 1
.word 0x5B # display 2
.word 0x4F # display 3