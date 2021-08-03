#ifndef __MDFN_DRIVERS_ARGS_H
#define __MDFN_DRIVERS_ARGS_H

enum
{
 SUBSTYPE_INTEGER = 0,
 SUBSTYPE_STRING = 1,
 SUBSTYPE_DOUBLE = 2,

 SUBSTYPE_FUNCTION = 0x2000,

 SUBSTYPE_STRING_ALLOC = 0x4001,
};

typedef struct {
        const char *name;
	const char *description;
	int *var;

	void *subs;
	int substype;
} ARGPSTRUCT;

int ParseArguments(int argc, char *argv[], ARGPSTRUCT *argsps, char **);
int ShowArgumentsHelp(ARGPSTRUCT *argsps, bool show_linked = true);

#endif
