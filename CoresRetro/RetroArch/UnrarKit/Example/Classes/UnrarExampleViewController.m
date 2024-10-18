//
//  UnrarExampleViewController.m
//  UnrarExample
//
//

#import "UnrarExampleViewController.h"
@import UnrarKit;

@interface UnrarExampleViewController ()

@property (strong) NSURL *largeArchiveURL;
@property (strong) NSProgress *currentExtractionProgress;

@end

static void *ProgressObserverContext = &ProgressObserverContext;


@implementation UnrarExampleViewController


- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.extractionStepLabel.text = @"";
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *docsDir = [[fm URLsForDirectory:NSDocumentDirectory
                                 inDomains:NSUserDomainMask] firstObject];
    self.largeArchiveURL = [docsDir URLByAppendingPathComponent:@"large-archive.rar"];
}

- (IBAction)listFiles:(id)sender {
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"Test Archive (Password)" ofType:@"rar"];

    NSError *archiveError = nil;
    URKArchive *archive = [[URKArchive alloc] initWithPath:filePath error:&archiveError];
    archive.password = self.passwordField.text;
    
    if (!archive) {
        UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Failed to create archive"
                                                                            message:@"Error creating the archive"
                                                                     preferredStyle:UIAlertControllerStyleAlert];
        [controller addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        
        [self presentViewController:controller animated:YES completion:nil];
        return;
    }
    
    NSError *error = nil;
    NSArray *filenames = [archive listFilenames:&error];
    
	if (!filenames) {
        self.fileListTextView.text = error.localizedDescription;
        return;
    }
    
    NSMutableString *fileList = [NSMutableString string];
    
    for (NSString *filename in filenames) {
        [fileList appendFormat:@"• %@\n", filename];
    }
    
    self.fileListTextView.text = fileList;
}

- (IBAction)extractLargeFile:(id)sender {
    NSProgress *progress = [NSProgress progressWithTotalUnitCount:1];
    self.currentExtractionProgress = progress;
    [progress addObserver:self
               forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                  options:NSKeyValueObservingOptionInitial
                  context:ProgressObserverContext];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self updateExtractionStep:@"Creating large archive…"];
        
        NSURL *archiveURL = [self createLargeArchive];
        
        if (!archiveURL) {
            return;
        }
        
        [self updateExtractionStep:@"Extracting archive…"];
        
        NSError *initError = nil;
        URKArchive *archive = [[URKArchive alloc] initWithURL:archiveURL
                                                        error:&initError];
        
        if (!archive) {
            [self reportError:[NSString stringWithFormat:@"Failed to create URKArchive: %@", initError.localizedDescription]];
            return;
        }

        NSString *firstFile = [[archive listFilenames:nil] firstObject];

        [progress becomeCurrentWithPendingUnitCount:1];

        NSError *extractError = nil;
        NSData *data = [archive extractDataFromFile:firstFile
                                              error:&extractError];
        
        self.currentExtractionProgress = nil;
        [progress removeObserver:self
                      forKeyPath:NSStringFromSelector(@selector(fractionCompleted))
                         context:ProgressObserverContext];
        [progress resignCurrent];
        
        if (!data) {
            [self reportError:[NSString stringWithFormat:@"Failed to extract archive: %@", extractError.localizedDescription]];
            return;
        }

        // On extraction completion:
        [self updateExtractionStep:[NSString stringWithFormat:@"Extracted %lub", (unsigned long)data.length]];
    });
}

- (IBAction)cancelExtraction:(id)sender {
    if (self.currentExtractionProgress) {
        [self.currentExtractionProgress cancel];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (context == ProgressObserverContext) {
        NSProgress *progress = object;
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self.extractionProgressView setProgress:progress.fractionCompleted
                                            animated:YES];
        }];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)reportError:(NSString *)message {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        self.fileListTextView.text = message;
    }];
}

- (void)updateExtractionStep:(NSString *)message {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        self.extractionStepLabel.text = message;
    }];
}

- (void)updateProgress:(float)progress {
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self.extractionProgressView setProgress:progress animated:progress > 0];
    }];
}

- (NSURL *)createLargeArchive {
    [self reportError:@""];

    // Create archive
    NSURL *archiveURL = self.largeArchiveURL;
    
    if (![archiveURL checkResourceIsReachableAndReturnError:nil]) {
        [self updateExtractionStep:@"Creating large text file…"];

        [self updateProgress:0];
        
        NSURL *largeFile = [self randomTextFileOfLength:100000000];
        
        if (!largeFile) {
            [self reportError:@"Failed to create large text file"];
            return nil;
        }
        
        [self updateProgress:0];

        [self updateExtractionStep:@"No archive"];
        [self reportError:
         @"The large archive has not been created yet. A Terminal command "
         "has been copied to the clipboard. Press ⌘V to paste it into a "
         "prompt in the UnrarKit source directory, paste it and run. Then "
         "click the button again"];
        
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = [NSString stringWithFormat:@"./Example/makeLargeArchive.sh \"%@\"", largeFile.path];

        return nil;
    }
    
    return archiveURL;
}

- (NSURL *)randomTextFileOfLength:(NSUInteger)numberOfCharacters {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *docsDir = [[fm URLsForDirectory:NSDocumentDirectory
                                 inDomains:NSUserDomainMask] firstObject];
    NSString *filename = [NSString stringWithFormat:@"long-random-str-%lu.txt", (unsigned long)numberOfCharacters];
    NSURL *fileURL = [docsDir URLByAppendingPathComponent:filename];
    
    if ([fileURL checkResourceIsReachableAndReturnError:nil]) {
        return fileURL;
    }
    
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 .,?!\n";
    NSUInteger letterCount = letters.length;
    
    NSMutableString *randomString = [NSMutableString stringWithCapacity:numberOfCharacters];
    
    for (NSUInteger i = 0; i < numberOfCharacters; i++) {
        uint32_t charIndex = arc4random_uniform((uint32_t)letterCount);
        [randomString appendFormat:@"%C", [letters characterAtIndex:charIndex]];
        
        if (i % 100 == 0) {
            float progress = i / (float)numberOfCharacters;
            [self updateProgress:progress];
        }
    }
    
    NSError *error = nil;
    if (![randomString writeToURL:fileURL atomically:YES encoding:NSUTF16StringEncoding error:&error]) {
        return nil;
    }
    
    return fileURL;
}


@end
