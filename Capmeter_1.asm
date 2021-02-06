; mathtest.asm:  Examples using math32.inc routines

$NOLIST
$MODEFM8LB1
$LIST

org 0000H
   ljmp MyProgram

; Timer/Counter 0 overflow interrupt vector
org 0x000B
    inc R7 ; Keep count of overflow in some available register not used anywhere else
    reti
   


; These register definitions needed by 'math32.inc'
DSEG at 30H
x:   ds 4
y:   ds 4
bcd: ds 5
Unit_sel: ds 1

BSEG
mf: dbit 1

$NOLIST
$include(math32.inc)
$LIST

; These 'equ' must match the hardware wiring
; They are used by 'LCD_4bit.inc'
LCD_RS equ P2.0
LCD_RW equ P1.7
LCD_E  equ P1.6
LCD_D4 equ P1.1
LCD_D5 equ P1.0
LCD_D6 equ P0.7
LCD_D7 equ P0.6
RA     equ #0x7D0 ;2000 ohms
RB     equ #0x64  ;100 ohms
$NOLIST
$include(LCD_4bit.inc)
$LIST

CSEG

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
Display_formated_BCD_F:
	Set_Cursor(2, 1)
	
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_char(#'.')
	Display_BCD(bcd+0)
	Display_char(#' ')
	Send_Constant_String(#neg_9)
	ret
Display_formated_BCD_mF:
	Set_Cursor(2, 1)
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_char(#'.')
	Display_BCD(bcd+0)
	Send_Constant_String(#neg_6)
	ret
Display_formated_BCD_uF:
	Set_Cursor(2, 1)
	
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_char(#'.')
	Display_BCD(bcd+0)
	Display_char(#' ')
	Send_Constant_String(#neg_3)
	
	ret
Display_formated_BCD_nF:
	Set_Cursor(2, 1)
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_char(#'.')
	Display_BCD(bcd+0)
	Display_char(#'0')
	Display_char(#'0')
	ret
	Display_formated_BCD_pF:
	Set_Cursor(2, 1)
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	Display_char(#'0')
    Display_char(#'.')
    Display_char(#'0')
	Display_char(#'0')
	ret
	
Wait_one_second:	
    ;For a 24.5MHz clock one machine cycle takes 1/24.5MHz=40.81633ns
    mov R2, #198 ; Calibrate using this number to account for overhead delays
X3: mov R1, #245
X2: mov R0, #167
X1: djnz R0, X1 ; 3 machine cycles -> 3*40.81633ns*167=20.44898us (see table 10.2 in reference manual)
    djnz R1, X2 ; 20.44898us*245=5.01ms
    djnz R2, X3 ; 5.01ms*198=0.991s + overhead
    ret

wait_for_P2_4:
	jb P2.4, $ ; loop while the button is not pressed
	Wait_Milli_Seconds(#50) ; debounce time
	jb P2.4, wait_for_P2_4 ; it was a bounce, try again
	jnb P2.4, $ ; loop while the button is pressed
	ret

Display_Cap:  db 'Capacitance(xx):', 0
CLEAR: db '                  ',0
Display_F: db ' F',0
Display_mF: db 'mF',0
Display_uF: db 'uF',0
Display_nF: db 'nF',0
Display_pF: db 'pF',0

Select_unit: db 'Units: ',0
neg_3: db 'E^-3',0
neg_6: db 'E^-6',0 
neg_9: db 'E^-9',0


MyProgram:
	mov sp, #07FH ; Initialize the stack pointer
    
    ; DISABLE WDT: provide Watchdog disable keys
	mov	WDTCN,#0xDE ; First key
	mov	WDTCN,#0xAD ; Second key

    ; Enable crossbar and weak pull-ups
    mov	XBR0,#0x00
	mov	XBR1,#0x10 ; Enable T0 on P0.0.  T0 is the external clock input to Timer/Counter 0
	mov	XBR2,#0x40
	
	setb P2.4
	setb P2.3

	; Switch clock to 24 MHz
	mov	CLKSEL, #0x00 ; 
	mov	CLKSEL, #0x00 ; Second write to CLKSEL is required according to the user manual (page 77)
	
	mov a,#0x00
	mov Unit_sel,a
	; Wait for 24 MHz clock to stabilze by checking bit DIVRDY in CLKSEL
waitclockstable:
	mov a, CLKSEL
	jnb acc.7, waitclockstable 
	
	clr TR0 ; Stop timer 0
    mov a, TMOD
    anl a, #0b_1111_0000 ; Clear the bits of timer/counter 0
    orl a, #0b_0000_0101 ; Sets the bits of timer/counter 0 for a 16-bit counter
    mov TMOD, a

    lcall LCD_4BIT
    ljmp forever
Choose_units_d:
Set_Cursor(1,1)
Send_Constant_String(#CLEAR)
Set_Cursor(1,1)
Send_Constant_String(#Select_unit)
Set_Cursor(2,1)
Send_Constant_String(#CLEAR)
Choose_units:
jb P2.4,increment  ; loop while the button is not pressed
Wait_Milli_Seconds(#50) ; debounce time
jb P2.4,increment ; it was a bounce, try again
jnb P2.4, $ ; loop while the button is pressed
Set_Cursor(1,1)
Send_Constant_String(#CLEAR)
Set_Cursor(1,1)
Send_Constant_String(#Display_Cap)
ljmp calculate_val

increment:
jb P2.3,print_units  ; loop while the button is not pressed
Wait_Milli_Seconds(#50) ; debounce time
jb P2.3,print_units ; it was a bounce, try again
jnb P2.3, $ ; loop while the button is pressed
mov a,Unit_sel
add a,#0x01
mov Unit_sel,a
cjne a,#0x05,print_units
mov a,#0x00
mov Unit_sel,a

print_units:
Set_Cursor(1,1)
Send_Constant_String(#Select_unit)
mov a,Unit_sel
cjne a,#0x00,print_mF
Set_Cursor(1,7)
Send_Constant_String(#Display_F)
ljmp Choose_units
print_mF:
cjne a,#0x01,print_uF
Set_Cursor(1,7)
Send_Constant_String(#Display_mF)
ljmp Choose_units
print_uF:
cjne a,#0x02,print_nF
Set_Cursor(1,7)
Send_Constant_String(#Display_uF)
ljmp Choose_units
print_nF:
cjne a,#0x03,print_pF
Set_Cursor(1,7)
Send_Constant_String(#Display_nF)
ljmp Choose_units
print_pF:
cjne a,#0x04,restart
Set_Cursor(1,7)
Send_Constant_String(#Display_pF)
restart:
ljmp Choose_units


Set_Cursor(1,1)
Send_Constant_String(#CLEAR)
Set_Cursor(1,1)
Send_Constant_String(#Display_Cap)	

Forever:

; Measure the frequency applied to pin T0 (T0 is routed to pin P0.0 using the 'crossbar')
   ; Measure the frequency applied to pin T0 (T0 is routed to pin P0.0 using the 'crossbar')
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
    ljmp Choose_units_d
calculate_val:    
    Load_x(2000);RA
    Load_y(100) ;RB
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
	lcall hex2bcd
	mov a,Unit_sel
	cjne a,#0x00,displaymF
	Set_Cursor(1,13)
	Send_Constant_String(#Display_F)
	lcall Display_formated_BCD_F
	displaymF:
	cjne a,#0x01,displayuF
	Set_Cursor(1,13)
	Send_Constant_String(#Display_mF)
	lcall Display_formated_BCD_mF
	displayuF:
	cjne a,#0x02,displaynF
	Set_Cursor(1,13)
	Send_Constant_String(#Display_uF)
	lcall Display_formated_BCD_uF
	displaynF:
	cjne a,#0x03,displaypF
	Set_Cursor(1,13)
	Send_Constant_String(#Display_nF)
	lcall Display_formated_BCD_nF
	displaypF:
	cjne a,#0x04,done_display
	Set_Cursor(1,13)
	Send_Constant_String(#Display_pF)
	lcall Display_formated_BCD_pF ; result should be 1690.9309
    done_display:
    lcall wait_for_P2_4
	
	ljmp Forever
	
END
