// Relaunch tool, extracted from Sparkle.framework

#import <AppKit/AppKit.h>
#import <unistd.h>

@interface TerminationListener : NSObject
{
@private
	const char *executablePath;
	pid_t parentProcessId;
}

- (void)relaunch __dead2;

@end

@implementation TerminationListener

- (void)watchdog:(NSTimer *)timer
{
	ProcessSerialNumber psn;
	if (GetProcessForPID(parentProcessId, &psn) == procNotFound)
	{
		[self relaunch];
		[timer invalidate];
	}
}

- (id) initWithExecutablePath:(const char *)execPath parentProcessId:(pid_t)ppid
{
	self = [super init];
	if (self != nil)
	{
		executablePath = execPath;
		parentProcessId = ppid;
		[NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(watchdog:) userInfo:nil repeats:YES];
	}
	return self;
}

- (void)relaunch
{
	NSString *path = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:executablePath length:strlen(executablePath)];
	[[NSWorkspace sharedWorkspace] launchApplication:path];
	exit(0);
}

@end

int main (int argc, const char * argv[])
{
	if (argc != 3)
		return EXIT_FAILURE;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	[[[TerminationListener alloc] initWithExecutablePath:argv[1] parentProcessId:atoi(argv[2])] autorelease];
	[[NSApplication sharedApplication] run];
	
	[pool drain];
	
	return EXIT_SUCCESS;
}
