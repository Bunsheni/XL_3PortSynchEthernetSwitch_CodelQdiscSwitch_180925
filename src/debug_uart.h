/*
 * debug_uart.h
 *
 *  Created on: 2018. 9. 25.
 *      Author: 22wow
 */


#ifndef DEBUG_UART_H_
#define DEBUG_UART_H_
#include <xs1.h>
#include <platform.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include "stddef.h"
#include "ethernet.h"
#include "print.h"
#include "xassert.h"
#include "ntoh.h"
#include "queue.h"
#include "delay.h"
#include "led_4p.h"
#include "uart.h"
#include "gpio.h"

typedef enum smi_type_e {
    STOP,
    READ_REGISTER,
    WRITE_REGISTER,
    SELECT_QUEUE,

} control_type_e;

typedef enum debug_mode_e {
    NOTHING = 0,
    QUEUE = 1,
    FILTER = 2,
    PHYSMI = 3,
    SELECT_PORT = 4,
    SELECTPORT = 5
} debug_mode_e;

typedef enum debug_portn_e {
    PORT0,
    PORT1,
    PORT2,
    NOSELECT
} debug_portn_e;
typedef struct
{
  unsigned portn;
  unsigned type;
  unsigned gate;
  unsigned drop_packet;
  unsigned total_packet;
  unsigned incoming_packet;
  unsigned queue_length;
  unsigned loss_packet;
  unsigned timestamp;
  unsigned queueingtime;
} signal_t;

typedef struct control_info_t
{
    unsigned char type;
    unsigned char portn;
    unsigned char phy_address;
    unsigned char reg_address;
    unsigned short value[32];
}control_info_t;

typedef interface debug_if {
    [[notification]] slave void request_control();
    [[clears_notification]] void get_control(control_info_t &desc);
//   void send_packet_data(unsigned char* data, unsigned n, unsigned work_n);
   void send_smi_data(control_info_t &desc);
   void send_queue_status(signal_t &desc);
   void printf(char * unsafe a);
} debug_if;


void codel_debug(
        client uart_rx_if i_rx, client uart_tx_if i_tx,
        server debug_if i_debug[n], unsigned char n);
int debug_uart(server debug_if i_debug[n], unsigned char n);





#endif /* DEBUG_UART_H_ */
