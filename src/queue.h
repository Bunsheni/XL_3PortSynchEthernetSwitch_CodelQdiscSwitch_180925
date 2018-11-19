/*
 * queue.h
 *
 *  Created on: 2018. 9. 19.
 *      Author: 22wow
 */


#ifndef QUEUE_H_
#define QUEUE_H_

#ifdef __XC__
extern "C" {
#endif


typedef struct packet_t{
    char *data;
    unsigned length;
    unsigned timestamp;
    unsigned queueingtime;
    unsigned outgoingtime;
    struct packet_t *next;
}packet_t;

typedef struct queue_t{
    packet_t *head;
    packet_t *tail;
    packet_t *last;
    unsigned length;
    unsigned max;
    unsigned dropcount;
    unsigned totalcount;
} queue_t;

queue_t *init_queue(int max);
void enqueue(queue_t *q, packet_t *d);
packet_t *dequeue(queue_t *q);

#ifdef __XC__
} // extern "C"
#endif

#endif /* QUEUE_H_ */
