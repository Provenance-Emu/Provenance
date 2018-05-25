/*
 *
 * Modified BSD license.
 *
 * Based on source code copyright (c) 1983, 1992, 1993 by The Regents of the University of California,
 * Copyright (c) 2012-2013 Sung-Taek, Kim <stkim1@colorfulglue.com> All Rights
 * Reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * Redistributions of  source code  must retain  the above  copyright notice,
 * this list of  conditions and the following  disclaimer. Redistributions in
 * binary  form must  reproduce  the  above copyright  notice,  this list  of
 * conditions and the following disclaimer  in the documentation and/or other
 * materials  provided with  the distribution.  Neither the  name of Sung-Tae
 * k Kim nor the names of its contributors may be used to endorse or promote
 * products  derived  from  this  software  without  specific  prior  written
 * permission.  THIS  SOFTWARE  IS  PROVIDED BY  THE  COPYRIGHT  HOLDERS  AND
 * CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
 * NOT LIMITED TO, THE IMPLIED  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A  PARTICULAR PURPOSE  ARE DISCLAIMED.  IN  NO EVENT  SHALL THE  COPYRIGHT
 * HOLDER OR  CONTRIBUTORS BE  LIABLE FOR  ANY DIRECT,  INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY,  OR CONSEQUENTIAL DAMAGES (INCLUDING,  BUT NOT LIMITED
 * TO, PROCUREMENT  OF SUBSTITUTE GOODS  OR SERVICES;  LOSS OF USE,  DATA, OR
 * PROFITS; OR  BUSINESS INTERRUPTION)  HOWEVER CAUSED AND  ON ANY  THEORY OF
 * LIABILITY,  WHETHER  IN CONTRACT,  STRICT  LIABILITY,  OR TORT  (INCLUDING
 * NEGLIGENCE  OR OTHERWISE)  ARISING  IN ANY  WAY  OUT OF  THE  USE OF  THIS
 * SOFTWARE,   EVEN  IF   ADVISED  OF   THE  POSSIBILITY   OF  SUCH   DAMAGE.
 *
 */



#import "LoggerDataWrite.h"
#include <sys/stat.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>

@interface LoggerDataWrite()
@property (nonatomic, readonly) NSData		*data;

static int make_mul_level_dir(char *);
static int check_dir_stat(const char *);
@end

@implementation LoggerDataWrite
{
	NSData			*_data;

}
@synthesize data = _data;

int
check_dir_stat(const char *path)
{
	struct stat sb;
	int retval = 0;
	
	if (stat(path, &sb) < 0)
	{
		retval = errno;
	}
	else
	{
		if (S_ISDIR(sb.st_mode))
		{
			retval = EEXIST;
		}
		else
		{
			retval = ENOTDIR;
		}
	}
	
	return retval;
}

/*
 origin of code : https://github.com/freebsd/freebsd/blob/master/bin/mkdir/mkdir.c
 this is how mkdir(2) -p operates.
 */
int
make_mul_level_dir(char *path)
{
	mode_t numask, oumask;
	int first, last, retval;
	char *p;
	
	p = path;
	oumask = 0;
	retval = 0;
	
	if (p[0] == '/')		/* Skip leading '/'. */
		++p;
	
	for (first = 1, last = 0; !last ; ++p)
	{
		
		if (p[0] == '\0')
		{
			last = 1;
		}
		else if (p[0] != '/')
		{
			continue;
		}
		
		// when *p is '/'...
		*p = '\0';
		
		if (p[1] == '\0')
		{
			last = 1;
		}
		
		
		if (first)
		{
			/*
			 * POSIX 1003.2:
			 * For each dir operand that does not name an existing
			 * directory, effects equivalent to those cased by the
			 * following command shall occcur:
			 *
			 * mkdir -p -m $(umask -S),u+wx $(dirname dir) &&
			 *    mkdir [-m mode] dir
			 *
			 * We change the user's umask and then restore it,
			 * instead of doing chmod's.
			 */
			oumask = umask(0);
			numask = oumask & ~(S_IWUSR | S_IXUSR);
			(void)umask(numask);
			first = 0;
		}
		
		if (last)
		{
			(void)umask(oumask);
		}
		
		/*
		 http://developer.apple.com/library/ios/#documentation/system/conceptual/manpages_iphoneos/man2/mkdir.2.html
		 iOS man page of mkdir(2) says it is compatible with IEEE Std
		 1003.1-1988 (``POSIX.1''). It's dated one but I am pretty sure it is
		 one of those atomic, thread-safe operations. Correct me if I am wrong.
		 stkim1 Jan. 08, 2013
		 */
		if (mkdir(path, (S_IRWXU | S_IRWXG | S_IRWXO)) < 0)
		{
			if (errno != EEXIST && errno != EISDIR)
			{
				retval = errno;
				break;
			}
		}
		
		if (!last)
		{
		    *p = '/';
		}
	}
	
	if (!first && !last)
	{
		(void)umask(oumask);
	}
	
	return (retval);
}

-(id)initWithBasepath:(NSString *)aBasepath
			 filePath:(NSString *)aFilepath
		dirOfFilepath:(NSString *)aDirOfFilepath
	   callback_queue:(dispatch_queue_t)a_callback_queue
			 callback:(callback_t)a_callback_block
{
	NSException* initException =
		[NSException
		 exceptionWithName:@"LoggerDataWrite"
		 reason:@"Inherited method not supported. Use InitWithData:basepath:filePath:dirPartOfFilepath:callback_queue:callback:"
		 userInfo:nil];
	@throw initException;
}

-(id)initWithData:(NSData *)aData
		 basepath:(NSString *)aBasepath
		 filePath:(NSString *)aFilepath
dirPartOfFilepath:(NSString *)aDirPartOfFilepath
   callback_queue:(dispatch_queue_t)a_callback_queue
		 callback:(callback_t)a_callback_block
{
	self =
		[super
		 initWithBasepath:aBasepath
		 filePath:aFilepath
		 dirOfFilepath:aDirPartOfFilepath
		 callback_queue:a_callback_queue
		 callback:a_callback_block];

	if(self)
	{
		_data = [aData retain];
	}
	return self;
}

-(void)dealloc
{
	[_data release],_data = nil;
	[super dealloc];
}

-(void)executeOnQueue:(dispatch_queue_t)aQueue
{
	dispatch_async(aQueue,^{
		if(IS_NULL_STRING(_basepath))
		{
			dispatch_async([self queue_callback],^{
				self.callback(self,ENOBASEPATH,nil);
			});

			return;
		}
		
		// if you cannot change the base of opration to 'documents'
		// you should return
		if(chdir([_basepath UTF8String]) < 0)
		{

NSLog(@"chdir error");

			int chdir_error_code;

			chdir_error_code = errno;

			dispatch_async([self queue_callback],^{
				self.callback(self,chdir_error_code,nil);
			});
			
			return;
		}

		// in case when you want to create a file in a child dir of basepath
		if(_dirPartOfFilepath != nil)
		{
			int		dir_status_code = 0;

			dir_status_code = check_dir_stat([_dirPartOfFilepath UTF8String]);
			
			//there is an error. clean up and stop
			if(dir_status_code != ENOENT && dir_status_code != EEXIST)
			{

NSLog(@"dir stat check error");

				dispatch_async([self queue_callback],^{
					self.callback(self,dir_status_code,nil);
				});
				
				return;
			}

			// dir non-exist. make dir
			if(dir_status_code == ENOENT)
			{
				int		mkdir_error = 0;
				char	*fpath_dir_part;
				
				fpath_dir_part = strdup([_dirPartOfFilepath UTF8String]);

NSLog(@"copied dir %s",fpath_dir_part);
				
				mkdir_error = make_mul_level_dir(fpath_dir_part);

				free(fpath_dir_part),fpath_dir_part = NULL;

				// if there is an error in making target dir
				if(mkdir_error != 0)
				{

NSLog(@"make target dir error");
					
					dispatch_async([self queue_callback],^{
						self.callback(self,mkdir_error,nil);
					});
					
					return;
				}
			}
		}
		// everything is green-lighted to proceed from this point on
		

		int fd = open([[self absTargetFilePath] UTF8String]
					  ,O_WRONLY|O_CREAT
					  ,S_IRUSR|S_IWUSR);
		
		dispatch_io_t channel_data_save = \
			dispatch_io_create(DISPATCH_IO_RANDOM
							   ,fd
							   ,[self queue_io_handler]
							   ,^(int error) {
								   close(fd);
							   });

		if(channel_data_save == NULL)
		{
			close(fd);
			dispatch_async([self queue_callback],^{
				self.callback(self,EIO,nil);
			});
		}
		else
		{
			dispatch_io_set_low_water(channel_data_save, 1);
			dispatch_io_set_high_water(channel_data_save, SIZE_MAX);

			dispatch_data_t data_save = \
				dispatch_data_create([_data bytes]
									 ,[_data length]
									 ,[self queue_io_handler]
									 ,^{/* You are not the owner of data. DO NOTHING!*/});

			dispatch_io_write(channel_data_save
							  ,0
							  ,data_save
							  ,[self queue_io_handler]
							  ,^(bool done, dispatch_data_t data, int error){
								  if(done)
								  {
									  dispatch_async([self queue_callback],^{
										  self.callback(self,error,nil);
									  });
								  }
							  });

			dispatch_io_close(channel_data_save, 0);
			dispatch_release(channel_data_save);
			dispatch_release(data_save);
		}
	});
}
@end
