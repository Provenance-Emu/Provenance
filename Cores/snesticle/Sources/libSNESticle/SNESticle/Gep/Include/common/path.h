
/*!

    \File    path.h

    \Description
	    Description

    \Notes
	    None.

    \Copyright
	    (c) 2004 Icer Addis

*/


#ifndef _path_h
#define _path_h

/*-- Include files -------------------------------------------------------------------------------*/

/*-- Preprocessor Definitions --------------------------------------------------------------------*/

#define PATH_MAX		(256)
#define PATH_MAX_DRIVE	(32)
#define PATH_MAX_DIR	(256)
#define PATH_MAX_NAME	(256)
#define PATH_MAX_EXT	(256)

/*-- Type Definitions ----------------------------------------------------------------------------*/

class CPath
{
public:
	CPath();
	CPath(const char *pPath);

	const char *				GetDrive() const				{return m_drive;}
	const char *				GetDir() const					{return m_dir;}
	const char *				GetName() const					{return m_name;}
	const char *				GetExt() const					{return m_ext;}
	const char *				GetPath();

	Bool 						HasDrive() const				{return m_drive[0]!='\0';}
	Bool 						HasDir() const					{return m_dir[0]!='\0';}
	Bool 						HasName() const					{return m_name[0]!='\0';}
	Bool 						HasExt() const					{return m_ext[0]!='\0';}

	void 						SetPath(const char *pPath);
	void 						SetDrive(const char *pDrive);
	void 						SetDir(const char *pDir);
	void 						SetName(const char *pName);
	void 						SetExt(const char *pExt);

	void 						Reset();

private:
	char						m_drive[PATH_MAX_DRIVE];
	char						m_dir[PATH_MAX_DIR];
	char						m_name[PATH_MAX_NAME];
	char						m_ext[PATH_MAX_EXT];
	char    					m_path[PATH_MAX];
};


/*-- Variables -----------------------------------------------------------------------------------*/

/*-- Functions -----------------------------------------------------------------------------------*/

void PathGetFileName(Char *pName, const Char *pPath);
void PathGetFileExt(Char *pExt, const Char *pPath);

#endif // _path_h

