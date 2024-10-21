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

// Common tree decoding code.
//
// A recurring feature used by the different LHA algorithms is to
// encode a set of codes, which have varying bit lengths. This is
// implemented using a binary tree, stored inside an array of
// elements.
//
// This file is implemented as a "template" file to be #include-d by
// other files. The typedef for TreeElement must be defined before
// include.


// Upper bit is set in a node value to indicate a leaf.

#define TREE_NODE_LEAF    (TreeElement) (1 << (sizeof(TreeElement) * 8 - 1))

// Structure used to hold data needed to build the tree.

typedef struct {
	// The tree data and its size (must not be exceeded)

	TreeElement *tree;
	unsigned int tree_len;

	// Counter used to allocate entries from the tree.
	// Every time a new node is allocated, this increase by 2.

	unsigned int tree_allocated;

	// The next tree entry.
	// As entries are allocated sequentially, the range from
	// next_entry..tree_allocated-1 constitutes the indices into
	// the tree that are available to be filled in. By the
	// end of the tree build, next_entry should = tree_allocated.

	unsigned int next_entry;
} TreeBuildData;

// Initialize all elements of the given tree to a good initial state.

static void init_tree(TreeElement *tree, size_t tree_len)
{
	unsigned int i;

	for (i = 0; i < tree_len; ++i) {
		tree[i] = TREE_NODE_LEAF;
	}
}

// Set tree to always decode to a single code.

static void set_tree_single(TreeElement *tree, TreeElement code)
{
	tree[0] = (TreeElement) code | TREE_NODE_LEAF;
}

// "Expand" the list of queue entries. This generates a new child
// node at each of the entries currently in the queue, adding the
// children of those nodes into the queue to replace them.
// The effect of this is to add an extra level to the tree, and
// to increase the tree depth of the indices in the queue.

static void expand_queue(TreeBuildData *build)
{
	unsigned int end_offset;
	unsigned int new_nodes;

	// Sanity check that there is enough space in the tree for
	// all the new nodes.

	new_nodes = (build->tree_allocated - build->next_entry) * 2;

	if (build->tree_allocated + new_nodes > build->tree_len) {
		return;
	}

	// Go through all entries currently in the allocated range, and
	// allocate a subnode for each.

	end_offset = build->tree_allocated;

	while (build->next_entry < end_offset) {
		build->tree[build->next_entry] = build->tree_allocated;
		build->tree_allocated += 2;
		++build->next_entry;
	}
}

// Read the next entry from the queue of entries waiting to be used.

static unsigned int read_next_entry(TreeBuildData *build)
{
	unsigned int result;

	// Sanity check.

	if (build->next_entry >= build->tree_allocated) {
		return 0;
	}

	result = build->next_entry;
	++build->next_entry;

	return result;
}

// Add all codes to the tree that have the specified length.
// Returns non-zero if there are any entries in code_lengths[] still
// waiting to be added to the tree.

static int add_codes_with_length(TreeBuildData *build,
                                 uint8_t *code_lengths,
                                 unsigned int num_code_lengths,
                                 unsigned int code_len)
{
	unsigned int i;
	unsigned int node;
	int codes_remaining;

	codes_remaining = 0;

	for (i = 0; i < num_code_lengths; ++i) {

		// Does this code belong at this depth in the tree?

		if (code_lengths[i] == code_len) {
			node = read_next_entry(build);

			build->tree[node] = (TreeElement) i | TREE_NODE_LEAF;
		}

		// More work to be done after this pass?

		else if (code_lengths[i] > code_len) {
			codes_remaining = 1;
		}
	}

	return codes_remaining;
}

// Build a tree, given the specified array of codes indicating the
// required depth within the tree at which each code should be
// located.

static void build_tree(TreeElement *tree, size_t tree_len,
                       uint8_t *code_lengths, unsigned int num_code_lengths)
{
	TreeBuildData build;
	unsigned int code_len;

	build.tree = tree;
	build.tree_len = tree_len;

	// Start with a single entry in the queue - the root node
	// pointer.

	build.next_entry = 0;

	// We always have the root ...

	build.tree_allocated = 1;

	// Iterate over each possible code length.
	// Note: code_len == 0 is deliberately skipped over, as 0
	// indicates "not used".

	code_len = 0;

	do {
		// Advance to the next code length by allocating extra
		// nodes to the tree - the slots waiting in the queue
		// will now be one level deeper in the tree (and the
		// codes 1 bit longer).

		expand_queue(&build);
		++code_len;

		// Add all codes that have this length.

	} while (add_codes_with_length(&build, code_lengths,
	                               num_code_lengths, code_len));
}

/*
static void display_tree(TreeElement *tree, unsigned int node, int offset)
{
	unsigned int i;

	if (node & TREE_NODE_LEAF) {
		for (i = 0; i < offset; ++i) putchar(' ');
		printf("leaf %i\n", node & ~TREE_NODE_LEAF);
	} else {
		for (i = 0; i < offset; ++i) putchar(' ');
		printf("0 ->\n");
		display_tree(tree, tree[node], offset + 4);
		for (i = 0; i < offset; ++i) putchar(' ');
		printf("1 ->\n");
		display_tree(tree, tree[node + 1], offset + 4);
	}
}
*/

// Read bits from the input stream, traversing the specified tree
// from the root node until we reach a leaf.  The leaf value is
// returned.

static int read_from_tree(BitStreamReader *reader, TreeElement *tree)
{
	TreeElement code;
	int bit;

	// Start from root.

	code = tree[0];

	while ((code & TREE_NODE_LEAF) == 0) {

		bit = read_bit(reader);

		if (bit < 0) {
			return -1;
		}

		code = tree[code + (unsigned int) bit];
	}

	// Mask off leaf bit to get the plain code.

	return (int) (code & ~TREE_NODE_LEAF);
}
