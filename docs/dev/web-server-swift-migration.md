# Swift web server migration (#2764)

Swift HTTP/WebDAV is the only backend for fresh installs and upgrades. The old useModernWebServer preference is no longer read; an old false value cannot retain the removed backend. The obsolete Advanced toggle/search result, ObjC adapter/re-export, status swizzles and vendored GCDWebServer/GCDWebUploader/GCDWebDAV sources/resources are removed. Swift product names remain unchanged.

The manager owns server lifetime. Reopening controls retains running connections, while an unexpectedly stopped listener can be restarted. Start/Stop operations serialize across actor suspension points. Done only dismisses the alert; iOS retains Open Web Uploader and both platforms have explicit Stop Server. Existing status events update the import-source menu's Running label.

## Preserved contracts

- Bind remains 0.0.0.0 with device HTTP 80 / WebDAV 81; Simulator/macOS use 8080/8081. Browse root remains Documents on iOS/macOS, Caches on tvOS. Default uploads use Imports under that root; explicit relative routing remains.
- Anonymous uploader/WebDAV access is unchanged. Debug API enablement and Basic authentication still use PVDebugAPIPrefs, including release default auth and fail-closed empty-password handling. No credentials, keychains or persistent access settings are changed.
- Upload start/progress/completed/failed and status notifications keep existing names/payloads; delete/move file events, SSE and debug route handlers remain. Uploading into a system directory does not itself establish library discovery; importer work is separately owned.
- HTTP and WebDAV Bonjour records advertise their existing listener ports on the main run loop.
- Existing bootstrap and emulation pause/resume behavior is unchanged. No new always-on/background listener policy or shared package extraction is introduced.

## Compatibility fixes

Hummingbird recursive routes capture paths with getCatchAll(), not get("**"). WebDAV uses the actual captured path for PUT/GET/HEAD/DELETE/MKCOL/COPY/MOVE/PROPFIND; root OPTIONS/PROPFIND support Finder discovery. Existing traversal checks and MOVE response semantics remain.

## Focused verification and remaining checks

The package suite checks selection, reopening/concurrent starts/failed-start recovery, actual multipart and system-directory uploads with byte equality/completion events, traversal rejection, real WebDAV operations and file events, debug Basic auth and Bonjour records. Router checks run in-process without network listeners. Separate package builds cover iOS/tvOS Simulator.

Before a future app build containing this change, combine the isolated PVLibraryRootView server-control hunks with the UI owner's header/Add Files work and compile PVUI for iOS/tvOS. Exercise Done during an upload, reopen without interruption, Running state, explicit Stop and Bonjour discovery on hardware. Package tests/builds and Swift syntax parsing do not establish full app or device acceptance.
