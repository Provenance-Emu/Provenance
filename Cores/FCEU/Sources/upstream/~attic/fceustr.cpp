#include <string.h>
#include <stdlib.h>

#include "types.h"
#include "fceustr.h"


/* Creates a fceustr from a C-style string. */
fceustr *fceustr_create(const char *str)
{
 fceustr *ret; 

 ret=malloc(sizeof(fceustr));
 
 ret->data=malloc(strlen(str)+1);
 strcpy(ret->data,str);

 ret->len=strlen(str);

 return(ret);
}

void fceustr_destroy(fceustr *str)
{
 if(str->data) free(str->data);
 free(str);
}
