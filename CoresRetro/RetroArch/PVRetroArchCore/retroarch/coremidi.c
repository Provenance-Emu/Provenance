//
//  coremidi.c
//  PVRetroArch
//
//  Created by Joseph Mattiello on 2/14/25.
//  Copyright © 2025 Provenance Emu. All rights reserved.
//

#include <CoreMIDI/CoreMIDI.h>
#include <libretro.h>
#include <lists/string_list.h>
#include <string/stdstring.h>
#include "../midi_driver.h"
#include "../../verbosity.h"

typedef struct
{
    MIDIClientRef client;
    MIDIPortRef input_port;
    MIDIPortRef output_port;
    MIDIEndpointRef input_endpoint;
    MIDIEndpointRef output_endpoint;
    struct string_list *input_list;
    struct string_list *output_list;
} coremidi_t;

static void coremidi_input_callback(const MIDIPacketList *pktlist, void *read_proc_ref, void *src_conn_ref)
{
    coremidi_t *d = (coremidi_t*)read_proc_ref;
    const MIDIPacket *packet = &pktlist->packet[0];
    midi_event_t event;
    uint32_t i;

    for (i = 0; i < pktlist->numPackets; i++)
    {
        event.data = (uint8_t*)packet->data;
        event.data_size = packet->length;
        event.delta_time = packet->timeStamp;

        // Process the MIDI event here
        // You can add it to a queue similar to winmm_midi.c if needed

        packet = MIDIPacketNext(packet);
    }
}

static bool coremidi_get_avail_inputs(struct string_list *inputs)
{
    ItemCount count = MIDIGetNumberOfSources();
    union string_list_elem_attr attr = {0};
    CFStringRef name;
    char buf[256];
    OSStatus err;
    int i;

    for (i = 0; i < count; i++)
    {
        MIDIEndpointRef endpoint = MIDIGetSource(i);
        err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name);
        if (err == noErr)
        {
            CFStringGetCString(name, buf, sizeof(buf), kCFStringEncodingUTF8);
            CFRelease(name);
            if (!string_list_append(inputs, buf, attr))
                return false;
        }
    }

    return true;
}

static bool coremidi_get_avail_outputs(struct string_list *outputs)
{
    ItemCount count = MIDIGetNumberOfDestinations();
    union string_list_elem_attr attr = {0};
    CFStringRef name;
    char buf[256];
    OSStatus err;
    int i;

    for (i = 0; i < count; i++)
    {
        MIDIEndpointRef endpoint = MIDIGetDestination(i);
        err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name);
        if (err == noErr)
        {
            CFStringGetCString(name, buf, sizeof(buf), kCFStringEncodingUTF8);
            CFRelease(name);
            if (!string_list_append(outputs, buf, attr))
                return false;
        }
    }

    return true;
}

static void *coremidi_init(const char *input, const char *output)
{
    coremidi_t *d = (coremidi_t*)calloc(1, sizeof(*d));
    OSStatus err;

    if (!d)
    {
        RARCH_ERR("[MIDI]: Out of memory.\n");
        return NULL;
    }

    err = MIDIClientCreate(CFSTR("RetroArch MIDI Client"), NULL, NULL, &d->client);
    if (err != noErr)
    {
        RARCH_ERR("[MIDI]: MIDIClientCreate failed: %d\n", err);
        goto error;
    }

    if (input)
    {
        err = MIDIInputPortCreate(d->client, CFSTR("Input Port"), coremidi_input_callback, d, &d->input_port);
        if (err != noErr)
        {
            RARCH_ERR("[MIDI]: MIDIInputPortCreate failed: %d\n", err);
            goto error;
        }

        // Connect to the specified input endpoint
        // You'll need to implement this based on the input name
    }

    if (output)
    {
        err = MIDIOutputPortCreate(d->client, CFSTR("Output Port"), &d->output_port);
        if (err != noErr)
        {
            RARCH_ERR("[MIDI]: MIDIOutputPortCreate failed: %d\n", err);
            goto error;
        }

        // Connect to the specified output endpoint
        // You'll need to implement this based on the output name
    }

    return d;

error:
    if (d->client)
        MIDIClientDispose(d->client);
    free(d);
    return NULL;
}

static void coremidi_free(void *p)
{
    coremidi_t *d = (coremidi_t*)p;

    if (!d)
        return;

    if (d->input_port)
        MIDIPortDispose(d->input_port);

    if (d->output_port)
        MIDIPortDispose(d->output_port);

    if (d->client)
        MIDIClientDispose(d->client);

    free(d);
}

static bool coremidi_set_input(void *p, const char *input)
{
    coremidi_t *d = (coremidi_t*)p;
    // Implement input switching logic here
    return true;
}

static bool coremidi_set_output(void *p, const char *output)
{
    coremidi_t *d = (coremidi_t*)p;
    // Implement output switching logic here
    return true;
}

static bool coremidi_read(void *p, midi_event_t *event)
{
    coremidi_t *d = (coremidi_t*)p;
    // Implement MIDI event reading logic here
    return false;
}

static bool coremidi_write(void *p, const midi_event_t *event)
{
    coremidi_t *d = (coremidi_t*)p;
    MIDIPacketList packetList;
    MIDIPacket *packet = MIDIPacketListInit(&packetList);

    packet = MIDIPacketListAdd(&packetList, sizeof(packetList), packet, 
        event->delta_time, event->data_size, event->data);

    if (packet)
    {
        OSStatus err = MIDISend(d->output_port, d->output_endpoint, &packetList);
        return err == noErr;
    }

    return false;
}

static bool coremidi_flush(void *p)
{
    coremidi_t *d = (coremidi_t*)p;
    // Implement flush logic if needed
    return true;
}

midi_driver_t midi_coremidi = {
    "coremidi",
    coremidi_get_avail_inputs,
    coremidi_get_avail_outputs,
    coremidi_init,
    coremidi_free,
    coremidi_set_input,
    coremidi_set_output,
    coremidi_read,
    coremidi_write,
    coremidi_flush
};
