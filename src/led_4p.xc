/*
 * led.xc
 * KONG Board LED Operation Library
 *  Created on: 2018. 2. 2.
 *      Author: 22wow
 */

#include <platform.h>
#include <stdio.h>
#include <delay.h>
#include <led_4p.h>

on tile[0] : port p_4led = XS1_PORT_4D;  //Port: XS1_4B0, Pin: X1_D04
unsigned int val = 0;
/*
 * toggle led
 */
void toggle_led(void)
{
    val++;
    p_4led <: val;
}

/*
 * blink led
 * parameter
 *      onoff_term: turn on/off term, half of period
 *      end_count: turn on/off count is over this parameter, finish
 * local variable
 *      count: turn on/off count
 *      time: turn on/off time from timer
 */
void blinky(unsigned onoff_term, unsigned end_count)
{
    unsigned count, time;
    timer t;
    count = 0;
    t:>time;
    unsigned msterm = MSTIMERCOUNT * onoff_term;
    while(1)
    {
        count++;
        if(end_count != 0 && count > end_count) break;
        toggle_led();
        time = time + msterm;
        t when timerafter(time):> void;
    }
}

void ledInit()
{
    printf("LED Init!\n");
    val = 0xFFFF;
    p_4led <: val;
}
void led0_On()
{
    val = val&14;
    p_4led <: val;
}
void led0_Off()
{
    val = val|1;
    p_4led <: val;
}
void led0_Toggle()
{
    val = val^1;
    p_4led <: val;
}
void led1_On()
{
    val = val&13;
    p_4led <: val;
}
void led1_Off()
{
    val = val|2;
    p_4led <: val;
}
void led1_Toggle()
{
    val = val^2;
    p_4led <: val;
}
void led2_On()
{
    val = val&11;
    p_4led <: val;
}
void led2_Off()
{
    val = val|4;
    p_4led <: val;
}
void led2_Toggle()
{
    val = val^4;
    p_4led <: val;
}
void led3_On()
{
    val = val&7;
    p_4led <: val;
}
void led3_Off()
{
    val = val|8;
    p_4led <: val;
}
void led3_Toggle()
{
    val = val^8;
    p_4led <: val;
}

