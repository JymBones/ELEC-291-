; Cup_Capacitor.asm: This program measures the water level in a cup capacitor,
; then shows the water level percentage on an lcd screen and audibly. If
; the boot button is pressed the water level percentage is read. If automatic 
; sound is turned on water level percentages are cotninuosly read. Please 
; load the percent1.wav file with EFM8_Receiver loaded before loading this program.


; Connections:
; 
; EFM8 board  SPI_FLASH
; P0.0        Pin 6 (SPI_CLK) 
; P0.1        Pin 2 (MISO)
; P0.2        Pin 5 (MOSI)
; P0.3        Pin 1 (CS/)
; GND         Pin 4
; 3.3V        Pins 3, 7, 8  (The MCP1700 3.3V voltage regulator or similar is required)
;
; P3.0 is the DAC output which should be connected to the input of power amplifier (LM386 or similar)
;

$NOLIST
$MODEFM8LB1
$LIST

SYSCLK         EQU 72000000  ; Microcontroller system clock frequency in Hz
TIMER2_RATE    EQU 22050     ; 22050Hz is the sampling rate of the wav file we are playing
TIMER2_RELOAD  EQU 0x10000-(SYSCLK/TIMER2_RATE)
F_SCK_MAX      EQU 20000000
BAUDRATE       EQU 115200

FLASH_CE EQU P0.3
SPEAKER  EQU P2.0
Automatic_Sound_Switch equ P2.6


; Commands supported by the SPI flash memory according to the datasheet
WRITE_ENABLE     EQU 0x06  ; Address:0 Dummy:0 Num:0
WRITE_DISABLE    EQU 0x04  ; Address:0 Dummy:0 Num:0
READ_STATUS      EQU 0x05  ; Address:0 Dummy:0 Num:1 to infinite
READ_BYTES       EQU 0x03  ; Address:3 Dummy:0 Num:1 to infinite
READ_SILICON_ID  EQU 0xab  ; Address:0 Dummy:3 Num:1 to infinite
FAST_READ        EQU 0x0b  ; Address:3 Dummy:1 Num:1 to infinite
WRITE_STATUS     EQU 0x01  ; Address:0 Dummy:0 Num:1
WRITE_BYTES      EQU 0x02  ; Address:3 Dummy:0 Num:1 to 256
ERASE_ALL        EQU 0xc7  ; Address:0 Dummy:0 Num:0
ERASE_BLOCK      EQU 0xd8  ; Address:3 Dummy:0 Num:0
READ_DEVICE_ID   EQU 0x9f  ; Address:0 Dummy:2 Num:1 to infinite


; Interrupt vectors:
cseg

org 0x0000 ; Reset vector
    ljmp MainProgram

org 0x0003 ; External interrupt 0 vector (not used in this code)
	reti

org 0x000B ; Timer/Counter 0 overflow interrupt vector (not used in this code)
	inc R7
	reti

org 0x0013 ; External interrupt 1 vector (not used in this code)
	reti

org 0x001B ; Timer/Counter 1 overflow interrupt vector (not used in this code
	reti

org 0x0023 ; Serial port receive/transmit interrupt vector (not used in this code)
	reti

org 0x005b ; Timer 2 interrupt vector.  Used in this code to replay the wave file.
	ljmp Timer2_ISR
	
	; Variables used in the program:
dseg at 30H
w:   ds 3 ; 24-bit play counter.  Decremented in Timer 2 ISR.
x:   ds 4
y:   ds 4
bcd: ds 5
Unit_sel: ds 1
tbsp: ds 1
length1: ds 4 ;1 markes the more significant digit
length2: ds 4 ;size of desired sound 
additions1: ds 3 
additions0: ds 3
position: ds 1  ;positon(0-29) in lookup table for percent1.wav 
currentloc1: ds 1 ;location for beginning of desired sound
currentloc2: ds 1
currentloc3: ds 1
remainder: ds 1
Count1ms: ds 2    ;Counter used with timer2 for automatic sound

BSEG
mf: dbit 1
done: dbit 1
ones_flag: dbit 1
percent_flag: dbit 1
play_sount_flag: dbit 1
seconds_flag: dbit 1
Automatic_Sound_flag: dbit 1
reading_flag: dbit 1
done_playing: dbit 1

$NOLIST
$include(math32.inc)
$LIST

; These 'equ' must match the hardware wiring
; They are used by 'LCD_4bit.inc'
LCD_RS equ P3.3
LCD_RW equ P3.2
LCD_E  equ P3.1
LCD_D4 equ P2.5
LCD_D5 equ P2.4
LCD_D6 equ P2.3
LCD_D7 equ P2.2
$NOLIST
$include(LCD_4bit_72MHz.inc)
$LIST

Display_Cap:  db 'Capacitance(xx):', 0
CLEAR: db '                  ',0
Display_nF: db 'nF',0
Water_lev: db 'Water Level(%):',0
madeIt: db 'Made it', 0

Left_blank mac
	mov a, %0
	anl a, #0xf0
	swap a
	jz Left_blank_%M_a
	ljmp %1
Left_blank_%M_a:
	Display_char(#' ')
	mov a, %0
	anl a, #0x0f
	jz Left_blank_%M_b
	ljmp %1
Left_blank_%M_b:
	Display_char(#' ')
endmac


end_search_step_step_12540:
	ljmp end_search_step_12540
	


;-------------------------------------;
; Search lookup table for location	  ;
; and length given position           ;
;-------------------------------------;	
determine_location:
	push acc
	push psw
	push x
	push y
	
	mov x+0, #0
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	;No addition
	mov a, position
	jz end_search_step_step_12540
	mov y+0, #0x7a
	mov y+1, additions1+0
	lcall add32
	;First addition
	mov a, position
	add a, #-1
	jz end_search_step_step_12540
	lcall add32
	;Second addition
	mov a, position
	add a, #-2
	jz end_search_step_12540
	lcall add32
	;Third addition
	mov a, position
	add a, #-3
	jz end_search_step_12540
	mov y+0,  additions0+1
	mov y+1, additions1+1
	lcall add32
	;Forth addtion
	mov a, position
	add a, #-4
	jz end_search_step_12540
	mov y+0, #0x7a
	mov y+1, additions1+0
	lcall add32
	;Fith addtion
	mov a, position
	add a, #-5
	jz end_search_step_12540
	lcall add32
	;Sixth addtion
	mov a, position
	add a, #-6
	jz end_search_step_12540
	lcall add32
	;Seventh addtion
	mov a, position
	add a, #-7
	jz end_search_step_12540
	lcall add32
	;Eight addtion
	mov a, position
	add a, #-8
	jz end_search_step_12540
	mov y+0,  additions0+1
	mov y+1, additions1+1
	lcall add32
	;Ninth addtion
	mov a, position
	add a, #-9
	jz end_search_step_12540
	lcall add32
	;Tenth addtion
	mov a, position
	add a, #-10
	jz end_search_step_12540
	lcall add32
	;Eleventh addtion
	mov a, position
	add a, #-11
	jz end_search_step_12540
	ljmp skip_stepper1
;stepper for locations requiring 12560 length
end_search_step_12540:
	mov length1, #High(12540)
	mov length2, #Low(12540)
	ljmp end_search

skip_stepper1:
	mov y+0, #0x62
	mov y+1, #0x4d
	lcall add32	
	;Twelth addtion
	mov a, position
	add a, #-12
	jz end_search_step_15540
	mov y+0, additions0+2
	mov y+1, additions1+2
	lcall add32
	mov y+0, #0xe8
	mov y+1, #0x03
	lcall add32
	;Thirteenth addtion
	mov a, position
	add a, #-13
	jz end_search_step_15540
	mov y+0, #0x32
	mov y+1, #0x55
	lcall add32
	;Forteenth addtion
	mov a, position
	add a, #-14
	jz end_search_step_15540
	lcall add32
	;Fifteenth addtion
	mov a, position
	add a, #-15
	jz end_search_step_15540
	lcall add32
	;Sizteenth addtion
	mov a, position
	add a, #-16
	jz end_search_step_15540
	ljmp skip_stepper2
;stepper for locations requiring 15540 length
end_search_step_15540:
	mov length1, #High(15540)
	mov length2, #Low(15540)
	ljmp end_search

skip_stepper2:
	mov y+0, #0xea
	mov y+1, #0x60
	lcall add32
	;Seventeeth addtion(done 17 addition)
	mov a, position
	add a, #-17
	jz end_search_step_17540
	lcall add32
	;Eighteenth addtion
	mov a, position
	add a, #-18
	jz end_search_step_17540
	mov y+0, additions0+2
	mov y+1, additions1+2
	lcall add32
	;Ninteeth addtion
	mov a, position
	add a, #-19
	jz end_search_step_17540
	ljmp skip_stepper3
;stepper for locations requiring 17540 length
end_search_step_17540:
	mov length1, #High(17540)
	mov length2, #Low(17540)
	ljmp end_search
skip_stepper3:	
	mov y+0, #0xea
	mov y+1, #0x60
	lcall add32
	;Twentieth addtion
	mov a, position
	add a, #-20
	jz end_search_step_15540
	mov y+0, additions0+2
	mov y+1, additions1+2
	lcall add32
	;Twenty First addtion
	mov a, position
	add a, #-21
	jz end_search_step_15540
	lcall add32
	;Twenty Second addtion
	mov a, position
	add a, #-22
	jz end_search_step_step_15540
	mov y+0, #0xea
	mov y+1, #0x60
	lcall add32
	;Twenty Third addtion
	mov a, position
	add a, #-23 ;50
	jz end_search_step_step_15540
	mov y+0, additions0+2
	mov y+1, additions1+2
	lcall add32
	;Twenty Fourth addtion
	mov a, position
	add a, #-24
	jz end_search_step_step_15540
	mov y+0, #0xea
	mov y+1, #0x60
	lcall add32
	;Twenty Fith addtion
	mov a, position
	add a, #-25 ;70
	jz end_search_step_step_15540
	mov y+0, additions0+2
	mov y+1, additions1+2
	lcall add32
	;Twenty sixth addtion
	mov a, position
	add a, #-26 ;80
	jz end_search_step_step_15540
	lcall add32
	;Twenty seventh addtion
	mov a, position
	add a, #-27 ;90
	jz end_search_step_step_15540
	mov y+0, #0xea
	mov y+1, #0x60
	lcall add32
	;Twenty eighth addtion
	mov a, position
	add a, #-28 ;100
	jz end_search_step_18540
	ljmp skip_stepper4
end_search_step_step_15540:
	ljmp end_search_step_15540
skip_stepper4:	
	lcall add32
	;Twenty nineth addtion
	mov a, position
	add a, #-29 ;percent
	
;stepper for locations requiring 15540 length
end_search_step_18540:
	mov length1, #High(18540)
	mov length2, #Low(18540)
		
end_search:
	mov currentloc1, x+2
	mov currentloc2, x+1
	mov currentloc3, x+0

	pop y
	pop x
	pop psw
	pop acc
ret

; Sends 10-digit BCD number in bcd to the LCD
Display_10_digit_BCD:
	Set_Cursor(2, 1)
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	; Replace all the zeros to the left with blanks
	Set_Cursor(2, 1)
	Left_blank(bcd+4, skip_blank)
	Left_blank(bcd+3, skip_blank)
	Left_blank(bcd+2, skip_blank)
	Left_blank(bcd+1, skip_blank)
	mov a, bcd+0
	anl a, #0f0h
	swap a
	jnz skip_blank
	Display_char(#' ')
skip_blank:
	ret

; We can display a number any way we want.  In this case with
; four decimal places.

Display_formated_BCD:
    Set_Cursor(2, 4)
    Display_BCD(bcd+4)
    Display_BCD(bcd+3)
 	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_char(#'.')
	Display_BCD(bcd+0)
	; Replace all the zeros to the left with blanks
	Set_Cursor(2, 1)
	mov a, bcd+0
	anl a, #0f0h
	swap a
	jnz skip_blankf
	Display_char(#' ')

skip_blankf:
	ret

;Note: does not actual wait 1 second, its purpose is to act as a delay	
Wait_one_second:	
    ;For a 72MHz clock one machine cycle takes 1/72MHz=13.8888ns
    mov R2, #198 ; Calibrate using this number to account for overhead delays
X3: mov R1, #245
X2: mov R0, #167
X1: djnz R0, X1 
    djnz R1, X2 
    djnz R2, X3
    ret


;-------------------------------------;
; ISR for Timer 2.  Used to playback  ;
; the WAV file stored in the SPI      ;
; flash memory.                       ;
;-------------------------------------;
Timer2_ISR:
   

	mov	SFRPAGE, #0x00 
	clr	TF2H ; Clear Timer2 interrupt flag

	; The registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits  ;will overflow to 0
	jnz Inc_Done
	inc Count1ms+1

Inc_Done:
	; Check if half second has passed
	mov a, Count1ms+0
	cjne a, #low(10000), Timer2_ISR_done1 ; Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(10000), Timer2_ISR_done1
	
	; 1000 milliseconds have passed.  Set a flag so the main program knows
	setb seconds_flag ; Let the main program know half second had passed
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a

Timer2_ISR_done1:


  ;only run normal timer 2 routine if play_sount_flag is 1
jnb play_sount_flag, Timer2_ISR_Done	
	; Check if the play counter is zero.  If so, stop playing sound.
	mov a, w+0
	orl a, w+1
	orl a, w+2
	jz stop_playing
	
	; Decrement play counter 'w'.  In this implementation 'w' is a 24-bit counter.
	mov a, #0xff
	dec w+0
	cjne a, w+0, keep_playing
	dec w+1
	cjne a, w+1, keep_playing
	dec w+2
	
keep_playing:

	setb SPEAKER
	lcall Send_SPI ; Read the next byte from the SPI Flash...
	
	; It gets a bit complicated here because we read 8 bits from the flash but we need to write 12 bits to DAC:
	mov SFRPAGE, #0x30 ; DAC registers are in page 0x30
	push acc ; Save the value we got from flash
	swap a
	anl a, #0xf0
	mov DAC0L, a
	pop acc
	swap a
	anl a, #0x0f
	mov DAC0H, a
	mov SFRPAGE, #0x00
	
	sjmp Timer2_ISR_Done

stop_playing:
	;clr TR2 ; Stop timer 2
	clr play_sount_flag
	jb percent_flag, notdone
	setb done_playing
	setb reading_flag
notdone:
	clr done
	setb FLASH_CE  ; Disable SPI Flash
	clr SPEAKER ; Turn off speaker.  Removes hissing noise when not playing sound.

Timer2_ISR_Done:	
	pop psw
	pop acc
	reti

;---------------------------------;
; Sends a byte via serial port    ;
;---------------------------------;
putchar:
	jbc	TI,putchar_L1
	sjmp putchar
putchar_L1:
	mov	SBUF,a
	ret

;---------------------------------;
; Receive a byte from serial port ;
;---------------------------------;
getchar:
	jbc	RI,getchar_L1
	sjmp getchar
getchar_L1:
	mov	a,SBUF
	ret

;---------------------------------;
; Sends AND receives a byte via   ;
; SPI.                            ;
;---------------------------------;
Send_SPI:
	mov	SPI0DAT, a
Send_SPI_L1:
	jnb	SPIF, Send_SPI_L1 ; Wait for SPI transfer complete
	clr SPIF ; Clear SPI complete flag 
	mov	a, SPI0DAT
	ret

;---------------------------------;
; SPI flash 'write enable'        ;
; instruction.                    ;
;---------------------------------;
Enable_Write:
	clr FLASH_CE
	mov a, #WRITE_ENABLE
	lcall Send_SPI
	setb FLASH_CE
	ret

;---------------------------------;
; This function checks the 'write ;
; in progress' bit of the SPI     ;
; flash memory.                   ;
;---------------------------------;
Check_WIP:
	clr FLASH_CE
	mov a, #READ_STATUS
	lcall Send_SPI
	mov a, #0x55
	lcall Send_SPI
	setb FLASH_CE
	jb acc.0, Check_WIP ;  Check the Write in Progress bit
	ret
	
Init_all:
	; Disable WDT:
	mov	WDTCN, #0xDE
	mov	WDTCN, #0xAD
	
	mov	VDM0CN, #0x80
	mov	RSTSRC, #0x06
	
	; Switch SYSCLK to 72 MHz.  First switch to 24MHz:
	mov	SFRPAGE, #0x10
	mov	PFE0CN, #0x20
	mov	SFRPAGE, #0x00
	mov	CLKSEL, #0x00
	mov	CLKSEL, #0x00 ; Second write to CLKSEL is required according to datasheet
	

	mov additions1+0, #0x49
	mov additions0+0, #0x7A
	mov additions1+1, #0x3D
	mov additions0+1, #0xC2
	mov additions1+2, #0x41
	mov additions0+2, #0xaa

	mov length1+0, #0x48 
	mov length2+0, #0x6c
	mov position, #5
	
	;play_sount_flag is used in place of tuning timer 2 on and off
	;This allows timer2 to continuously count for our automatic sound 
	clr play_sount_flag
	clr seconds_flag
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	clr Automatic_Sound_flag
	clr reading_flag
;	setb done_playing
	
	clr done
	; Wait for clock to settle at 24 MHz by checking the most significant bit of CLKSEL:
Init_L1:
	mov	a, CLKSEL
	jnb	acc.7, Init_L1
	
	; Now switch to 72MHz:
	mov	CLKSEL, #0x03
	mov	CLKSEL, #0x03  ; Second write to CLKSEL is required according to datasheet
	
	; Wait for clock to settle at 72 MHz by checking the most significant bit of CLKSEL:
Init_L2:
	mov	a, CLKSEL
	jnb	acc.7, Init_L2

	mov	SFRPAGE, #0x00
	
	; Configure P3.0 as analog output.  P3.0 pin is the output of DAC0.
	anl	P3MDIN, #0xFE
	orl	P3, #0x01
	
	; Configure the pins used for SPI (P0.0 to P0.3)
	mov	P0MDOUT, #0x1D ; SCK, MOSI, P0.3, TX0 are push-pull, all others open-drain
	
	orl P0SKIP, #0b_1100_1000 ; P0.7 and P0.6 used by LCD.  P0.3 used as CS/ for SPI memory.
	orl P1SKIP, #0b_0000_0011 ; P1.1 and P1.2 used by LCD


	mov	XBR0, #0x03 ; Enable SPI and UART0: SPI0E=1, URT0E=1
	mov	XBR1, #0x10
	mov	XBR2, #0x40 ; Enable crossbar and weak pull-ups
	
	clr TR0 ; Stop timer 0
    mov a, TMOD
    anl a, #0b_1111_0000 ; Clear the bits of timer/counter 0
    orl a, #0b_0000_0101 ; Sets the bits of timer/counter 0 for a 16-bit counter
    mov TMOD, a

	; Enable serial communication and set up baud rate using timer 1
	mov	SCON0, #0x10	
	mov	TH1, #(0x100-((SYSCLK/BAUDRATE)/(12*2)))
	mov	TL1, TH1
	anl	TMOD, #0x0F ; Clear the bits of timer 1 in TMOD
	orl	TMOD, #0x20 ; Set timer 1 in 8-bit auto-reload mode.  Don't change the bits of timer 0
	setb TR1 ; START Timer 1
	setb TI ; Indicate TX0 ready
	
	; Configure DAC 0
	mov	SFRPAGE, #0x30 ; To access DAC 0 we use register page 0x30
	mov	DACGCF0, #0b_1000_1000 ; 1:D23REFSL(VCC) 1:D3AMEN(NORMAL) 2:D3SRC(DAC3H:DAC3L) 1:D01REFSL(VCC) 1:D1AMEN(NORMAL) 1:D1SRC(DAC1H:DAC1L)
	mov	DACGCF1, #0b_0000_0000
	mov	DACGCF2, #0b_0010_0010 ; Reference buffer gain 1/3 for all channels
	mov	DAC0CF0, #0b_1000_0000 ; Enable DAC 0
	mov	DAC0CF1, #0b_0000_0010 ; DAC gain is 3.  Therefore the overall gain is 1.
	; Initial value of DAC 0 is mid scale:
	mov	DAC0L, #0x00
	mov	DAC0H, #0x08
	mov	SFRPAGE, #0x00
	
	; Configure SPI
	mov	SPI0CKR, #((SYSCLK/(2*F_SCK_MAX))-1)
	mov	SPI0CFG, #0b_0100_0000 ; SPI in master mode
	mov	SPI0CN0, #0b_0000_0001 ; SPI enabled and in three wire mode
	setb FLASH_CE ; CS=1 for SPI flash memory
	clr SPEAKER ; Turn off speaker.
	
	; Configure Timer 2 and its interrupt
	mov	TMR2CN0,#0x00 ; Stop Timer2; Clear TF2
	orl	CKCON0,#0b_0001_0000 ; Timer 2 uses the system clock
	; Initialize reload value:
	mov	TMR2RLL, #low(TIMER2_RELOAD)
	mov	TMR2RLH, #high(TIMER2_RELOAD)
	; Set timer to reload immediately
	mov	TMR2H,#0xFF
	mov	TMR2L,#0xFF
	setb ET2 ; Enable Timer 2 interrupts
	setb TR2 ; Timer 2 is only enabled to play stored sound;!!tunred on
	
	setb EA ; Enable interrupts
	setb IP.1
	lcall LCD_4BIT
	mov w+0,#0x00
	mov w+1,#0x00
	mov w+2,#0x00
	mov w+3,#0x00
	mov w+4,#0x00
	ret

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
MainProgram:
    mov SP, #0x7f ; Setup stack pointer to the start of indirectly accessable data memory minus one
    lcall Init_all ; Initialize the hardware

forever_loop:

;Wait_Milli_Seconds(#200)	

    jb done_playing, update_reading
	jb reading_flag, update_reading

play:    
    ljmp play_seq
    
    update_reading:
    clr TR2
    setb reading_flag
    ;clr TR1;!
    ; Measure the frequency applied to pin T0 (T0 is routed to pin P1.2 using the 'crossbar')
    clr TR0 ; Stop counter 0
    mov TL0, #0
    mov TH0, #0
    mov R7, #0
    clr TF0 ; Clear overflow flag
    setb ET0  ; Enable timer 0 interrupt
    setb EA ; Enable global interrupts
    setb TR0 ; Start counter 0
    lcall Wait_one_second
    clr TR0 ; Stop counter 0, R7-TH0-TL0 has the frequency
    ;setb TR1;!
calculate_val:
;cpl ET2    
    Load_x(98700);RA- Measure with MultiMeter
    Load_y(9858) ;RB- Measure with MultiMeter
	lcall add32
	Load_y(100)
	lcall div32
	mov R0,x+0
	mov R1,x+1
	mov R2,x+2
	mov R3,x+3
	mov y+0,R0
	mov y+1,R1
	mov y+2,R2
	mov y+3,R3
	
	mov x+0, TL0
	mov x+1, TH0
	mov x+2, R7
	mov x+3, #0
    
	; mul32 and hex2bcd are in math32.inc
	lcall mul32
	mov R0,x+0
	mov R1,x+1
	mov R2,x+2
	mov R3,x+3
	mov y+0,R0
	mov y+1,R1
	mov y+2,R2
	mov y+3,R3
	
	; There are macros defined in math32.inc that can be used to load constants
	; to variables x and y. The same code above may be written as:
	Load_x(1440000000)
    lcall div32
    Load_y(365)
    lcall sub32	  
 	load_y(1000)
 	lcall mul32
 	load_y(53)
 	lcall add32
 	load_y(18)
 	lcall div32
 	load_y(490000)
 	lcall mul32
 	load_y(10000)
 	lcall div32
 	load_y(5000)
 	lcall sub32
 	load_y(40) 
 	lcall div32
 
 
 hexconvert:
 
lcall hex2bcd
 	
 	mov a, bcd+3
 	cjne a, #0x00, overflow
 	ljmp hexconvert100
 
 overflow:
 
 mov bcd+4,#0x00
 mov bcd+3,#0x00
 mov bcd+2,#0x00
 mov bcd+1,#0x00
 mov bcd+0,#0x00

 hexconvert100:
 mov a,bcd+2
 cjne a,#0x01,print_level
 mov bcd+1,#0x00
 mov bcd+0,#0x00

 print_level:
 ;setb ET2
	Set_Cursor(1,1)
    Send_Constant_String(#Water_lev)	
	lcall Display_formated_BCD
clr reading_flag
	
	
jb Automatic_Sound_Switch, play_seq  
	Wait_Milli_Seconds(#50)	
	jb Automatic_Sound_Switch, play_seq 
	jnb Automatic_Sound_Switch, $	
	;stops automatic
	cpl Automatic_Sound_flag ;switch automatic on or off
	

;-------------------------------------;
; Play sequence. Determines if the    ;
; current water level percentage      ;
; should be read, then plays specific ;
; sound bytes accordingly             ;
;-------------------------------------;

play_seq:
setb TR2
    Wait_Milli_Seconds(#200)
    jb reading_flag, forever_loop0
    ;jb done_playing, forever_loop0
    jb ones_flag, mov_remainder
    jb percent_flag,say_percent
	jb RI, serial_get0
	jb seconds_flag, automatic_routine
Check_boot_button:
	jb P3.7, forever_loop0 ; Check if push-button pressed
	jnb P3.7, $ ; Wait for push-button release
	setb reading_flag
	clr done_playing
	; Play the whole memory
	mov a, bcd+1
	ljmp check_level

;if Automatic_Sound_flag is 1 reas current water level
automatic_routine:
	clr seconds_flag
	jnb Automatic_Sound_flag, Check_boot_button ;go back to loop if Automatic_Sound_flag is 0
	setb reading_flag
	clr done_playing
	; Play the whole memory
	mov a, bcd+1
	ljmp check_level
	
say_percent:
clr percent_flag
ljmp next_percent

mov_remainder:
mov a,remainder
ljmp check_level

forever_loop0:	
	ljmp forever_loop

serial_get0:
ljmp serial_get

check_level:
setb percent_flag

jnb ones_flag,reg_zero
cjne a, #0x00,next1
clr ones_flag
ljmp play_seq

reg_zero:
cjne a, #0x00,next1
mov position, #0
ljmp play_mem

next1:
clr ones_flag
cjne a,#0x01,next2
mov position,#1
ljmp play_mem

next2:
cjne a,#0x02,next3
mov position,#2
ljmp play_mem

next3:
cjne a,#0x03,next4
mov position,#3
ljmp play_mem

next4:
cjne a,#0x04,next5
mov position,#4
ljmp play_mem

next5:
cjne a,#0x05,next6
mov position,#5
ljmp play_mem

next6:
cjne a,#0x06,next7
mov position,#6
ljmp play_mem

next7:
cjne a,#0x07,next8
mov position,#7
ljmp play_mem

next8:
cjne a,#0x08,next9
mov position,#8
ljmp play_mem

next9:
cjne a,#0x09,next10
mov position,#9
ljmp play_mem

next10:
cjne a,#0x10,next11
mov position,#10
ljmp play_mem

next11:
cjne a,#0x11,next12
mov position,#11
ljmp play_mem

next12:
cjne a,#0x12,next13
mov position,#12
ljmp play_mem

next13:
cjne a,#0x13,next14
mov position,#13
ljmp play_mem

next14:
cjne a,#0x14,next15
mov position,#14
ljmp play_mem

next15:
cjne a,#0x15,next16
mov position,#15
ljmp play_mem

next16:
cjne a,#0x16,next17
mov position,#16
ljmp play_mem

next17:
cjne a,#0x17,next18
mov position,#17
ljmp play_mem

next18:
cjne a,#0x18,next19
mov position,#18
ljmp play_mem

next19:
cjne a,#0x19,next20
mov position,#19
ljmp play_mem

next20:
cjne a,#0x30,N1
N1:
jnb cy,next30
clr cy
setb ones_flag
subb a,#0x20
mov remainder,a
mov position,#20
ljmp play_mem

next30:
cjne a,#0x40,N2
N2:
jnb cy,next40
clr cy
setb ones_flag
subb a,#0x30
mov remainder,a
mov position,#21
ljmp play_mem

next40:
cjne a,#0x50,N3
N3:
jnb cy,next50
clr cy
setb ones_flag
subb a,#0x40
mov remainder,a
mov position,#22
ljmp play_mem

next50:
cjne a,#0x60,N4
N4:
jnb cy,next60
clr cy
setb ones_flag
subb a,#0x50
mov remainder,a
mov position,#23
ljmp play_mem

next60:
cjne a,#0x70,N5
N5:
jnb cy,next70
clr cy
setb ones_flag
subb a,#0x60
mov remainder,a
mov position,#24
ljmp play_mem

next70:
cjne a,#0x80,N6
N6:
jnb cy,next80
clr cy
setb ones_flag
subb a,#0x70
mov remainder,a
mov position,#25
ljmp play_mem

next80:
cjne a,#0x90,N7
N7:
jnb cy,next90
clr cy
setb ones_flag
subb a,#0x80
mov remainder,a
mov position,#26
ljmp play_mem

next90:
cjne a,#0xA0,N8
N8:
jnb cy,next100
clr cy
setb ones_flag
subb a,#0x90
mov remainder,a
mov position,#27
ljmp play_mem

next100:
mov a, bcd+2
cjne a,#0x01,next_percent
mov position,#28
ljmp play_mem

next_percent:
mov position,#29
clr done
ljmp play_mem


; Play sound bite given location and length
play_mem:
	clr play_sount_flag ;
	;clr TR2 ; Stop Timer 2 ISR from playing previous request
	setb FLASH_CE
	clr SPEAKER ; Turn off speaker.
	
	clr FLASH_CE ; Enable SPI Flash
	lcall determine_location
	mov a, #READ_BYTES
	lcall Send_SPI
	; Set the initial position in memory where to start playing
	mov a, currentloc1
	lcall Send_SPI
	mov a, currentloc2
	lcall Send_SPI
	mov a, currentloc3
	lcall Send_SPI
	mov a, #0xff ; Request first byte to send to DAC
	lcall Send_SPI
	
	; How many bytes to play? All of them!  Asume 4Mbytes memory: 0x3fffff
	mov w+2, #0x00
	mov w+1, length1
	mov w+0, length2
	
	setb SPEAKER ; Turn on speaker.
	setb play_sount_flag
	;setb TR2 ; Start playback by enabling Timer 2
forever_loop1:
ljmp forever_loop
	
serial_get:
	lcall getchar ; Wait for data to arrive
	cjne a, #'#', forever_loop1 ; Message format is #n[data] where 'n' is '0' to '9'
	clr play_sount_flag
	;clr TR2 ; Stop Timer 2 from playing previous request
	setb FLASH_CE ; Disable SPI Flash	
	clr SPEAKER ; Turn off speaker.
	lcall getchar
ljmp commands_start

commands_start:
;---------------------------------------------------------	
	cjne a, #'0' , Command_0_skip
Command_0_start: ; Identify command
	clr FLASH_CE ; Enable SPI Flash	
	mov a, #READ_DEVICE_ID
	lcall Send_SPI	
	mov a, #0x55
	lcall Send_SPI
	lcall putchar
	mov a, #0x55
	lcall Send_SPI
	lcall putchar
	mov a, #0x55
	lcall Send_SPI
	lcall putchar
	setb FLASH_CE ; Disable SPI Flash
	ljmp forever_loop	
Command_0_skip:

;---------------------------------------------------------	
	cjne a, #'1' , Command_1_skip 
Command_1_start: ; Erase whole flash (takes a long time)
	lcall Enable_Write
	clr FLASH_CE
	mov a, #ERASE_ALL
	lcall Send_SPI
	setb FLASH_CE
	lcall Check_WIP
	mov a, #0x01 ; Send 'I am done' reply
	lcall putchar		
	ljmp forever_loop	
Command_1_skip:

;---------------------------------------------------------	
	cjne a, #'2' , Command_2_skip 
Command_2_start: ; Load flash page (256 bytes or less)
	lcall Enable_Write
	clr FLASH_CE
	mov a, #WRITE_BYTES
	lcall Send_SPI
	lcall getchar ; Address bits 16 to 23
	lcall Send_SPI
	lcall getchar ; Address bits 8 to 15
	lcall Send_SPI
	lcall getchar ; Address bits 0 to 7
	lcall Send_SPI
	lcall getchar ; Number of bytes to write (0 means 256 bytes)
	mov r0, a
Command_2_loop:
	lcall getchar
	lcall Send_SPI
	djnz r0, Command_2_loop
	setb FLASH_CE
	lcall Check_WIP
	mov a, #0x01 ; Send 'I am done' reply
	lcall putchar		
	ljmp forever_loop	
Command_2_skip:

;---------------------------------------------------------	
	cjne a, #'3' , Command_3_skip 
Command_3_start: ; Read flash bytes (256 bytes or less)
	clr FLASH_CE
	mov a, #READ_BYTES
	lcall Send_SPI
	lcall getchar ; Address bits 16 to 23
	lcall Send_SPI
	lcall getchar ; Address bits 8 to 15
	lcall Send_SPI
	lcall getchar ; Address bits 0 to 7
	lcall Send_SPI
	lcall getchar ; Number of bytes to read and send back (0 means 256 bytes)
	mov r0, a

Command_3_loop:
	mov a, #0x55
	lcall Send_SPI
	lcall putchar
	djnz r0, Command_3_loop
	setb FLASH_CE	
	ljmp forever_loop	
Command_3_skip:

;---------------------------------------------------------	
	cjne a, #'4' , Command_4_skip 
Command_4_start: ; Playback a portion of the stored wav file
	clr play_sount_flag
	;clr TR2 ; Stop Timer 2 ISR from playing previous request
	setb FLASH_CE
	
	clr FLASH_CE ; Enable SPI Flash
	mov a, #READ_BYTES
	lcall Send_SPI
	; Get the initial position in memory where to start playing
	lcall getchar
	lcall Send_SPI
	lcall getchar
	lcall Send_SPI
	lcall getchar
	lcall Send_SPI
	; Get how many bytes to play
	lcall getchar
	mov w+2, a
	lcall getchar
	mov w+1, a
	lcall getchar
	mov w+0, a
	
	mov a, #0x00 ; Request first byte to send to DAC
	lcall Send_SPI
	
	setb play_sount_flag
	;setb TR2 ; Start playback by enabling timer 2
	ljmp forever_loop	
Command_4_skip:

;---------------------------------------------------------	
	cjne a, #'5' , Command_5_skip 
Command_5_start: ; Calculate and send CRC-16 of ISP flash memory from zero to the 24-bit passed value.
	; Get how many bytes to use to calculate the CRC.  Store in [r5,r4,r3]
	lcall getchar
	mov r5, a
	lcall getchar
	mov r4, a
	lcall getchar
	mov r3, a
	
	; Since we are using the 'djnz' instruction to check, we need to add one to each byte of the counter.
	; A side effect is that the down counter becomes efectively a 23-bit counter, but that is ok
	; because the max size of the 25Q32 SPI flash memory is 400000H.
	inc r3
	inc r4
	inc r5
	
	; Initial CRC must be zero.
	mov	SFRPAGE, #0x20 ; UART0, CRC, and SPI can work on this page
	mov	CRC0CN0, #0b_0000_1000 ; // Initialize hardware CRC result to zero;

	clr FLASH_CE
	mov a, #READ_BYTES
	lcall Send_SPI
	clr a ; Address bits 16 to 23
	lcall Send_SPI
	clr a ; Address bits 8 to 15
	lcall Send_SPI
	clr a ; Address bits 0 to 7
	lcall Send_SPI
	mov	SPI0DAT, a ; Request first byte from SPI flash
	sjmp Command_5_loop_start

Command_5_loop:
	jnb SPIF, Command_5_loop 	; Check SPI Transfer Completion Flag
	clr SPIF				    ; Clear SPI Transfer Completion Flag	
	mov a, SPI0DAT				; Save received SPI byte to accumulator
	mov SPI0DAT, a				; Request next byte from SPI flash; while it arrives we calculate the CRC:
	mov	CRC0IN, a               ; Feed new byte to hardware CRC calculator

Command_5_loop_start:
	; Drecrement counter:
	djnz r3, Command_5_loop
	djnz r4, Command_5_loop
	djnz r5, Command_5_loop
Command_5_loop2:	
	jnb SPIF, Command_5_loop2 	; Check SPI Transfer Completion Flag
	clr SPIF			    	; Clear SPI Transfer Completion Flag
	mov a, SPI0DAT	            ; This dummy read is needed otherwise next transfer fails (why?)
	setb FLASH_CE 				; Done reading from SPI flash
	
	; Computation of CRC is complete.  Send 16-bit result using the serial port
	mov	CRC0CN0, #0x01 ; Set bit to read hardware CRC high byte
	mov	a, CRC0DAT
	lcall putchar

	mov	CRC0CN0, #0x00 ; Clear bit to read hardware CRC low byte
	mov	a, CRC0DAT
	lcall putchar
	
	mov	SFRPAGE, #0x00

	ljmp forever_loop	
Command_5_skip:

;---------------------------------------------------------	
	cjne a, #'6' , Command_6_skip 
Command_6_start: ; Fill flash page (256 bytes)
	lcall Enable_Write
	clr FLASH_CE
	mov a, #WRITE_BYTES
	lcall Send_SPI
	lcall getchar ; Address bits 16 to 23
	lcall Send_SPI
	lcall getchar ; Address bits 8 to 15
	lcall Send_SPI
	lcall getchar ; Address bits 0 to 7
	lcall Send_SPI
	lcall getchar ; Byte to write
	mov r1, a
	mov r0, #0 ; 256 bytes
Command_6_loop:
	mov a, r1
	lcall Send_SPI
	djnz r0, Command_6_loop
	setb FLASH_CE
	lcall Check_WIP
	mov a, #0x01 ; Send 'I am done' reply
	lcall putchar		
	ljmp forever_loop	
Command_6_skip:

	ljmp forever_loop

END