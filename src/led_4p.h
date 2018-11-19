/*
 * led.h
 *
 *  Created on: 2018. 2. 2.
 *      Author: 22wow
 */


#ifndef LED_H_
#define LED_H_

void toggle_led(void);
void blinky(unsigned period_ms, unsigned end_count);
void ledInit();
void led0_On();
void led0_Off();
void led0_Toggle();
void led1_On();
void led1_Off();
void led1_Toggle();
void led2_On();
void led2_Off();
void led2_Toggle();
void led3_On();
void led3_Off();
void led3_Toggle();

#endif /* LED_H_ */
