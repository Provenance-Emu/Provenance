#ifndef _OLDMOVIE_H_
#define _OLDMOVIE_H_

#include "movie.h"

enum EFCM_CONVERTRESULT
{
	FCM_CONVERTRESULT_SUCCESS,
	FCM_CONVERTRESULT_FAILOPEN,
	FCM_CONVERTRESULT_OLDVERSION,
	FCM_CONVERTRESULT_UNSUPPORTEDVERSION,
	FCM_CONVERTRESULT_STARTFROMSAVESTATENOTSUPPORTED,
};

inline const char * EFCM_CONVERTRESULT_message(EFCM_CONVERTRESULT e)
{
	static const char * errmsg[] = {
		"Success",
		"Failed to open input file",
		"This is a 'version 1' movie file. These are not supported yet.",
		"This is an unsupported ancient version",
		"Movies starting from savestates are not supported"
	};

	return errmsg[e];
}

EFCM_CONVERTRESULT convert_fcm(MovieData& md, std::string fname);

#endif
