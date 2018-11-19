/*
 * delay.xc
 *
 *  Created on: 2018. 2. 2.
 *      Author: 22wow
 */
#include <platform.h>
#include <stdio.h>
#include <delay.h>

void delay_millisecond(unsigned delay_ms)
{
    timer t;
    unsigned int time;
    t:>time;
    t when timerafter(time + MSTIMERCOUNT * delay_ms) :> void;
}

void delay_microsecond(unsigned delay_us)
{
    timer t;
    unsigned int time;
    t:>time;
    t when timerafter(time + USTIMERCOUNT * delay_us) :> void;
}
