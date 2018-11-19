/*
 * XL_3PortSynchEthernetSwitch_EthernetDemo_180222.xc
 *
 *  Created on: 2018. 2. 22.
 *      Author: 22wow
 */


#include <xs1.h>
#include <platform.h>
#include <stdio.h>
#include <delay.h>
#include "ethernet.h"
#include "smi.h"
#include "ethernet_phy.h"
#include "debug_uart.h"

int main(void)
{
    ethernet_cfg_if i_cfg[ETHERNET_PORTS];
    switch_data_if i_switch[ETHERNET_PORTS][2];
    smi_if i_smi;
    filter_reqest_if i_filter[3];
    filter_signal_if i_signal;
    debug_if i_debug[2];

  par
  {
    on tile[1]: debug_uart(i_debug, 2);
    on tile[0]: smi_kong(i_smi);
    on tile[1]: control_driver(i_smi, i_cfg, i_debug[0], i_signal);
    on tile[0]: filter_kong(i_filter, i_debug[1], i_signal);
    on tile[1]: mii0_kong(i_cfg[0], i_filter[0], i_switch[0][1], i_switch[2][0], i_switch[0][0], i_switch[2][1], NOQUEUE);
    on tile[0]: mii1_kong(i_cfg[1], i_filter[1], i_switch[1][1], i_switch[0][0], i_switch[1][0], i_switch[0][1], CODEL);
    on tile[0]: mii2_kong(i_cfg[2], i_filter[2], i_switch[2][1], i_switch[1][0], i_switch[2][0], i_switch[1][1], NOQUEUE);
  }

  return 0;
}
