/*
 * ethernet_phy.xc
 *
 *  Created on: 2018. 2. 2.
 *      Author: 22wow
 */

// Here are the port definitions required by ethernet. This port assignment
// is for the KONG Borad of YoonLAB

#include "ethernet_phy.h"

port p_eth0_rxclk  = on tile[1]: XS1_PORT_1C;
port p_eth0_rxd    = on tile[1]: XS1_PORT_4F;
port p_eth0_txd    = on tile[1]: XS1_PORT_4D;
port p_eth0_rxdv   = on tile[1]: XS1_PORT_1D;
port p_eth0_txen   = on tile[1]: XS1_PORT_1O;
port p_eth0_txclk  = on tile[1]: XS1_PORT_1P;
port p_eth0_rxerr  = on tile[1]: XS1_PORT_1L;
port p_eth0_dummy  = on tile[1]: XS1_PORT_1M;
clock eth0_rxclk   = on tile[1]: XS1_CLKBLK_1;
clock eth0_txclk   = on tile[1]: XS1_CLKBLK_2;

port p_eth1_rxclk  = on tile[0]: XS1_PORT_1K;
port p_eth1_rxd    = on tile[0]: XS1_PORT_4E;
port p_eth1_txd    = on tile[0]: XS1_PORT_4F;
port p_eth1_rxdv   = on tile[0]: XS1_PORT_1L;
port p_eth1_txen   = on tile[0]: XS1_PORT_1I;
port p_eth1_txclk  = on tile[0]: XS1_PORT_1J;
port p_eth1_rxerr  = on tile[0]: XS1_PORT_1A;
port p_eth1_dummy  = on tile[0]: XS1_PORT_1B;
clock eth1_rxclk   = on tile[0]: XS1_CLKBLK_1;
clock eth1_txclk   = on tile[0]: XS1_CLKBLK_2;

port p_eth2_rxclk  = on tile[0]: XS1_PORT_1H;
port p_eth2_rxd    = on tile[0]: XS1_PORT_4A;
port p_eth2_txd    = on tile[0]: XS1_PORT_4C;
port p_eth2_rxdv   = on tile[0]: XS1_PORT_1G;
port p_eth2_txen   = on tile[0]: XS1_PORT_1F;
port p_eth2_txclk  = on tile[0]: XS1_PORT_1E;
port p_eth2_rxerr  = on tile[0]: XS1_PORT_1C;
port p_eth2_dummy  = on tile[0]: XS1_PORT_1D;
clock eth2_rxclk   = on tile[0]: XS1_CLKBLK_3;
clock eth2_txclk   = on tile[0]: XS1_CLKBLK_4;


port p_eth_reset  = on tile[0]: XS1_PORT_1M;
port p_smi_mdio   = on tile[0]: XS1_PORT_1P;
port p_smi_mdc    = on tile[0]: XS1_PORT_1O;

static unsigned char phy_address[3] = {0x2, 0x2, 0x9};
static unsigned char phy_embeded[3] = {1, 1, 0};

enum status_update_state_t {
  STATUS_UPDATE_IGNORING,
  STATUS_UPDATE_WAITING,
  STATUS_UPDATE_PENDING,
};
enum gate_state_t {
  GATE_CLOSE,
  GATE_OPEN,
};


#pragma unsafe arrays
unsigned do_forwarding(eth_global_forward_info_t table,
        char buf[packet_size], size_t packet_size, char nport)
{
    unsigned char res = 3;
    unsigned found = 0;
    char nPort = nport;
    int blankTableIndex = -1;
    unsigned *addr;

  unsigned *words = (unsigned *)buf;
  // Do all entries without an early exit so that it is always worst-case timing
  for (size_t i = 0;i < ETHERNET_MACADDR_FOWARDING_TABLE_SIZE; i++)
  {
      addr = (unsigned *)table[i].addr;
    if(table[i].result != 0)
    {
        //source address check
        if(((words[1]>>16&0xffff)|((words[2]<<16)&(0xffff0000))) == addr[0] && (words[2]>>16 & 0xffff) == (addr[1] & 0xffff))
        {
            table[i].result = FILTER_TIMER;
            found = 1;
        }
        //destination address check
        if(((words[0] == addr[0]) && ((words[1] & 0xffff) == (addr[1] & 0xffff))))
        {
            res = nPort != table[i].nPort ? table[i].nPort : -1;
        }
    }
    else if(blankTableIndex == -1)
    {
        blankTableIndex = i;
    }
  }
  //못찾았고 빈곳이 있으면 그곳에 저장
  if(!found && blankTableIndex != -1)
  {
      int j;
      // Found an empty entry, use it
      memcpy(table[blankTableIndex].addr, ((char*) words) + 6, 6);
      table[blankTableIndex].result = FILTER_TIMER;
      table[blankTableIndex].nPort = nPort;
#if(DEBUG)
      for(j=0;j<6;j++)
      {
          printf("%x",((char*)words)[6+j]);
      }
      printf(" is Registered with port%d at table %d\n", nPort, blankTableIndex);
#endif
  }
  return res;
}

void process_time_forward_table(eth_global_forward_info_t table)
{
  for (size_t i = 0; i < ETHERNET_MACADDR_FOWARDING_TABLE_SIZE; i++) {
      if(table[i].result > 0)
      {
          table[i].result--;
#if(DEBUG)
          if(table[i].result == 0)
              printf("Filter %d is deleted\n", i);
#endif
      }
  }
}

void smi_kong(server interface smi_if i_smi)
{
    p_eth_reset <: 1;
    smi(i_smi, p_smi_mdio, p_smi_mdc);
}

void mii0_kong(server ethernet_cfg_if i_cfg,
        server filter_reqest_if i_filter,
        server switch_data_if i_rx0,
        server switch_data_if i_rx1,
        client switch_data_if i_tx0,
        client switch_data_if i_tx1,
        queueing_algorithm_e queueing_algorithm)
{
    interface mii_if i_mii;
    printf("MII 0 Run\n");
    par {
        mii(i_mii, p_eth0_rxclk, p_eth0_rxerr, p_eth0_rxd, p_eth0_rxdv, p_eth0_txclk,
                p_eth0_txen, p_eth0_txd, p_eth0_dummy,
                eth0_rxclk, eth0_txclk, ETH_RX_BUFFER_SIZE_WORDS);
        mii_ethernet_switch_aux(i_mii, i_cfg, i_filter,
                     i_rx0, i_rx1, i_tx0, i_tx1, 0, queueing_algorithm);

    }
}

void mii1_kong(server ethernet_cfg_if i_cfg,
        server filter_reqest_if i_filter,
        server switch_data_if i_rx0,
        server switch_data_if i_rx1,
        client switch_data_if i_tx0,
        client switch_data_if i_tx1,
        queueing_algorithm_e queueing_algorithm)
{
    interface mii_if i_mii;
    printf("MII 1 Run\n");
    par {
        mii(i_mii, p_eth1_rxclk, p_eth1_rxerr, p_eth1_rxd, p_eth1_rxdv, p_eth1_txclk,
                p_eth1_txen, p_eth1_txd, p_eth1_dummy,
                eth1_rxclk, eth1_txclk, ETH_RX_BUFFER_SIZE_WORDS);
        mii_ethernet_switch_aux(i_mii, i_cfg, i_filter,
                     i_rx0, i_rx1, i_tx0, i_tx1, 1, queueing_algorithm);

    }
}

void mii2_kong(server ethernet_cfg_if i_cfg,
        server filter_reqest_if i_filter,
        server switch_data_if i_rx0,
        server switch_data_if i_rx1,
        client switch_data_if i_tx0,
        client switch_data_if i_tx1,
        queueing_algorithm_e queueing_algorithm)
{
    interface mii_if i_mii;
    printf("MII 3 Run\n");
    par {
        mii(i_mii, p_eth2_rxclk, p_eth2_rxerr, p_eth2_rxd, p_eth2_rxdv, p_eth2_txclk,
                p_eth2_txen, p_eth2_txd, p_eth2_dummy,
                eth2_rxclk, eth2_txclk, ETH_RX_BUFFER_SIZE_WORDS);
        mii_ethernet_switch_aux(i_mii, i_cfg, i_filter,
                     i_rx0, i_rx1, i_tx0, i_tx1, 2, queueing_algorithm);

    }
}

unsigned smi_phy_is_powered_down_n(client smi_if smi, int i)
{
  return ((smi.read_reg(phy_address[i], BASIC_CONTROL_REG) >> BASIC_CONTROL_POWER_DOWN_BIT) & 1);
}

ethernet_link_state_t smi_get_link_state_n(client interface smi_if smi, int i)
{
    unsigned link_up = ((smi.read_reg(phy_address[i], BASIC_STATUS_REG) >> BASIC_STATUS_LINK_BIT) & 1);
    return link_up ? ETHERNET_LINK_UP : ETHERNET_LINK_DOWN;;
}

ethernet_speed_t smi_get_link_speed_n(client smi_if smi, int i)
{
    if ((smi.read_reg(phy_address[i], 0x1F) >> 2) & 1) {
      return LINK_10_MBPS_FULL_DUPLEX;
    }
    else {
      return LINK_100_MBPS_FULL_DUPLEX;
    }
}

void smi_configure_n(client smi_if smi, int i, ethernet_speed_t speed_mbps, smi_autoneg_t auto_neg)
{
  if (speed_mbps != LINK_10_MBPS_FULL_DUPLEX &&
      speed_mbps != LINK_100_MBPS_FULL_DUPLEX &&
      speed_mbps != LINK_1000_MBPS_FULL_DUPLEX) {
    printf("Invalid Ethernet speed provided, must be 10, 100 or 1000");
  }

  if (auto_neg == SMI_ENABLE_AUTONEG) {
    uint16_t auto_neg_advert_100_reg = smi.read_reg(phy_address[i], AUTONEG_ADVERT_REG);
    uint16_t gige_control_reg = smi.read_reg(phy_address[i], GIGE_CONTROL_REG);

    // Clear bits [9:5]
    auto_neg_advert_100_reg &= 0xfc1f;
    // Clear bits [9:8]
    gige_control_reg &= 0xfcff;

    switch (speed_mbps) {
    #pragma fallthrough
      case LINK_1000_MBPS_FULL_DUPLEX: gige_control_reg |= 1 << AUTONEG_ADVERT_1000BASE_T_FULL_DUPLEX;
    #pragma fallthrough
      case LINK_100_MBPS_FULL_DUPLEX: auto_neg_advert_100_reg |= 1 << AUTONEG_ADVERT_100BASE_TX_FULL_DUPLEX;
      case LINK_10_MBPS_FULL_DUPLEX: auto_neg_advert_100_reg |= 1 << AUTONEG_ADVERT_10BASE_TX_FULL_DUPLEX; break;
      default: __builtin_unreachable(); break;
    }

    // Write back
    smi.write_reg(phy_address[i], AUTONEG_ADVERT_REG, auto_neg_advert_100_reg);
    smi.write_reg(phy_address[i], GIGE_CONTROL_REG, gige_control_reg);
  }

  uint16_t basic_control = smi.read_reg(phy_address[i], BASIC_CONTROL_REG);
  if (auto_neg == SMI_ENABLE_AUTONEG) {
    // set autoneg bit
    basic_control |= 1 << BASIC_CONTROL_AUTONEG_EN_BIT;
    smi.write_reg(phy_address[i], BASIC_CONTROL_REG, basic_control);
    // restart autoneg
    basic_control |= 1 << BASIC_CONTROL_RESTART_AUTONEG_BIT;
  }
  else {
    // set duplex mode, clear autoneg and speed
    basic_control |= 1 << BASIC_CONTROL_FULL_DUPLEX_BIT;
    basic_control &= ~( (1 << BASIC_CONTROL_AUTONEG_EN_BIT)|
                          (1 << BASIC_CONTROL_100_MBPS_BIT)|
                         (1 << BASIC_CONTROL_1000_MBPS_BIT));

    if (speed_mbps == LINK_100_MBPS_FULL_DUPLEX) {
      basic_control |= 1 << BASIC_CONTROL_100_MBPS_BIT;
    } else if (speed_mbps == LINK_1000_MBPS_FULL_DUPLEX) {
      printf("Autonegotiation cannot be disabled in 1000 Mbps mode");
    }
  }
  smi.write_reg(phy_address[i], BASIC_CONTROL_REG, basic_control);
}

void ethernet_init_forward_table(eth_global_forward_info_t table)
{
  for (size_t i = 0; i < ETHERNET_MACADDR_FOWARDING_TABLE_SIZE; i++) {
    memset(table[i].addr, 0, sizeof table[i].addr);
    table[i].result = 0;
    table[i].appdata = 0;
  }
}


void control_driver(client interface smi_if i_smi, client ethernet_cfg_if i_cfg[3],
        client debug_if i_debug, server filter_signal_if i_signal)
{
    ethernet_link_state_t link_state[ETHERNET_PORTS];
    ethernet_speed_t link_speed[ETHERNET_PORTS];
    const int link_poll_period_ms = 1000;
    const int debug_poll_period_ms = 100;
    unsigned char phy_init_state[ETHERNET_PORTS];
    timer tmr, tmr2;
    int t, tt, index;
    control_info_t control_info;
    signal_t signal_info;
    control_info.type = 0;
    control_info.portn = 0;
    control_info.reg_address = 0;
    for(index = 0; index < ETHERNET_PORTS; index++)
    {
        phy_init_state[index] = 0;
        link_state[index]  = ETHERNET_LINK_DOWN;
        link_speed[index]  = ETH_SPEED_INIT;
    }
    tmr :> t;
    tmr2 :> tt;

    i_debug.printf("\r\nThis is CodelQdisc Switch\n\r1: queue debug, 2: filter debug, 3: phy debug\n\r");
    while(1)
    {
      select
      {
      case i_signal.get_signal(signal_t &desc):
          if(signal_info.total_packet != desc.total_packet)
          {
              memcpy(&signal_info, &desc, sizeof(signal_info));
              i_debug.send_queue_status(signal_info);
          }
          break;
      case i_signal.filter_signal(char ports):
          break;
      case i_debug.request_control():
          i_debug.get_control(control_info);
          if(control_info.type == READ_REGISTER)
          {
              printf("phy control\n");
              unsigned short data[32];
              int i, j;
              char * string;
              control_info.phy_address = phy_address[control_info.portn];
              if(control_info.reg_address<0)
              {
                  for(i = 0;i < 32;i++)
                  {
                      control_info.value[i] = i_smi.read_reg(phy_address[control_info.portn], i);
                  }
              }
              else if(control_info.reg_address < 32)
              {
                  control_info.value[control_info.reg_address] = i_smi.read_reg(phy_address[control_info.portn], control_info.reg_address);
              }
              i_debug.send_smi_data(control_info);
          }
          else if(control_info.type == WRITE_REGISTER)
          {
              i_smi.write_reg(phy_address[control_info.portn], control_info.reg_address, control_info.value[control_info.reg_address]);
          }
          else if(control_info.type == SELECTPORT)
          {

          }
          break;
      case tmr2 when timerafter(tt) :> tt:
          i_signal.signal_reqeust();
        tt += debug_poll_period_ms * XS1_TIMER_KHZ;
        break;
      case tmr when timerafter(t) :> t:
        for(index = 0; index<3; index++)
        {
            if(phy_embeded[index])
            {
                if (phy_init_state[index] == 0 && phy_embeded[index])
                    if(!smi_phy_is_powered_down_n(i_smi, index))
                {
                    smi_configure_n(i_smi, index, LINK_100_MBPS_FULL_DUPLEX, SMI_ENABLE_AUTONEG);
                    phy_init_state[index] = 1;

                    printf("PHY%d on\n", index);
                }

                if(phy_init_state[index] == 1)
                {
                    ethernet_link_state_t new_state = smi_get_link_state_n(i_smi, index);
                    if (new_state != link_state[index]){
                        if (new_state == ETHERNET_LINK_UP) {
                            printf("Port%d link_state: UP\n", index);
                            link_speed[index] = 1;//smi_get_link_speed_n(i_smi, index)
                            if(link_speed[index] == 1)
                                printf("Port%d link_speed: 100Mb\n", index);
                            else
                                printf("Port%d link_speed: 10Mb\n", index);
                        }else{
                            printf("Port%d link_state: DOWN\n", index);
                        }
                        link_state[index] = new_state;
                        i_cfg[index].set_link_state(0, new_state, link_speed[index]);
                    }
                }
            }
        }
        t += link_poll_period_ms * XS1_TIMER_KHZ;
        break;
      }
    }
}

void filter_kong(client filter_reqest_if i_filter[3],
        client debug_if i_debug, client filter_signal_if i_signal)
{
    timer tmr;
    unsigned period_end_time;
    const int link_poll_period = 1000 * XS1_TIMER_KHZ;
    unsigned char buf[12];
    char port0, port1, portn, tmp, res;
    eth_global_forward_info_t forward_info;
    signal_t packet_info[3];
    for(int i=0;i<3;i++)
    {
        packet_info[i].total_packet = 0;
        packet_info[i].loss_packet = 0;
        packet_info[i].drop_packet = 0;
        packet_info[i].timestamp = 0;
        packet_info[i].incoming_packet = 0;
        packet_info[i].portn = i;
        packet_info[i].queue_length = 0;
        packet_info[i].queueingtime = 0;
    }

    ethernet_init_forward_table(forward_info);
    tmr :> period_end_time;
    while(1)
    {
      select
      {
          case tmr when timerafter(period_end_time) :> period_end_time:
            process_time_forward_table(forward_info);
            period_end_time += link_poll_period;
            break;
          case i_signal.signal_reqeust():
              i_signal.get_signal(packet_info[1]);
              break;


          case i_filter[int i].filtering_reqeust():
            i_filter[i].get_packet(packet_info[i], buf, 12);
            //printf("Get Packet %d at %d\n", packet_info.len, i);
            tmp = do_forwarding(forward_info, buf, 12, i);// 3:send to All/0,1,2:portnumber to be sended/-1:no send
            port0 = i==2 ? 0 : i+1;
            port1 = i==0 ? 2 : i-1;
            if(tmp < 2)
            {
                if(phy_embeded[port0] && phy_embeded[port1])
                    res = 2;
                else if(phy_embeded[port0])
                    res = 0;
                else if(phy_embeded[port1])
                    res = 1;
                else
                    res = -1;
            }
            else if(0 > res)
            {
                res = -1;
            }
            else
            {
                res = -1;
                for(portn=0; portn<3; portn++)
                {
                    if(phy_embeded[port0] && port0 == portn)
                    {
                        res = 0;
                        break;
                    }
                    else if(phy_embeded[port1] && port1 == portn)
                    {
                        res = 1;
                        break;
                    }
                }
            }
            i_filter[i].filter_response(res);
            break;
      }
    }
}


unsigned control_law(unsigned t, unsigned count, unsigned interval)
{
    return t + interval/sqrt(count);
}

void mii_ethernet_switch_aux(client mii_if i_mii,
                             server ethernet_cfg_if i_cfg,
                             server filter_reqest_if i_filter,
                             server switch_data_if i_rx0,
                             server switch_data_if i_rx1,
                             client switch_data_if i_tx0,
                             client switch_data_if i_tx1,
                             char nPort, queueing_algorithm_e queueing_algorithm)
{
    unsafe {
      uint8_t mac_address[MACADDR_NUM_BYTES] = {0};
      ethernet_link_state_t link_status = ETHERNET_LINK_DOWN;
      ethernet_speed_t link_speed = LINK_100_MBPS_FULL_DUPLEX;
      client_state_t client_state;
      int txbuf[(ETHERNET_MAX_PACKET_SIZE+3)/4];
      mii_info_t mii_info;
      int filtering_nbytes;
      int incoming_timestamp;
      int incoming_tcount;
      int outgoing_nbytes;
      int outgoing_timestamp;
      int outgoing_tcount;
      int outgoing_sourceport;
      int * unsafe filtering_data = null;


      //for queueing init
      timer queueing_timer;
      queue_t *data_queue_p;
      unsigned time_gate_open = GATEOPENUS;
      unsigned time_gate_close = GATECLOSEUS;
      unsigned time_period = GATEOPENUS + GATECLOSEUS;
      unsigned gate_period = (time_period) * USTIMERCOUNT;
      unsigned gate_blocking_time = GATECLOSEUS * USTIMERCOUNT;
      unsigned gate_nonblocking_time = GATEOPENUS * USTIMERCOUNT;

      unsigned time;
      unsigned period;
      char gate_open = 0;
      data_queue_p = (queue_t *)(init_queue(1000));
      queue_t a = *data_queue_p;
      queueing_timer:>time;
      char nofiltering = 0;

      //for codel
      unsigned target = USTIMERCOUNT * TARGET;
      unsigned interval = USTIMERCOUNT * INTERVAL;
      unsigned MTU = 10;
      char drop_state = 0;
      unsigned count = 0;
      unsigned last_count = 0;
      unsigned next_drop_time = 0;
      unsigned delta = 0;
      unsigned sojourntime = 0;
      unsigned totalqueueingtime = 0;
      unsigned averagequeueingtime = 0;

      client_state.portn = nPort;
      client_state.status_update_state = STATUS_UPDATE_IGNORING;
      client_state.filtering_packet = 0;
      client_state.incoming_packet = 0;
      client_state.outgoing_packet = 0;
      client_state.outgoing_total = 0;
      client_state.num_etype_filters = 0;
      client_state.gate_open = GATE_CLOSE;
      client_state.drop_packet = 0;
      client_state.total_packet = 0;
      client_state.loss_packet = 0;
      client_state.gate = queueing_algorithm;

      mii_info = i_mii.init();
      while (1) {

          //output operation for packets in queue;
          if(queueing_algorithm == CODEL)
          {
              packet_t *outgoing_packet;
              unsigned outgoing_bytelen;
              char *outgoing_data;
              if(gate_open && data_queue_p->length > 0 && client_state.outgoing_packet == 0)
              {
                  unsigned enqtime;
                  unsigned sojourn_time;
                  unsigned length = data_queue_p->head->next->length;
                  double bitlen = ((length*8+3)/100);
                  unsigned duration = bitlen * USTIMERCOUNT;
                  unsigned deqtime;
                  queueing_timer:> deqtime;

                  if(deqtime + duration < time)
                  {
                      outgoing_packet = (packet_t *)(dequeue(data_queue_p));

                      unsigned queue_length = data_queue_p->length;
                      enqtime = outgoing_packet->timestamp;
                      sojourn_time = deqtime - enqtime;

                      //////////////
                      unsigned deq_close_t = time; //다음 gate가 닫힐시간
                      unsigned deq_open_t = time - gate_nonblocking_time; //마지막으로 gate가 열린시간
                      if(1)
                      {
                          if(enqtime < deq_open_t)
                          {
                              int n = (deq_open_t-enqtime)/gate_period + 1;
                              unsigned enq_close_t = deq_close_t - gate_period * n; //마지막으로 gate가 열린시간
                              unsigned enq_open_t = enq_close_t - gate_nonblocking_time;
                              if(enq_close_t>enqtime)
                              {
                                  sojourn_time = (enq_close_t - enqtime) + (deqtime - deq_open_t) + ((n-1) * gate_nonblocking_time);
                              }
                              else
                              {
                                  sojourn_time = (deqtime - deq_open_t) + ((n-1) * gate_nonblocking_time);
                              }
                          }
                          else
                          {
                              sojourn_time = deqtime - enqtime;
                          }
                      }
////////////////////////////


                      outgoing_packet->outgoingtime = deqtime;
                      outgoing_packet->queueingtime = sojourn_time;

                      if(drop_state)
                      {
                          if(sojourn_time < target || queue_length < MTU)
                          {
                              drop_state = 0;
                          }
                          else
                          {
                              while(deqtime >= next_drop_time && drop_state)
                              {
                                  client_state.drop_packet++;
                                  free(outgoing_packet->data);
                                  free(outgoing_packet);//drop
                                  outgoing_packet = 0;
                                  outgoing_packet = (packet_t *)(dequeue(data_queue_p));
                                  enqtime = outgoing_packet->timestamp;

                                  sojourn_time = deqtime - enqtime;
                                  if(1)
                                  {
                                      if(enqtime < deq_open_t)
                                      {
                                          int n = (deq_open_t-enqtime)/gate_period + 1;
                                          unsigned enq_close_t = deq_close_t - gate_period * n; //마지막으로 gate가 열린시간
                                          unsigned enq_open_t = enq_close_t - gate_nonblocking_time;
                                          if(enq_close_t>enqtime)
                                          {
                                              sojourn_time = (enq_close_t - enqtime) + (deqtime - deq_open_t) + ((n-1) * gate_nonblocking_time);
                                          }
                                          else
                                          {
                                              sojourn_time = (deqtime - deq_open_t) + ((n-1) * gate_nonblocking_time);
                                          }
                                      }
                                      else
                                      {
                                          sojourn_time = deqtime - enqtime;
                                      }
                                  }

                                  outgoing_packet->outgoingtime = deqtime;
                                  outgoing_packet->queueingtime = sojourn_time;
                                  count++;
                                  if(sojourn_time < target || data_queue_p->length < MTU)
                                  {
                                      drop_state = 0;
                                  }
                                  else
                                  {
                                      next_drop_time = control_law(next_drop_time, count, interval);
                                      if(1)
                                      {
                                          if(deq_close_t < next_drop_time)
                                          {
                                              unsigned d1 = deq_close_t - deqtime;
                                              int c = (next_drop_time - d1)/gate_nonblocking_time;
                                              unsigned d2 = (next_drop_time - d1) - gate_nonblocking_time*c;
                                              unsigned d3 = gate_period*(c+1) - gate_nonblocking_time;
                                              next_drop_time = deq_close_t + d2 + d3;
                                          }
                                      }
                                  }
                              }
                          }
                      }
                      else if(sojourn_time >= target && data_queue_p->length >= MTU)
                      {
                          //drop
                          client_state.drop_packet++;
                          free(outgoing_packet->data);
                          free(outgoing_packet);//drop
                          outgoing_packet = 0;
                          drop_state = 1;
                          delta  = count - last_count;
                          count = 1;
                          if((delta > 1) && (deqtime - next_drop_time < 16 * interval))
                              count = delta;
                          next_drop_time = control_law(deqtime, count, interval);
                          /////
                          if(1)
                          {
                              if(deq_close_t < next_drop_time)
                              {
                                  unsigned d1 = deq_close_t - deqtime;
                                  int c = (next_drop_time - d1)/gate_nonblocking_time;
                                  unsigned d2 = (next_drop_time - d1) - gate_nonblocking_time*c;
                                  unsigned d3 = gate_period*(c+1) - gate_nonblocking_time;
                                  next_drop_time = deq_close_t + d2 + d3;
                              }
                          }
                          /////
                          last_count = count;
                      }

                      if(outgoing_packet && outgoing_packet->data && outgoing_packet->length)
                      {
                          client_state.outgoing_total++;
                          totalqueueingtime += (outgoing_packet->queueingtime)/XS1_TIMER_MHZ;
                          averagequeueingtime = totalqueueingtime/client_state.outgoing_total;
                          sojourntime = averagequeueingtime;
                          i_mii.send_packet(outgoing_packet->data, outgoing_packet->length);
                          client_state.timestamp = deqtime;
                          client_state.outgoing_packet = 1;
                      }
                  }
              }
              if(client_state.outgoing_packet == 1)
              {
                  select {
                  case mii_packet_sent(mii_info):
                      client_state.outgoing_packet = 0;
                      free(outgoing_packet->data);
                      free(outgoing_packet);
                    break;
                  }
              }
          }
          else
          {
              if(client_state.outgoing_packet == 1)
              {
                  i_mii.send_packet(txbuf, outgoing_nbytes);
                  client_state.outgoing_packet = 2;
              }

              if(client_state.outgoing_packet == 2)
              {
                  select {
                  case mii_packet_sent(mii_info):
                      client_state.outgoing_packet = 0;
                    break;
                  }
              }

          }

          //get incoming_packet
          if(nofiltering)
          {
              int * unsafe data;
              int nbytes;
              unsigned timestamp;
              {data, nbytes, timestamp} = i_mii.get_incoming_packet();
              if(data)
              {
                  i_tx0.forward_packet((char *)data, nbytes, timestamp);
                  i_tx1.forward_packet((char *)data, nbytes, timestamp);
                  i_mii.release_packet(data);
              }
          }
          else if(!client_state.filtering_packet)
          {
            int * unsafe data;
            int nbytes;
            unsigned timestamp;
            {data, nbytes, timestamp} = i_mii.get_incoming_packet();
            if(data)
            {
                incoming_timestamp = timestamp;
                filtering_nbytes = nbytes;
                filtering_data = data;
                incoming_tcount = 0;
                int *unsafe p_len_type = (int *unsafe) &data[3];
                uint16_t len_type = (uint16_t) NTOH_U16_ALIGNED(p_len_type);
                unsigned header_len = 14;
                if (len_type == 0x8100) {
                  header_len += 4;
                  p_len_type = (int *unsafe) &data[4];
                  len_type = (uint16_t) NTOH_U16_ALIGNED(p_len_type);
                }
                const unsigned rx_data_len = nbytes - header_len;

                if ((len_type < 1536) && (len_type > rx_data_len) || link_status == ETHERNET_LINK_DOWN)
                {
                  // Invalid len_type field, will fall out and free the buffer below
                    i_mii.release_packet(filtering_data);
                    filtering_data = null;
                }
                else {
                    client_state.filtering_packet = 1;
                    i_filter.filtering_reqeust();
                }
            }
          }

        select {
        case queueing_timer when timerafter(time) :> void:
            gate_open ^= 1;
            period = gate_open ? time_gate_open : time_gate_close;
            time += USTIMERCOUNT * period;
          break;
        case mii_incoming_packet(mii_info):
            client_state.total_packet++;
            break;
        case i_filter.get_packet(signal_t &desc, char data[n], unsigned n):
        int t;
        queueing_timer:>t;
        desc.timestamp = t;
        desc.gate = client_state.gate;
        desc.portn = client_state.portn;
        desc.incoming_packet = client_state.incoming_packet;
        desc.drop_packet = client_state.drop_packet;
        desc.total_packet = client_state.total_packet;
        desc.loss_packet = client_state.loss_packet;
        desc.queue_length = data_queue_p->length;
        desc.queueingtime = sojourntime;
        desc.timestamp = client_state.timestamp;
          if (client_state.status_update_state == STATUS_UPDATE_PENDING) {
            desc.type = 0;
            data[0] = link_status;
            data[1] = link_speed;
            client_state.status_update_state = STATUS_UPDATE_WAITING;
          } else if (client_state.filtering_packet) {
            desc.type = 1;
            memcpy(data, filtering_data, n);
          } else {
            desc.type = ETH_NO_DATA;
          }
          break;
        case i_filter.filter_response(char ports):
            if (filtering_data != null)
            {
                if(ports == 2 || ports == 0)
                {
                    i_tx0.forward_packet((char *)filtering_data, filtering_nbytes, incoming_timestamp);
                }
                if(ports == 2 || ports == 1)
                {
                    i_tx1.forward_packet((char *)filtering_data, filtering_nbytes, incoming_timestamp);
                }
                i_mii.release_packet(filtering_data);
                filtering_data = null;
            }
            client_state.filtering_packet = 0;
            break;
          break;

        case i_rx0.forward_packet(char data[n], unsigned n, int request_timestamp):
          if(link_status)
          {
              if(queueing_algorithm)
              {
                  unsigned timestamp;
                  queueing_timer :> timestamp;
                  packet_t *filtered_packet_p;
                  filtered_packet_p = (packet_t *)(malloc(sizeof(packet_t)));
                  filtered_packet_p->data = (char *)malloc(ETHERNET_MAX_PACKET_SIZE);
                  filtered_packet_p->length = n;
                  filtered_packet_p->timestamp = timestamp;
                  memcpy(filtered_packet_p->data, data, n);
                  enqueue(data_queue_p, filtered_packet_p);

              }
              else
              {
                  memcpy(txbuf, data, n);
                  client_state.outgoing_packet = 1;
                  outgoing_nbytes = n;
                  outgoing_timestamp = request_timestamp;
                  outgoing_sourceport = nPort - 1;
              }
          }
          break;
        case i_rx1.forward_packet(char data[n], unsigned n, int request_timestamp):

                if(link_status)
                {
                    if(queueing_algorithm)
                    {
                        unsigned timestamp;
                        queueing_timer :> timestamp;
                        packet_t *filtered_packet_p;
                        filtered_packet_p = (packet_t *)(malloc(sizeof(packet_t)));
                        filtered_packet_p->data = (char *)malloc(ETHERNET_MAX_PACKET_SIZE);
                        filtered_packet_p->length = n;
                        filtered_packet_p->timestamp = timestamp;
                        memcpy(filtered_packet_p->data, data, n);
                        enqueue(data_queue_p, filtered_packet_p);

                    }
                    else
                    {
                        memcpy(txbuf, data, n);
                        client_state.outgoing_packet = 1;
                        outgoing_nbytes = n;
                        outgoing_timestamp = request_timestamp;
                        outgoing_sourceport = nPort - 1;
                    }
                }
          break;
        case i_cfg.get_macaddr(size_t ifnum, uint8_t r_mac_address[MACADDR_NUM_BYTES]):
          memcpy(r_mac_address, mac_address, sizeof mac_address);
          break;
        case i_cfg.set_macaddr(size_t ifnum, uint8_t r_mac_address[MACADDR_NUM_BYTES]):
          memcpy(mac_address, r_mac_address, sizeof r_mac_address);
          break;
        case i_cfg.add_macaddr_filter(size_t client_num, int is_hp,
                                             ethernet_macaddr_filter_t entry) ->
                                               ethernet_macaddr_filter_result_t result:
          break;

        case i_cfg.del_macaddr_filter(size_t client_num, int is_hp,
                                             ethernet_macaddr_filter_t entry):
          break;

        case i_cfg.del_all_macaddr_filters(size_t client_num, int is_hp):
          break;

        case i_cfg.add_ethertype_filter(size_t client_num, uint16_t ethertype):
          break;

        case i_cfg.del_ethertype_filter(size_t client_num, uint16_t ethertype):
          break;

        case i_cfg.get_tile_id_and_timer_value(unsigned &tile_id, unsigned &time_on_tile): {
          fail("Outgoing timestamps are not supported in standard MII Ethernet MAC");
          break;
        }
        case i_cfg.set_egress_qav_idle_slope(size_t ifnum, unsigned slope):
          fail("Shaper not supported in standard MII Ethernet MAC");
          break;

        case i_cfg.set_ingress_timestamp_latency(size_t ifnum, ethernet_speed_t speed, unsigned value): {
          fail("Timestamp correction not supported in standard MII Ethernet MAC");
          break;
        }
        case i_cfg.set_egress_timestamp_latency(size_t ifnum, ethernet_speed_t speed, unsigned value): {
          fail("Timestamp correction not supported in standard MII Ethernet MAC");
          break;
        }
        case i_cfg.enable_strip_vlan_tag(size_t client_num):
          fail("VLAN tag stripping not supported in standard MII Ethernet MAC");
          break;
        case i_cfg.disable_strip_vlan_tag(size_t client_num):
          fail("VLAN tag stripping not supported in standard MII Ethernet MAC");
          break;
        case i_cfg.enable_link_status_notification(size_t client_num):
          client_state.status_update_state = STATUS_UPDATE_WAITING;
          break;

        case i_cfg.disable_link_status_notification(size_t client_num):
          client_state.status_update_state = STATUS_UPDATE_IGNORING;
          break;

        case i_cfg.set_link_state(int ifnum, ethernet_link_state_t status, ethernet_speed_t speed):
          if (link_status != status) {
            link_status = status;
            link_speed = speed;
            if (client_state.status_update_state == STATUS_UPDATE_WAITING) {
              client_state.status_update_state = STATUS_UPDATE_PENDING;
              i_filter.filtering_reqeust();
            }
          }
          break;
        }
      }
    }
  }
