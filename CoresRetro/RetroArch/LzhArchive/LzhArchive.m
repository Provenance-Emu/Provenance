#import "LzhArchive.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "lib/lha_arch.h"
#include "lha_reader.h"

#include "config.h"
#include "extract.h"
#include "list.h"

typedef enum {
    MODE_UNKNOWN,
    MODE_LIST,
    MODE_LIST_VERBOSE,
    MODE_CRC_CHECK,
    MODE_EXTRACT,
    MODE_PRINT
} ProgramMode;

@interface LzhArchive ()
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@end

@implementation LzhArchive
{
    /// path for zip file
    NSString *_path;
}
#pragma mark - Unzipping
+ (BOOL)unLzhFileAtPath:(NSString *)path toDestination:(NSString *)destination overwrite:(BOOL)overwrite
{
    ProgramMode mode = MODE_EXTRACT;
    LHAOptions options;
    options.overwrite_policy = overwrite ? LHA_OVERWRITE_ALL : LHA_OVERWRITE_SKIP;
    options.quiet = 0;
    options.verbose = 1;
    options.dry_run = 0;
    options.extract_path = [destination UTF8String];
    options.use_path = 0;

    FILE *fstream;
    LHAInputStream *stream;
    LHAReader *reader;
    LHAFilter filter;
    int result;
    fstream = fopen([path UTF8String], "rb");
    if (fstream == NULL) {
        NSLog(@"Archive: LZH Read Error\n");
        return false;
    }
    NSLog(@"Archive: Reading LZH %@\n", path);
    stream = lha_input_stream_from_FILE(fstream);
    reader = lha_reader_new(stream);
    lha_filter_init(&filter, reader, NULL, 0);
    result = 1;
    switch (mode) {
        case MODE_LIST:
            list_file_basic(&filter, &options, fstream);
            break;

        case MODE_LIST_VERBOSE:
            list_file_verbose(&filter, &options, fstream);
            break;

        case MODE_CRC_CHECK:
            result = test_file_crc(&filter, &options);
            break;

        case MODE_EXTRACT:
            result = extract_archive(&filter, &options);
            break;

        case MODE_PRINT:
            result = print_archive(&filter, &options);
            break;

        case MODE_UNKNOWN:
            break;
    }
    print_archive(&filter, &options);
    lha_reader_free(reader);
    lha_input_stream_free(stream);
    NSLog(@"Archive Result %d\n", result);
    fclose(fstream);
    return true;
}
@end
