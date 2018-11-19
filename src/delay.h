/*
 * delay.h
 *
 *  Created on: 2018. 2. 2.
 *      Author: 22wow
 */


#ifndef DELAY_H_
#define DELAY_H_

#define MSTIMERCOUNT XS1_TIMER_HZ/1000
#define USTIMERCOUNT XS1_TIMER_HZ/1000000

void delay_millisecond(unsigned delay_ms);
void delay_microsecond(unsigned delay_us);

#endif /* DELAY_H_ */
