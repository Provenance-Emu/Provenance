
#ifndef _TITLEMAN_H
#define _TITLEMAN_H

int find_title(FILE *f, const char *title, int *offset);
int get_next_title(FILE *f, char *title, int *offset);
int list_title_db(const char *name);
int add_title_db(const char *name, const char *title);
int del_title_db(FILE *f, const char *title);


#endif
