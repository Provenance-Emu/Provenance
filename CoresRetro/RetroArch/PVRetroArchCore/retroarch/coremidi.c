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

#define CORE_MIDI_QUEUE_SIZE 1024

typedef struct {
    midi_event_t events[CORE_MIDI_QUEUE_SIZE]; ///< Event buffer
    int read_index;         ///< Current read position
    int write_index;        ///< Current write position
} coremidi_queue_t;

typedef struct
{
    // CoreMIDI objects
    MIDIClientRef client;
    MIDIPortRef input_port;
    MIDIPortRef output_port;
    MIDIEndpointRef input_endpoint;
    MIDIEndpointRef output_endpoint;

    // Lists of available devices
    struct string_list *input_list;
    struct string_list *output_list;

    // Queue for incoming MIDI events
    coremidi_queue_t input_queue; ///< Queue for incoming MIDI events
    CFRunLoopRef runLoop; ///< Dedicated run loop for CoreMIDI
    dispatch_queue_t runLoopQueue; ///< GCD queue for run loop
} coremidi_t;

static dispatch_queue_t coremidi_queue = NULL; ///< Shared dispatch queue for all CoreMIDI operations
static CFRunLoopRef coremidi_runLoop = NULL; ///< Shared run loop for CoreMIDI

static void midi_notification(const MIDINotification *message, void *refCon)
{
    coremidi_t *d = (coremidi_t*)refCon;

    switch (message->messageID)
    {
        case kMIDIMsgObjectAdded:
            if (message->messageSize >= sizeof(MIDIObjectAddRemoveNotification))
            {
                const MIDIObjectAddRemoveNotification *note = (const MIDIObjectAddRemoveNotification *)message;
                if (note->childType == kMIDIObjectType_Source)
                {
                    RARCH_LOG("[MIDI]: New input device added\n");
                    // You might want to update the available inputs list here
                }
                else if (note->childType == kMIDIObjectType_Destination)
                {
                    RARCH_LOG("[MIDI]: New output device added\n");
                    // You might want to update the available outputs list here
                }
            }
            break;

        case kMIDIMsgObjectRemoved:
            if (message->messageSize >= sizeof(MIDIObjectAddRemoveNotification))
            {
                const MIDIObjectAddRemoveNotification *note = (const MIDIObjectAddRemoveNotification *)message;
                if (note->childType == kMIDIObjectType_Source)
                {
                    RARCH_LOG("[MIDI]: Input device removed\n");
                    // Handle input device removal
                    if (d->input_endpoint == note->child)
                    {
                        MIDIPortDisconnectSource(d->input_port, d->input_endpoint);
                        d->input_endpoint = 0;
                    }
                }
                else if (note->childType == kMIDIObjectType_Destination)
                {
                    RARCH_LOG("[MIDI]: Output device removed\n");
                    // Handle output device removal
                    if (d->output_endpoint == note->child)
                    {
                        d->output_endpoint = 0;
                    }
                }
            }
            break;

        default:
            break;
    }
}

static void coremidi_init_queue(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Create the shared queue
        coremidi_queue = dispatch_queue_create("com.provenance.coremidi", DISPATCH_QUEUE_SERIAL);

        // Create and start the run loop
        dispatch_async(coremidi_queue, ^{
            coremidi_runLoop = CFRunLoopGetCurrent();
            CFRunLoopRun();
        });

        // Wait for the run loop to be ready
        int attempts = 0;
        while (!coremidi_runLoop && attempts < 100) {
            usleep(1000); // 1ms delay
            attempts++;
        }
        if (!coremidi_runLoop) {
            RARCH_ERR("[MIDI]: Failed to initialize run loop\n");
        }
    });
}

// Set input device
static bool coremidi_set_input(void *p, const char *input);

// Set output device
static bool coremidi_set_output(void *p, const char *output);

// Initialize the queue
static void coremidi_queue_init(coremidi_queue_t *q)
{
    q->read_index = 0;
    q->write_index = 0;
}

// Write to the queue
static bool coremidi_queue_write(coremidi_queue_t *q, const midi_event_t *ev)
{
    int next_write = (q->write_index + 1) % CORE_MIDI_QUEUE_SIZE;

    if (next_write == q->read_index) // Queue full
        return false;

    memcpy(&q->events[q->write_index], ev, sizeof(*ev));
    q->write_index = next_write;
    return true;
}

// Read from the queue
static bool coremidi_queue_read(coremidi_queue_t *q, midi_event_t *ev)
{
    if (q->read_index == q->write_index) // Queue empty
        return false;

    memcpy(ev, &q->events[q->read_index], sizeof(*ev));
    q->read_index = (q->read_index + 1) % CORE_MIDI_QUEUE_SIZE;
    return true;
}

// MIDI input callback
static void coremidi_input_callback(const MIDIPacketList *pktlist, void *read_proc_ref, void *src_conn_ref)
{
    coremidi_t *d = (coremidi_t*)read_proc_ref;
    const MIDIPacket *packet = &pktlist->packet[0];
    midi_event_t event;
    uint32_t i;

    (void)src_conn_ref; // Unused parameter

    for (i = 0; i < pktlist->numPackets; i++)
    {
        // Process each MIDI message in the packet
        const uint8_t *data = packet->data;
        size_t length = packet->length;
        const MIDITimeStamp timestamp = packet->timeStamp;

        while (length > 0)
        {
            // Determine message size based on status byte
            size_t msg_size = midi_driver_get_event_size(data[0]);
            if (msg_size == 0 || msg_size > length)
                break;

            // Create event
            event.data = (uint8_t*)data; // Cast to uint8_t*
            event.data_size = msg_size;
            event.delta_time = (uint32_t)timestamp;

            // Add to queue
            if (!coremidi_queue_write(&d->input_queue, &event))
            {
                RARCH_WARN("[MIDI]: Input queue overflow, dropping event.\n");
                break;
            }

            // Advance to next message
            data += msg_size;
            length -= msg_size;
        }

        packet = MIDIPacketNext(packet);
    }
}

// Get the number of MIDI input devices
static ItemCount safe_MIDIGetNumberOfSources(void)
{
    __block ItemCount count = 0;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    dispatch_async(coremidi_queue, ^{
        count = MIDIGetNumberOfSources();
        dispatch_semaphore_signal(sema);
    });

    // Timeout after 1 second
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC)) != 0) {
        RARCH_WARN("[MIDI]: Timeout getting number of sources\n");
        return 0;
    }

    return count;
}

// Get available MIDI input devices
static bool coremidi_get_avail_inputs(struct string_list *inputs)
{
    __block ItemCount count = 0;
    union string_list_elem_attr attr = {0};
    CFStringRef name = NULL;
    char buf[256];
    __block OSStatus err = noErr;
    int i;

    if (!inputs)
    {
        RARCH_WARN("[MIDI]: Invalid inputs list in coremidi_get_avail_inputs\n");
        return false;
    }

    // Initialize the shared queue if not already done
    coremidi_init_queue();

    count = safe_MIDIGetNumberOfSources();
    if (count == 0)
    {
        RARCH_LOG("[MIDI]: No MIDI input sources found\n");
        return true; // Not an error, just no devices
    }

    for (i = 0; i < count; i++)
    {
        __block MIDIEndpointRef endpoint = 0;

        dispatch_sync(coremidi_queue, ^{
            endpoint = MIDIGetSource(i);
        });

        if (!endpoint)
        {
            RARCH_WARN("[MIDI]: Failed to get source endpoint %d\n", i);
            continue;
        }

        dispatch_sync(coremidi_queue, ^{
            err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name);
        });

        if (err != noErr || !name)
        {
            RARCH_WARN("[MIDI]: Failed to get display name for source %d: %d\n", i, err);
            continue;
        }

        if (!CFStringGetCString(name, buf, sizeof(buf), kCFStringEncodingUTF8))
        {
            RARCH_WARN("[MIDI]: Failed to convert CFString for source %d\n", i);
            CFRelease(name);
            continue;
        }

        if (!string_list_append(inputs, buf, attr))
        {
            RARCH_ERR("[MIDI]: Failed to append input device to list: %s\n", buf);
            CFRelease(name);
            return false;
        }

        CFRelease(name);
    }

    return true;
}

static ItemCount safe_MIDIGetNumberOfDestinations(void)
{
    __block ItemCount count = 0;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    dispatch_async(coremidi_queue, ^{
        count = MIDIGetNumberOfDestinations();
        dispatch_semaphore_signal(sema);
    });

    // Timeout after 1 second
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC)) != 0) {
        RARCH_WARN("[MIDI]: Timeout getting number of destinations\n");
        return 0;
    }

    return count;
}

static bool coremidi_get_avail_outputs(struct string_list *outputs)
{
    __block ItemCount count = 0;
    union string_list_elem_attr attr = {0};
    CFStringRef name = NULL;
    char buf[256];
    __block OSStatus err = noErr;
    int i;

    if (!outputs)
    {
        RARCH_WARN("[MIDI]: Invalid outputs list in coremidi_get_avail_outputs\n");
        return false;
    }

    // Initialize the shared queue if not already done
    coremidi_init_queue();

    count = safe_MIDIGetNumberOfDestinations();
    if (count == 0)
    {
        RARCH_LOG("[MIDI]: No MIDI output destinations found\n");
        return true; // Not an error, just no devices
    }

    for (i = 0; i < count; i++)
    {
        __block MIDIEndpointRef endpoint = 0;

        dispatch_sync(coremidi_queue, ^{
            endpoint = MIDIGetDestination(i);
        });

        if (!endpoint)
        {
            RARCH_WARN("[MIDI]: Failed to get destination endpoint %d\n", i);
            continue;
        }

        dispatch_sync(coremidi_queue, ^{
            err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name);
        });

        if (err != noErr || !name)
        {
            RARCH_WARN("[MIDI]: Failed to get display name for destination %d: %d\n", i, err);
            continue;
        }

        if (!CFStringGetCString(name, buf, sizeof(buf), kCFStringEncodingUTF8))
        {
            RARCH_WARN("[MIDI]: Failed to convert CFString for destination %d\n", i);
            CFRelease(name);
            continue;
        }

        if (!string_list_append(outputs, buf, attr))
        {
            RARCH_ERR("[MIDI]: Failed to append output device to list: %s\n", buf);
            CFRelease(name);
            return false;
        }

        CFRelease(name);
    }

    return true;
}

static void *coremidi_init(const char *input, const char *output)
{
    coremidi_t *d = (coremidi_t*)calloc(1, sizeof(*d));
    __block OSStatus err;
    __block bool init_success = false;

    if (!d)
    {
        RARCH_ERR("[MIDI]: Out of memory.\n");
        return NULL;
    }

    // Initialize the shared queue and run loop
    coremidi_init_queue();
    if (!coremidi_runLoop) {
        RARCH_ERR("[MIDI]: Failed to initialize run loop\n");
        free(d);
        return NULL;
    }

    // Ensure the run loop is running
    if (!CFRunLoopIsWaiting(coremidi_runLoop)) {
        RARCH_ERR("[MIDI]: Run loop is not running\n");
        free(d);
        return NULL;
    }

    // Initialize the input queue
    coremidi_queue_init(&d->input_queue);

    // Create MIDI client with timeout protection
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    dispatch_async(coremidi_queue, ^{
        err = MIDIClientCreate(CFSTR("RetroArch MIDI Client"), midi_notification, d, &d->client);
        if (err == noErr) {
            init_success = true;
        }
        dispatch_semaphore_signal(sema);
    });

    // Timeout after 1 second
    if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC)) != 0) {
        RARCH_ERR("[MIDI]: Timeout during MIDIClientCreate\n");
        free(d);
        return NULL;
    }

    if (!init_success) {
        RARCH_ERR("[MIDI]: MIDIClientCreate failed: %d\n", err);
        free(d);
        return NULL;
    }

    // Create input port if specified
    if (input)
    {
        dispatch_async(coremidi_queue, ^{
            err = MIDIInputPortCreate(d->client, CFSTR("Input Port"), coremidi_input_callback, d, &d->input_port);
            dispatch_semaphore_signal(sema);
        });

        // Timeout after 1 second
        if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC)) != 0) {
            RARCH_ERR("[MIDI]: Timeout during MIDIInputPortCreate\n");
            goto error;
        }

        if (err != noErr)
        {
            RARCH_ERR("[MIDI]: MIDIInputPortCreate failed: %d\n", err);
            goto error;
        }

        // Connect to the specified input endpoint
        if (!coremidi_set_input(d, input))
        {
            RARCH_ERR("[MIDI]: Failed to connect to input device: %s\n", input);
            goto error;
        }
    }

    // Create output port if specified
    if (output)
    {
        dispatch_async(coremidi_queue, ^{
            err = MIDIOutputPortCreate(d->client, CFSTR("Output Port"), &d->output_port);
            dispatch_semaphore_signal(sema);
        });

        // Timeout after 1 second
        if (dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC)) != 0) {
            RARCH_ERR("[MIDI]: Timeout during MIDIOutputPortCreate\n");
            goto error;
        }

        if (err != noErr)
        {
            RARCH_ERR("[MIDI]: MIDIOutputPortCreate failed: %d\n", err);
            goto error;
        }

        // Connect to the specified output endpoint
        if (!coremidi_set_output(d, output))
        {
            RARCH_ERR("[MIDI]: Failed to connect to output device: %s\n", output);
            goto error;
        }
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

    // Clean up MIDI resources on the shared queue
    dispatch_sync(coremidi_queue, ^{
        if (d->input_port)
            MIDIPortDispose(d->input_port);

        if (d->output_port)
            MIDIPortDispose(d->output_port);

        if (d->client)
            MIDIClientDispose(d->client);

        // Stop the run loop
        if (coremidi_runLoop) {
            CFRunLoopStop(coremidi_runLoop);
            coremidi_runLoop = NULL;
        }
    });

    free(d);
}

static bool coremidi_set_input(void *p, const char *input)
{
    coremidi_t *d = (coremidi_t*)p;
    __block OSStatus err = noErr;
    __block bool result = false;

    if (!d || !d->input_port)
        return false;

    dispatch_sync(d->runLoopQueue, ^{
        // Disconnect current input endpoint if connected
        if (d->input_endpoint)
        {
            err = MIDIPortDisconnectSource(d->input_port, d->input_endpoint);
            if (err != noErr)
            {
                RARCH_WARN("[MIDI]: Failed to disconnect input endpoint: %d\n", err);
            }
            d->input_endpoint = 0;
        }

        // If input is NULL or "Off", just return success
        if (!input || string_is_equal(input, "Off"))
        {
            result = true;
            return;
        }

        // Find the input endpoint by name
        ItemCount count = MIDIGetNumberOfSources();
        for (ItemCount i = 0; i < count; i++)
        {
            MIDIEndpointRef endpoint = MIDIGetSource(i);
            CFStringRef name;
            char buf[256];

            err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, (CFStringRef *)&name);
            if (err == noErr)
            {
                CFStringGetCString(name, buf, sizeof(buf), kCFStringEncodingUTF8);
                CFRelease(name);

                if (string_is_equal(input, buf))
                {
                    err = MIDIPortConnectSource(d->input_port, endpoint, NULL);
                    if (err == noErr)
                    {
                        d->input_endpoint = endpoint;
                        result = true;
                        return;
                    }
                    RARCH_WARN("[MIDI]: Failed to connect input endpoint: %d\n", err);
                    result = false;
                    return;
                }
            }
        }

        RARCH_WARN("[MIDI]: Input device not found: %s\n", input);
        result = false;
    });

    if (err == kMIDIInvalidClient) {
        RARCH_ERR("[MIDI]: Invalid MIDI client\n");
    } else if (err == kMIDIInvalidPort) {
        RARCH_ERR("[MIDI]: Invalid MIDI port\n");
    }

    return result;
}

static bool coremidi_set_output(void *p, const char *output)
{
    coremidi_t *d = (coremidi_t*)p;
    __block bool result = false;

    if (!d)
        return false;

    dispatch_sync(d->runLoopQueue, ^{
        // If output is NULL or "Off", just return success
        if (!output || string_is_equal(output, "Off"))
        {
            d->output_endpoint = 0;
            result = true;
            return;
        }

        // Find the output endpoint by name
        ItemCount count = MIDIGetNumberOfDestinations();
        for (ItemCount i = 0; i < count; i++)
        {
            MIDIEndpointRef endpoint = MIDIGetDestination(i);
            CFStringRef name;
            char buf[256];
            OSStatus err;

            err = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &name);
            if (err == noErr)
            {
                CFStringGetCString(name, buf, sizeof(buf), kCFStringEncodingUTF8);
                CFRelease(name);

                if (string_is_equal(output, buf))
                {
                    d->output_endpoint = endpoint;
                    result = true;
                    return;
                }
            }
        }

        RARCH_WARN("[MIDI]: Output device not found: %s\n", output);
        result = false;
    });

    return result;
}

static bool coremidi_read(void *p, midi_event_t *event)
{
    coremidi_t *d = (coremidi_t*)p;
    midi_event_t ev;

    if (!d || !event)
    {
        RARCH_WARN("[MIDI]: Invalid parameters in coremidi_read\n");
        return false;
    }

    if (!coremidi_queue_read(&d->input_queue, &ev))
    {
#ifdef DEBUG
        RARCH_LOG("[MIDI]: No data available in input queue\n");
#endif
        return false;
    }

    // Ensure the event data size is valid
    if (ev.data_size > sizeof(event->data))
    {
        RARCH_WARN("[MIDI]: Event data size too large: %zu\n", ev.data_size);
        return false;
    }

    memcpy(event->data, ev.data, ev.data_size);
    event->data_size = ev.data_size;
    event->delta_time = ev.delta_time;

    return true;
}

static bool coremidi_write(void *p, const midi_event_t *event)
{
    coremidi_t *d = (coremidi_t*)p;
    __block bool result = false;

    if (!d || !event)
    {
        RARCH_WARN("[MIDI]: Invalid parameters in coremidi_write\n");
        return false;
    }

    dispatch_sync(d->runLoopQueue, ^{
        if (!d->output_port || !d->output_endpoint)
        {
            RARCH_WARN("[MIDI]: Output not configured\n");
            result = false;
            return;
        }

        // Validate event data size
        if (event->data_size == 0 || event->data_size > 65535)
        {
            RARCH_WARN("[MIDI]: Invalid event data size: %zu\n", event->data_size);
            result = false;
            return;
        }

        MIDIPacketList packetList;
        MIDIPacket *packet = MIDIPacketListInit(&packetList);
        packet = MIDIPacketListAdd(&packetList, sizeof(packetList), packet,
            event->delta_time, event->data_size, event->data);

        if (!packet)
        {
            RARCH_WARN("[MIDI]: Failed to create MIDI packet\n");
            result = false;
            return;
        }

        OSStatus err = MIDISend(d->output_port, d->output_endpoint, &packetList);
        if (err != noErr)
        {
            RARCH_WARN("[MIDI]: MIDISend failed with error: %d\n", err);
            result = false;
            return;
        }

        result = true;
    });

    return result;
}

static bool coremidi_flush(void *p)
{
    coremidi_t *d = (coremidi_t*)p;
    __block bool result = false;

    if (!d || !d->output_port)
        return false;

    dispatch_sync(d->runLoopQueue, ^{
        OSStatus err = MIDIFlushOutput(d->output_endpoint);
        if (err != noErr)
        {
            RARCH_WARN("[MIDI]: MIDIFlushOutput failed with error: %d\n", err);
            result = false;
            return;
        }
        result = true;
    });

    return result;
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
