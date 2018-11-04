#ifndef __BML_H
#define __BML_H
#include <vector>

const int bml_attr_type = -2;

typedef struct bml_node
{
    char *name;
    char *data;

    int depth;

    std::vector<bml_node *> child;

} bml_node;

bml_node *bml_find_sub (bml_node *node, const char *name);

bml_node *bml_parse_file (const char *filename);

/* Parse character array into BML tree. Destructive to input. */
bml_node *bml_parse (char **buffer);

/* Recursively free bml_node and substructures */
void bml_free_node (bml_node *);

/* Print node structure to stdout */
void bml_print_node (bml_node *);

#endif
