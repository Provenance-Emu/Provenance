/** SDLMain.m - main entry point for our Cocoa-ized SDL app
    Initial Version: Darrell Walisser <dwaliss1@purdue.edu>
    Non-NIB-Code & other changes: Max Horn <max@quendi.de>
  */

#import "SDL.h"
#import "SDLMain.h"

#define SDL_main stellaMain
extern int stellaMain(int argc, char* argv[]);

static int    gArgc;
static char** gArgv;

// The main class of the application, the application's delegate
@implementation SDLMain {
  BOOL calledMainline;
  NSString* openFilename;
}

// ----------------------------------------------------------------------------
static SDLMain* sharedInstance = nil;

+ (SDLMain*) sharedInstance {
    return sharedInstance;
}

// ----------------------------------------------------------------------------
/**
  * Catch document open requests...this lets us notice files when the app
  *  was launched by double-clicking a document, or when a document was
  *  dragged/dropped on the app's icon. You need to have a
  *  CFBundleDocumentsType section in your Info.plist to get this message,
  *  apparently.
  *
  * Files are added to gArgv, so to the app, they'll look like command line
  *  arguments. Previously, apps launched from the finder had nothing but
  *  an argv[0].
  *
  * This message may be received multiple times to open several docs on launch.
  *
  * This message is ignored once the app's mainline has been called.
  */
- (BOOL)application:(NSApplication*)theApplication openFile:(NSString*)filename
{
  if (calledMainline) return FALSE;

  openFilename = filename;

  return TRUE;
}


// ----------------------------------------------------------------------------
// Called when the internal event loop has just started running
- (void) applicationDidFinishLaunching: (NSNotification *) note
{
  int status;

  calledMainline = TRUE;

  if (openFilename) {
    int _argc = 2;
    char** _argv = SDL_malloc(sizeof(char*) * 2);

    _argv[0] = gArgv[0];

    char* filename = SDL_malloc(strlen([openFilename UTF8String]) + 1);
    strcpy(filename, [openFilename UTF8String]);
    _argv[1] = filename;

    status = SDL_main(_argc, _argv);

    SDL_free(filename);
    SDL_free(_argv);
  } else
    status = SDL_main(gArgc, gArgv);

  // We're done, thank you for playing
  exit(status);
}

@end

#ifdef main
#  undef main
#endif

// Main entry point to executable - should *not* be SDL_main!
int main (int argc, char* argv[])
{
  gArgc = argc;
  gArgv = argv;

  NSApplicationMain (argc, (const char**)argv);

  return 0;
}
