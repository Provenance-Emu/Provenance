

#include "types.h"
#include "conloop.h"

int main(Int32 nArgs, Char **pArg)
{
	if (ConLoopInit())
	{
		// do stuff here
		while (ConLoopProcess())
		{
		}

		ConLoopShutdown();
	}

	return 0;
}
