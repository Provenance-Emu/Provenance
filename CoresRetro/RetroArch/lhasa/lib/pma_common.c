/*

Copyright (c) 2011, 2012, Simon Howard

Permission to use, copy, modify, and/or distribute this software
for any purpose with or without fee is hereby granted, provided
that the above copyright notice and this permission notice appear
in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL
WARRANTIES WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY SPECIAL, DIRECT, INDIRECT, OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM
LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

 */

//
// Common functions used by PMarc decoders.
//

typedef struct {
	unsigned int offset;
	unsigned int bits;
} VariableLengthTable;

// Read a variable length code, given the header bits already read.
// Returns the decoded value, or -1 for error.

static int decode_variable_length(BitStreamReader *reader,
                                  const VariableLengthTable *table,
                                  unsigned int header)
{
	int value;

	value = read_bits(reader, table[header].bits);

	if (value < 0) {
		return -1;
	}

	return (int) table[header].offset + value;
}

typedef struct {
	uint8_t prev;
	uint8_t next;
} HistoryNode;

// History linked list. In the decode stream, codes representing
// characters are not the character itself, but the number of
// nodes to count back in time in the linked list. Every time
// a character is output, it is moved to the front of the linked
// list. The entry point index into the list is the last output
// character, given by history_head;

typedef struct {
	HistoryNode history[256];
	uint8_t history_head;
} HistoryLinkedList;

// Initialize the history buffer.

static void init_history_list(HistoryLinkedList *list)
{
	unsigned int i;

	// History buffer is initialized to a linear chain to
	// start off with:

	for (i = 0; i < 256; ++i) {
		list->history[i].prev = (uint8_t) (i + 1);
		list->history[i].next = (uint8_t) (i - 1);
	}

	// The chain is cut into groups and initially arranged so
	// that the ASCII characters are closest to the start of
	// the chain. This is followed by ASCII control characters,
	// then various other groups.

	list->history_head = 0x20;

	list->history[0x7f].prev = 0x00;  // 0x20 ... 0x7f -> 0x00
	list->history[0x00].next = 0x7f;

	list->history[0x1f].prev = 0xa0;  // 0x00 ... 0x1f -> 0xa0
	list->history[0xa0].next = 0x1f;

	list->history[0xdf].prev = 0x80;  // 0xa0 ... 0xdf -> 0x80
	list->history[0x80].next = 0xdf;

	list->history[0x9f].prev = 0xe0;  // 0x80 ... 0x9f -> 0xe0
	list->history[0xe0].next = 0x9f;

	list->history[0xff].prev = 0x20;  // 0xe0 ... 0xff -> 0x20
	list->history[0x20].next = 0xff;
}

// Look up an entry in the history list, returning the code found.

static uint8_t find_in_history_list(HistoryLinkedList *list, uint8_t count)
{
	unsigned int i;
	uint8_t code;

	// Start from the last outputted byte.

	code = list->history_head;

	// Walk along the history chain until we reach the desired
	// node.  If we will have to walk more than half the chain,
	// go the other way around.

	if (count < 128) {
		for (i = 0; i < count; ++i) {
			code = list->history[code].prev;
		}
	} else {
		for (i = 0; i < 256U - count; ++i) {
			code = list->history[code].next;
		}
	}

	return code;
}

// Update history list, by moving the specified byte to the head
// of the queue.

static void update_history_list(HistoryLinkedList *list, uint8_t b)
{
	HistoryNode *node, *old_head;

	// No update necessary?

	if (list->history_head == b) {
		return;
	}

	// Unhook the entry from its current position:

	node = &list->history[b];
	list->history[node->next].prev = node->prev;
	list->history[node->prev].next = node->next;

	// Hook in between the old head and old_head->next:

	old_head = &list->history[list->history_head];
	node->prev = list->history_head;
	node->next = old_head->next;

	list->history[old_head->next].prev = b;
	old_head->next = b;

	// 'b' is now the head of the queue:

	list->history_head = b;
}
