/*
 * queue.xc
 *
 *  Created on: 2018. 9. 19.
 *      Author: 22wow
 */

#include <string.h>
#include "queue.h"

queue_t *init_queue(int max)
{
    packet_t *head;
    packet_t *tail;
    queue_t *newqueue;

    newqueue = (queue_t *)(malloc(sizeof(queue_t)));
    head = (packet_t *)(malloc(sizeof(packet_t)));
    tail = (packet_t *)(malloc(sizeof(packet_t)));

    newqueue->head = head;
    newqueue->tail = tail;

    newqueue->head->length = 0;
    newqueue->head->data = NULL;
    newqueue->head->next = tail;

    newqueue->tail->length = 0;
    newqueue->tail->data = NULL;
    newqueue->tail->next = tail;
    newqueue->last = head;
    newqueue->length = 0;
    newqueue->max = max;

    return newqueue;
}

void enqueue(queue_t *q, packet_t *d)
{
    packet_t *t;
    if(q->length < q->max)
    {
        t = q->last;
        t->next = d;
        d->next = q->tail;
        q->last = d;
        q->length++;
    }
    else
    {
        printf("queue overflow\n");
    }
}

packet_t *dequeue(queue_t *q)
{
    packet_t *res = NULL;
    packet_t *t;
    t = q->head;
    if(q->length > 0)
    {
        res = t->next;
        t->next = res->next;
        q->length--;
        if(q->length == 0)
            q->last = q->head;

    }
    return res;
}
