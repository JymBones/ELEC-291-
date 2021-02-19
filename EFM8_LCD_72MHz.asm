; EFM8_LCD_72MHz.asm:  Test the LCD at 72 MHz
;

$NOLIST
$MODEFM8LB1
$LIST

SYSCLKv EQU 72000000  ; Microcontroller system clock frequency in Hz

cseg
org 0x0000 ; Reset vector
    ljmp MainProgram

; These 'equ' must match the hardware wiring
; They are used by 'LCD_4bit.inc'
LCD_RS equ P2.0
LCD_RW equ P1.7
LCD_E  equ P1.6
LCD_D4 equ P1.1
LCD_D5 equ P1.0
LCD_D6 equ P0.7
LCD_D7 equ P0.6
$NOLIST
$include(LCD_4bit_72MHz.inc)
$LIST

Msg1:  db 'Test Message 1', 0
Msg2:  db 'Test Message 2', 0

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
   
	mov	XBR0, #0x00
	mov	XBR1, #0x00
	mov	XBR2, #0x40 ; Enable crossbar and weak pull-ups
      
	ret

;---------------------------------;
; Main program. Includes hardware ;
; initialization and 'forever'    ;
; loop.                           ;
;---------------------------------;
MainProgram:
    mov SP, #0x7f ; Setup stack pointer to the start of indirectly accessable data memory minus one
    lcall Init_all ; Initialize the hardware

    lcall LCD_4BIT 
	Set_Cursor(1, 1)
    Send_Constant_String(#Msg1)
	Set_Cursor(2, 1)
    Send_Constant_String(#Msg2)
 
forever_loop:
	ljmp forever_loop

END
