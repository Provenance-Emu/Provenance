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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include "lha_decoder.h"

#include "bit_stream_reader.c"

// Size of the ring buffer used to hold history:

#define RING_BUFFER_SIZE     4096 /* bytes */

// When this limit is reached, the code tree is reordered.

#define TREE_REORDER_LIMIT   32 * 1024  /* 32 kB */

// Number of codes ('byte' codes + 'copy' codes):

#define NUM_CODES            314

// Number of nodes in the code tree.

#define NUM_TREE_NODES       (NUM_CODES * 2 - 1)

// Number of possible offsets:

#define NUM_OFFSETS          64

// Minimum length of the offset top bits:

#define MIN_OFFSET_LENGTH    3 /* bits */

// Threshold for copying. The first copy code starts from here.

#define COPY_THRESHOLD       3 /* bytes */

// Required size of the output buffer.  At most, a single call to read()
// might result in a copy of the entire ring buffer.

#define OUTPUT_BUFFER_SIZE   RING_BUFFER_SIZE

typedef struct {

	// If true, this node is a leaf node.

	unsigned int leaf        :1;

	// If this is a leaf node, child_index is the code represented by
	// this node. Otherwise, nodes[child_index] and nodes[child_index-1]
	// are the children of this node.

	unsigned int child_index :15;

	// Index of the parent node of this node.

	uint16_t parent;

	// Frequency count for this node - number of times that it has
	// received a hit.

	uint16_t freq;

	// Group that this node belongs to.

	uint16_t group;
} Node;

typedef struct {

	// Input bit stream.

	BitStreamReader bit_stream_reader;

	// Ring buffer of past data.  Used for position-based copies.

	uint8_t ringbuf[RING_BUFFER_SIZE];
	unsigned int ringbuf_pos;

	// Array of tree nodes. nodes[0] is the root node.  The array
	// is maintained in order by frequency.

	Node nodes[NUM_TREE_NODES];

	// Indices of leaf nodes of the tree (map from code to leaf
	// node index)

	uint16_t leaf_nodes[NUM_CODES];

	// Groups list.  Every node belongs to a group.  All nodes within
	// a group have the same frequency. There can be at most
	// NUM_TREE_NODES groups (one for each node). num_groups is used
	// to allocate and deallocate groups as needed.

	uint16_t groups[NUM_TREE_NODES];
	unsigned int num_groups;

	// Index of the "leader" of a group within the nodes[] array.
	// The leader is the left-most node within a span of nodes with
	// the same frequency.

	uint16_t group_leader[NUM_TREE_NODES];

	// Offset lookup table.  Maps from a byte value (sequence of next
	// 8 bits from input stream) to an offset value.

	uint8_t offset_lookup[256];

	// Length of offsets, in bits.

	uint8_t offset_lengths[NUM_OFFSETS];
} LHALH1Decoder;

// Frequency distribution used to calculate the offset codes.

static const unsigned int offset_fdist[] = {
	1,    // 3 bits
	3,    // 4 bits
	8,    // 5 bits
	12,   // 6 bits
	24,   // 7 bits
	16,   // 8 bits
};

// Allocate a group from the free groups array.

static uint16_t alloc_group(LHALH1Decoder *decoder)
{
	uint16_t result;

	result = decoder->groups[decoder->num_groups];
	++decoder->num_groups;

	return result;
}

// Free a group that is no longer in use.

static void free_group(LHALH1Decoder *decoder, uint16_t group)
{
	--decoder->num_groups;
	decoder->groups[decoder->num_groups] = group;
}

// Initialize groups array.

static void init_groups(LHALH1Decoder *decoder)
{
	unsigned int i;

	for (i = 0; i < NUM_TREE_NODES; ++i) {
		decoder->groups[i] = (uint16_t) i;
	}

	decoder->num_groups = 0;
}

// Initialize the tree with its basic initial configuration.

static void init_tree(LHALH1Decoder *decoder)
{
	unsigned int i, child;
	int node_index;
	uint16_t leaf_group;
	Node *node;

	// Leaf nodes are placed at the end of the table.  Start by
	// initializing these, and working backwards.

	node_index = NUM_TREE_NODES - 1;
	leaf_group = alloc_group(decoder);

	for (i = 0; i < NUM_CODES; ++i) {
		node = &decoder->nodes[node_index];
		node->leaf = 1;
		node->child_index = (unsigned short) i;
		node->freq = 1;
		node->group = leaf_group;

		decoder->group_leader[leaf_group] = (uint16_t) node_index;
		decoder->leaf_nodes[i] = (uint16_t) node_index;

		--node_index;
	}

	// Now build up the intermediate nodes, up to the root.  Each
	// node gets two nodes as children.

	child = NUM_TREE_NODES - 1;

	while (node_index >= 0) {
		node = &decoder->nodes[node_index];
		node->leaf = 0;

		// Set child pointer and update the parent pointers of the
		// children.

		node->child_index = child;
		decoder->nodes[child].parent = (uint16_t) node_index;
		decoder->nodes[child - 1].parent = (uint16_t) node_index;

		// The node's frequency is equal to the sum of the frequencies
		// of its children.

		node->freq = (uint16_t) (decoder->nodes[child].freq
		                       + decoder->nodes[child - 1].freq);

		// Is the frequency the same as the last node we processed?
		// if so, we are in the same group. If not, we must
		// allocate a new group.  Either way, this node is now the
		// leader of its group.

		if (node->freq == decoder->nodes[node_index + 1].freq) {
			node->group = decoder->nodes[node_index + 1].group;
		} else {
			node->group = alloc_group(decoder);
		}

		decoder->group_leader[node->group] = (uint16_t) node_index;

		// Process next node.

		--node_index;
		child -= 2;
	}
}

// Fill in a range of values in the offset_lookup table, which have
// the bits from 'code' as the high bits, and the low bits can be
// any values in the range from 'mask'.  Set these values to point
// to 'offset'.

static void fill_offset_range(LHALH1Decoder *decoder, uint8_t code,
                              unsigned int mask, unsigned int offset)
{
	unsigned int i;

	// Set offset lookup table to map from all possible input values
	// that fit within the mask to the target offset.

	for (i = 0; (i & ~mask) == 0; ++i) {
		decoder->offset_lookup[code | i] = (uint8_t) offset;
	}
}

// Calculate the values for the offset_lookup and offset_lengths
// tables.

static void init_offset_table(LHALH1Decoder *decoder)
{
	unsigned int i, j, len;
	uint8_t code, iterbit, offset;

	code = 0;
	offset = 0;

	// Iterate through each entry in the frequency distribution table,
	// filling in codes in the lookup table as we go.

	for (i = 0; i < sizeof(offset_fdist) / sizeof(*offset_fdist); ++i) {

		// offset_fdist[0] is the number of codes of length
		// MIN_OFFSET_LENGTH bits, increasing as we go. As the
		// code increases in length, we must iterate progressively
		// lower bits in the code (moving right - extending the
		// code to be 1 bit longer).

		len = i + MIN_OFFSET_LENGTH;
		iterbit = (uint8_t) (1 << (8 - len));

		for (j = 0; j < offset_fdist[i]; ++j) {

			// Store lookup values for this offset in the
			// lookup table, and save the code length.
			// (iterbit - 1) turns into a mask for the lower
			// bits that are not part of the code.

			fill_offset_range(decoder, code,
			                  (uint8_t) (iterbit - 1), offset);
			decoder->offset_lengths[offset] = (uint8_t) len;

			// Iterate to next code.

			code = (uint8_t) (code + iterbit);
			++offset;
		}
	}
}

// Initialize the history ring buffer.

static void init_ring_buffer(LHALH1Decoder *decoder)
{
	memset(decoder->ringbuf, ' ', RING_BUFFER_SIZE);
	decoder->ringbuf_pos = 0;
}

static int lha_lh1_init(void *data, LHADecoderCallback callback,
                        void *callback_data)
{
	LHALH1Decoder *decoder = data;

	// Initialize input stream reader.

	bit_stream_reader_init(&decoder->bit_stream_reader,
	                       callback, callback_data);

	// Initialize data structures.

	init_groups(decoder);
	init_tree(decoder);
	init_offset_table(decoder);
	init_ring_buffer(decoder);

	return 1;
}

// Make the given node the leader of its group: swap it with the current
// leader so that it is in the left-most position.  Returns the new index
// of the node.

static uint16_t make_group_leader(LHALH1Decoder *decoder,
                                  uint16_t node_index)
{
	Node *node, *leader;
	uint16_t group;
	uint16_t leader_index;
	unsigned int tmp;

	group = decoder->nodes[node_index].group;
	leader_index = decoder->group_leader[group];

	// Already the leader?  If so, there is nothing to do.

	if (leader_index == node_index) {
		return node_index;
	}

	node = &decoder->nodes[node_index];
	leader = &decoder->nodes[leader_index];

	// Swap leaf and child indices in the two nodes:

	tmp = leader->leaf;
	leader->leaf = node->leaf;
	node->leaf = tmp;

	tmp = leader->child_index;
	leader->child_index = node->child_index;
	node->child_index = tmp;

	if (node->leaf) {
		decoder->leaf_nodes[node->child_index] = node_index;
	} else {
		decoder->nodes[node->child_index].parent = node_index;
		decoder->nodes[node->child_index - 1].parent = node_index;
	}

	if (leader->leaf) {
		decoder->leaf_nodes[leader->child_index] = leader_index;
	} else {
		decoder->nodes[leader->child_index].parent = leader_index;
		decoder->nodes[leader->child_index - 1].parent = leader_index;
	}

	return leader_index;
}

// Increase the frequency count for a node, rearranging groups as
// appropriate.

static void increment_node_freq(LHALH1Decoder *decoder, uint16_t node_index)
{
	Node *node, *other;

	node = &decoder->nodes[node_index];
	other = &decoder->nodes[node_index - 1];

	++node->freq;

	// If the node is part of a group containing other nodes, it
	// must leave the group.

	if (node_index < NUM_TREE_NODES - 1
	 && node->group == decoder->nodes[node_index + 1].group) {

		// Next node in the group now becomes the leader.

		++decoder->group_leader[node->group];

		// The node must now either join the group to its
		// left, or start a new group.

		if (node->freq == other->freq) {
			node->group = other->group;
		} else {
			node->group = alloc_group(decoder);
			decoder->group_leader[node->group] = node_index;
		}

	} else {
		// The node is in a group of its own (single-node
		// group).  It might need to join the group of the
		// node on its left if it has the same frequency.

		if (node->freq == other->freq) {
			free_group(decoder, node->group);
			node->group = other->group;
		}
	}
}

// Reconstruct the code huffman tree to be more evenly distributed.
// Invoked periodically as data is processed.

static void reconstruct_tree(LHALH1Decoder *decoder)
{
	Node *leaf;
	unsigned int child;
	unsigned int freq;
	unsigned int group;
	int i;

	// Gather all leaf nodes at the start of the table.

	leaf = decoder->nodes;

	for (i = 0; i < NUM_TREE_NODES; ++i) {
		if (decoder->nodes[i].leaf) {
			leaf->leaf = 1;
			leaf->child_index = decoder->nodes[i].child_index;

			// Frequency of the nodes in the new tree is halved,
			// this acts as a running average each time the
			// tree is reconstructed.

			leaf->freq = (uint16_t) (decoder->nodes[i].freq + 1) / 2;

			++leaf;
		}
	}

	// The leaf nodes are now all at the start of the table.  Now
	// reconstruct the tree, starting from the end of the table and
	// working backwards, inserting branch nodes between the leaf
	// nodes.  Each branch node inherits the sum of the frequencies
	// of its children, and must be placed to maintain the ordering
	// within the table by decreasing frequency.

	leaf = &decoder->nodes[NUM_CODES - 1];
	child = NUM_TREE_NODES - 1;
	i = NUM_TREE_NODES - 1;

	while (i >= 0) {

		// Before we can add a new branch node, we need at least
		// two nodes to use as children.  If we don't have this
		// then we need to copy some from the leaves.

		while ((int) child - i < 2) {
			decoder->nodes[i] = *leaf;
			decoder->leaf_nodes[leaf->child_index] = (uint16_t) i;

			--i;
			--leaf;
		}

		// Now that we have at least two nodes to take as children
		// of the new branch node, we can calculate the branch
		// node's frequency.

		freq = (unsigned int) (decoder->nodes[child].freq
		                     + decoder->nodes[child - 1].freq);

		// Now copy more leaf nodes until the correct place to
		// insert the new branch node presents itself.

		while (leaf >= decoder->nodes && freq >= leaf->freq) {
			decoder->nodes[i] = *leaf;
			decoder->leaf_nodes[leaf->child_index] = (uint16_t) i;

			--i;
			--leaf;
		}

		// The new branch node can now be inserted.

		decoder->nodes[i].leaf = 0;
		decoder->nodes[i].freq = (uint16_t) freq;
		decoder->nodes[i].child_index = (uint16_t) child;

		decoder->nodes[child].parent = (uint16_t) i;
		decoder->nodes[child - 1].parent = (uint16_t) i;

		--i;

		// Process the next pair of children.

		child -= 2;
	}

	// Reconstruct the group data.  Start by resetting group data.

	init_groups(decoder);

	// Assign a group to the first node.

	group = alloc_group(decoder);
	decoder->nodes[0].group = (uint16_t) group;
	decoder->group_leader[group] = 0;

	// Assign a group number to each node, nodes having the same
	// group if the have the same frequency, and allocating new
	// groups when a new frequency is found.

	for (i = 1; i < NUM_TREE_NODES; ++i) {
		if (decoder->nodes[i].freq == decoder->nodes[i - 1].freq) {
			decoder->nodes[i].group = decoder->nodes[i - 1].group;
		} else {
			group = alloc_group(decoder);
			decoder->nodes[i].group = (uint16_t) group;

			// First node with a particular frequency is leader.
			decoder->group_leader[group] = (uint16_t) i;
		}
	}
}

// Increment the counter for the specific code, reordering the tree as
// necessary.

static void increment_for_code(LHALH1Decoder *decoder, uint16_t code)
{
	uint16_t node_index;

	// When the limit is reached, we must reorder the code tree
	// to better match the code frequencies:

	if (decoder->nodes[0].freq >= TREE_REORDER_LIMIT) {
		reconstruct_tree(decoder);
	}

	++decoder->nodes[0].freq;

	// Dynamically adjust the tree.  Start from the leaf node of
	// the tree and walk back up, rearranging nodes to the root.

	node_index = decoder->leaf_nodes[code];

	while (node_index != 0) {

		// Shift the node to the left side of its group,
		// and bump the frequency count.

		node_index = make_group_leader(decoder, node_index);

		increment_node_freq(decoder, node_index);

		// Iterate up to the parent node.

		node_index = decoder->nodes[node_index].parent;
	}
}

// Read a code from the input stream.

static int read_code(LHALH1Decoder *decoder, uint16_t *result)
{
	unsigned int node_index;
	int bit;

	// Start from the root node, and traverse down until a leaf is
	// reached.

	node_index = 0;

	//printf("<root ");
	while (!decoder->nodes[node_index].leaf) {
		bit = read_bit(&decoder->bit_stream_reader);

		if (bit < 0) {
			return 0;
		}

		//printf("<%i>", bit);

		// Choose one of the two children depending on the
		// bit that was read.

		node_index = decoder->nodes[node_index].child_index
		           - (unsigned int) bit;
	}

	*result = decoder->nodes[node_index].child_index;
	//printf(" -> %i!>\n", *result);

	increment_for_code(decoder, *result);

	return 1;
}

// Read an offset code from the input stream.

static int read_offset(LHALH1Decoder *decoder, unsigned int *result)
{
	unsigned int offset;
	int future, offset2;

	// The offset can be up to 8 bits long, but is likely not
	// that long. Use the lookup table to find the offset
	// and its length.

	future = peek_bits(&decoder->bit_stream_reader, 8);

	if (future < 0) {
		return 0;
	}

	offset = decoder->offset_lookup[future];

	// Skip past the offset bits and also read the following
	// lower-order bits.

	read_bits(&decoder->bit_stream_reader,
	          decoder->offset_lengths[offset]);

	offset2 = read_bits(&decoder->bit_stream_reader, 6);

	if (offset2 < 0) {
		return 0;
	}

	*result = (offset << 6) | (unsigned int) offset2;

	return 1;
}

static void output_byte(LHALH1Decoder *decoder, uint8_t *buf,
                        size_t *buf_len, uint8_t b)
{
	buf[*buf_len] = b;
	++*buf_len;

	decoder->ringbuf[decoder->ringbuf_pos] = b;
	decoder->ringbuf_pos = (decoder->ringbuf_pos + 1) % RING_BUFFER_SIZE;
}

static size_t lha_lh1_read(void *data, uint8_t *buf)
{
	LHALH1Decoder *decoder = data;
	size_t result;
	uint16_t code;

	result = 0;

	// Read the next code from the input stream.

	if (!read_code(decoder, &code)) {
		return 0;
	}

	// The code either indicates a single byte to be output, or
	// it indicates that a block should be copied from the ring
	// buffer as it is a repeat of a sequence earlier in the
	// stream.

	if (code < 0x100) {
		output_byte(decoder, buf, &result, (uint8_t) code);
	} else {
		unsigned int count, start, i, pos, offset;

		// Read the offset into the history at which to start
		// copying.

		if (!read_offset(decoder, &offset)) {
			return 0;
		}

		count = code - 0x100U + COPY_THRESHOLD;
		start = decoder->ringbuf_pos - offset + RING_BUFFER_SIZE - 1;

		// Copy from history into output buffer:

		for (i = 0; i < count; ++i) {
			pos = (start + i) % RING_BUFFER_SIZE;

			output_byte(decoder, buf, &result,
			            decoder->ringbuf[pos]);
		}
	}

	return result;
}

LHADecoderType lha_lh1_decoder = {
	lha_lh1_init,
	NULL,
	lha_lh1_read,
	sizeof(LHALH1Decoder),
	OUTPUT_BUFFER_SIZE,
	RING_BUFFER_SIZE
};
