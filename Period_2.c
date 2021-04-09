#include <XC.h>
#include <stdio.h>
#include <stdlib.h>
 
// Configuration Bits (somehow XC32 takes care of this)
#pragma config FNOSC = FRCPLL       // Internal Fast RC oscillator (8 MHz) w/ PLL
#pragma config FPLLIDIV = DIV_2     // Divide FRC before PLL (now 4 MHz)
#pragma config FPLLMUL = MUL_20     // PLL Multiply (now 80 MHz)
#pragma config FPLLODIV = DIV_2     // Divide After PLL (now 40 MHz)
#pragma config FWDTEN = OFF         // Watchdog Timer Disabled
#pragma config FPBDIV = DIV_1       // PBCLK = SYCLK
#pragma config FSOSCEN = OFF        // Secondary Oscillator Enable (Disabled)

// Defines
#define SYSCLK 40000000L
#define Baud2BRG(desired_baud)( (SYSCLK / (16*desired_baud))-1)
 
void UART2Configure(int baud_rate)
{
    // Peripheral Pin Select
    U2RXRbits.U2RXR = 4;    //SET RX to RB8
    RPB9Rbits.RPB9R = 2;    //SET RB9 to TX

    U2MODE = 0;         // disable autobaud, TX and RX enabled only, 8N1, idle=HIGH
    U2STA = 0x1400;     // enable TX and RX
    U2BRG = Baud2BRG(baud_rate); // U2BRG = (FPb / (16*baud)) - 1
    
    U2MODESET = 0x8000;     // enable UART2
}

// Needed to by scanf() and gets()
int _mon_getc(int canblock)
{
	char c;
	
    if (canblock)
    {
	    while( !U2STAbits.URXDA); // wait (block) until data available in RX buffer
	    c=U2RXREG;
	    if(c=='\r') c='\n'; // When using PUTTY, pressing <Enter> sends '\r'.  Ctrl-J sends '\n'
		return (int)c;
    }
    else
    {
        if (U2STAbits.URXDA) // if data available in RX buffer
        {
		    c=U2RXREG;
		    if(c=='\r') c='\n';
			return (int)c;
        }
        else
        {
            return -1; // no characters to return
        }
    }
}

// Use the core timer to wait for 1 ms.
void wait_1ms(void)
{
    unsigned int ui;
    _CP0_SET_COUNT(0); // resets the core timer count

    // get the core timer count
    while ( _CP0_GET_COUNT() < (SYSCLK/(2*1000)) );
}

void waitms(int len)
{
	while(len--) wait_1ms();
}

#define PIN_PERIOD (PORTB&64)

// GetPeriod() seems to work fine for frequencies between 200Hz and 700kHz.
long int GetPeriod (int n)
{
	int i;
	unsigned int saved_TCNT1a, saved_TCNT1b;
	
    _CP0_SET_COUNT(0); // resets the core timer count
	while (PIN_PERIOD!=0) // Wait for square wave to be 0
	{
		if(_CP0_GET_COUNT() > (SYSCLK/4)) return 0;
	}

    _CP0_SET_COUNT(0); // resets the core timer count
	while (PIN_PERIOD==0) // Wait for square wave to be 1
	{
		if(_CP0_GET_COUNT() > (SYSCLK/4)) return 0;
	}
	
    _CP0_SET_COUNT(0); // resets the core timer count
	for(i=0; i<n; i++) // Measure the time of 'n' periods
	{
		while (PIN_PERIOD!=0) // Wait for square wave to be 0
		{
			if(_CP0_GET_COUNT() > (SYSCLK/4)) return 0;
		}
		while (PIN_PERIOD==0) // Wait for square wave to be 1
		{
			if(_CP0_GET_COUNT() > (SYSCLK/4)) return 0;
		}
	}

	return  _CP0_GET_COUNT();
}

// Information here:
// http://umassamherstm5.org/tech-tutorials/pic32-tutorials/pic32mx220-tutorials/1-basic-digital-io-220
void main(void)
{
	long int count;
	int i;
	int zero=0;
	float T, f;
	float config;
	float detected;
	float freqs[3];
	
	CFGCON = 0;
  
    UART2Configure(115200);  // Configure UART2 for a baud rate of 115200
    
    ANSELB &= ~64; // Set RB5 as a digital I/O
    TRISB = 64;   // configure pin RB5 as input
    TRISBbits.TRISB5 = 0;
    CNPDBbits.CNPDB6 = 1;   // Enable pull-up resistor for RB5
 
	waitms(500);
	printf("Period measurement using the core timer free running counter.\r\n"
	      "Connect signal to RB6 (pin 15).\r\n");
	waitms(500);
	
	LATBbits.LATB5 = 0;
	
	for(i=0;i<10;i++){
	count=GetPeriod(100);
		if(count>0)
		{
			T=(count*2.0)/(SYSCLK*100.0);
			f=1/T;
			printf("Configuring...                     \r");
		}else
		{	printf("NO SIGNAL: Check RB6                     \r");
		}
		waitms(200);
		}
		
		config=f;	
    
     while(1)
    {
    
    
		count=GetPeriod(100);
		if(count>0)
		{
			T=(count*2.0)/(SYSCLK*100.0);
			f=1/T;
			detected=f-config;
			
			
			if(detected<-18&&detected>-50){
			printf("Micro - Ferromagnetic; %f %f %f\r", f, detected, config);
			}else
			if(detected<-50&&detected>-100){
			printf("Small - Ferromagnetic; %f %f %f\r", f, detected, config);
			}else
			if(detected<-100&&detected>-275){
			printf("Medium - Ferromagnetic; %f %f %f \r", f, detected, config);
			}else
			if(detected<-275){
			printf("Large - Ferromagnetic; %f %f %f\r", f, detected, config);
			}else
			if(detected>18&&detected<50){
			printf("Micro - Paramagnetic; %f %f %f\r", f, detected, config);
			}else
			if(detected>50&&detected<100){
			printf("Small - Paramagnetic; %f %f %f\r", f, detected, config);
			}else
			if(detected<275&&detected>100){
			printf("Medium - Paramagnetic; %f %f %f\r", f, detected, config);
			}else
			if(detected>275){
			printf("Large - Paramagnetic; %f %f %f\r", f, detected, config);
			}else{
			
			printf("NO METAL DETECTED %f  %f %f\r", f, detected, config);
			
			freqs[zero] = f;
			zero++;
			
			
			if(zero==3){
			
				config = (freqs[0]+freqs[1]+freqs[2])/3;
				zero = 0;
			}
			}

		}
		else
		{
		
		
			printf("NO SIGNAL: Check RB6                     \r");
		}
		waitms(200);
    }
}
