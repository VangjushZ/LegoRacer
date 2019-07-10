.equ ADDR_AUDIODACFIFO, 0xFF203040
.equ BEEP_SOUND, 0x60000000

.global beep

beep: 
    movia 	r16, ADDR_AUDIODACFIFO
	movia 	r17, BEEP_SOUND
	stwio 	r17, 8(r16)      # left channel
	stwio 	r17, 12(r16)     # right channel
	ret