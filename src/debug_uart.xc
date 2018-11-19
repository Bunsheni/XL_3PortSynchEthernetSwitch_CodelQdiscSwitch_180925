/*
 * debug_uart.xc
 *
 *  Created on: 2018. 9. 25.
 *      Author: 22wow
 */
#include "debug_uart.h"

port p_uart_rx = on tile[1]: XS1_PORT_1E;
port p_uart_tx = on tile[1]: XS1_PORT_1F;
#define RX_BUFFER_SIZE 20

int uart_printf(client uart_tx_if uart_tx, char *str)
{
    int i = 0;
    while(str[i] != '\0')
    {
        uart_tx.write(str[i]);
        delay_microsecond(10);
        i++;
    }
    return i;
}

int uart_clear_printf(client uart_tx_if uart_tx, char *str, int lastlength)
{
    int i = 0;
    uart_tx.write('\r');
    while(i < lastlength)
    {
        uart_tx.write(' ');
        delay_microsecond(10);
        i++;
    }
    uart_tx.write('\r');

    return uart_printf(uart_tx, str);
}


void codel_debug(
        client uart_rx_if i_rx, client uart_tx_if i_tx,
        server debug_if i_debug[n], unsigned char n)
{
    unsafe
    {
        char buffer[1000];
        char stream[1000];
        char flag, tx_flag;
        int index = 0;
        int lastlength = 0;
        control_info_t control_info;
        signal_t queue_info;
        debug_mode_e debug_mode = NOTHING;
        debug_portn_e debug_portn = NOSELECT;

        printf("\nHello World!\n");
        while(1)
        {
            if(debug_mode == QUEUE)
            {
                if(debug_portn == NOSELECT && tx_flag)
                {
                    uart_printf(i_tx, "select port number: ");
                    tx_flag = 0;
                }
                else if(debug_portn != NOSELECT && flag)
                {
                    sprintf(stream, "Port%u- Length: %u, Drop: %u, Loss: %u, Total: %u, Queueing time:%d\r\n", queue_info.portn,queue_info.queue_length,queue_info.drop_packet,queue_info.loss_packet,queue_info.total_packet,queue_info.queueingtime);
                    lastlength = uart_clear_printf(i_tx, stream, lastlength);
                    flag = 0;
                }
            }
            else if(debug_mode == PHYSMI)
            {
                int i;
                sprintf(stream, "PHYADD: 0x%.4x\n\r", control_info.phy_address);
                lastlength = uart_printf(i_tx, stream);
                for(i = 0;i < 32;i++)
                {
                    sprintf(stream, "reg%d: 0x%.4x\n\r",i,control_info.value[i]);
                    lastlength = uart_printf(i_tx, stream);
                }
                flag = 0;
                debug_mode = NOTHING;
            }
            else if(debug_mode == SELECTPORT && tx_flag)
            {
                uart_printf(i_tx, "select port number: ");
                tx_flag = 0;
            }
            select
            {
                case i_rx.data_ready():

                    uint8_t data = i_rx.read();
                    printf("%d\n", data);
                    if(data == 13)
                    {
                        i_tx.write('\n');
                        i_tx.write('\r');
                        printf("debugmode: %d\n", debug_mode);
                        if(debug_mode == NOTHING)
                        {
                            if(buffer[0] == '1' && index == 1)
                            {
                                debug_mode = QUEUE;
                                debug_portn = NOSELECT;
                                tx_flag = 1;
                            }
                            else if(buffer[0] == '2' && index == 1)
                            {
                                debug_mode = FILTER;
                            }
                            else if(buffer[0] == '3' && index == 1)
                            {
                                debug_mode = PHYSMI;
                                control_info.type = READ_REGISTER;
                                control_info.reg_address = -1;
                                i_debug[0].request_control();
                            }
                            else if(buffer[0] == '4' && index == 1)
                            {
                                debug_mode = SELECTPORT;
                                tx_flag = 1;
                            }
                            else
                            {
                                printf("wrong input\n");
                            }
                        }
                        else if(debug_mode == QUEUE && debug_portn == NOSELECT)
                        {
                            if(buffer[0] == '0' && index == 1)
                            {
                                debug_portn = PORT0;
                                control_info.type = SELECTPORT;
                                control_info.portn = 0;
                                i_debug[0].request_control();
                            }
                            else if(buffer[0] == '1' && index == 1)
                            {
                                debug_portn = PORT1;
                                control_info.type = SELECTPORT;
                                control_info.portn = 1;
                                i_debug[0].request_control();
                            }
                            else if(buffer[0] == '2' && index == 1)
                            {
                                debug_portn = PORT2;
                                control_info.type = SELECTPORT;
                                control_info.portn = 2;
                                i_debug[0].request_control();
                            }
                            else
                            {
                                tx_flag = 1;
                            }
                        }
                        else if(debug_mode == SELECTPORT)
                        {
                            if(buffer[0] == '0' && index == 1)
                            {
                                debug_portn = PORT0;
                                control_info.type = SELECT_PORT;
                                control_info.portn = 0;
                                i_debug[0].request_control();
                                debug_mode = NOTHING;
                            }
                            else if(buffer[0] == '1' && index == 1)
                            {
                                debug_portn = PORT1;
                                control_info.type = SELECT_PORT;
                                control_info.portn = 1;
                                i_debug[0].request_control();
                                debug_mode = NOTHING;
                            }
                            else if(buffer[0] == '2' && index == 1)
                            {
                                debug_portn = PORT2;
                                control_info.type = SELECT_PORT;
                                control_info.portn = 2;
                                i_debug[0].request_control();
                                debug_mode = NOTHING;
                            }
                            else
                            {
                                tx_flag = 1;
                            }
                        }
                        else
                        {
                            printf("nothing\n");
                        }
                        index = 0;
                    }
                    else if(data == 27)
                    {
                        uart_printf(i_tx, "\n\r1: queue debug, 2: filter debug, 3: phy debug\n\r");
                        debug_mode = 0;
                        debug_portn = -1;
                        index = 0;
                    }
                    else if(data == 8)
                    {
                        i_tx.write(data);
                        index--;
                    }
                    else
                    {
                        i_tx.write(data);
                        buffer[index] = data;
                        index++;
                    }



                    break;
                case i_debug[int n].get_control(control_info_t &desc):
                        memcpy(&desc, &control_info, sizeof(control_info));
                        break;
                case i_debug[int n].send_queue_status(signal_t &desc):
                        memcpy(&queue_info, &desc, sizeof(queue_info));
                        flag = 1;
                    break;
                case i_debug[int n].send_smi_data(control_info_t &desc):
                        memcpy(&control_info, &desc, sizeof(control_info));
                        flag = 1;
                break;
                case i_debug[int n].printf(char *unsafe a):
                        int i = 0;
                        while(a[i] != '\0')
                        {
                            i++;
                        }
                        i++;
                        char *b = (char *)(malloc(i));
                        memcpy(b, a, i);
                        lastlength = uart_printf(i_tx, b);
                    free(b);
                break;
            }
        }
    }
}

int debug_uart(server debug_if i_debug[n], unsigned char n)
{
    uart_rx_if i_uart_rx;
    uart_tx_if i_uart_tx;
    input_gpio_if i_gpio_rx[1];
    output_gpio_if i_gpio_tx[1];

    par
    {
        codel_debug(i_uart_rx, i_uart_tx, i_debug, n);
        output_gpio(i_gpio_tx, 1, p_uart_tx, null);
        uart_tx(i_uart_tx, null, 115200, UART_PARITY_NONE, 8, 1, i_gpio_tx[0]);
        input_gpio_with_events(i_gpio_rx, 1, p_uart_rx, null);
        uart_rx(i_uart_rx, null, RX_BUFFER_SIZE, 115200, UART_PARITY_NONE, 8, 1, i_gpio_rx[0]);
    }
    return 0;

}



