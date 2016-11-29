//
//  PVConflictViewController.m
//  Provenance
//
//  Created by James Addyman on 17/04/2015.
//  Copyright (c) 2015 James Addyman. All rights reserved.
//

#import "PVConflictViewController.h"
#import "PVGameImporter.h"
#import "PVEmulatorConfiguration.h"

@interface PVConflictViewController ()

@property (nonatomic, strong) PVGameImporter *gameImporter;
@property (nonatomic, strong) NSArray *conflictedFiles;

@end

@implementation PVConflictViewController

- (instancetype)initWithGameImporter:(PVGameImporter *)gameImporter
{
    if ((self = [super initWithStyle:UITableViewStylePlain]))
    {
        self.gameImporter = gameImporter;
    }
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

#if TARGET_OS_TV
    self.splitViewController.title = @"Solve Conflicts";
#else
    self.title = @"Solve Conflicts";

    if (![[self conflictedFiles] count]) {
        self.tableView.separatorColor = [UIColor clearColor];
    }
#endif
    [self updateConflictedFiles];
}

- (void)updateConflictedFiles
{
    NSMutableArray *tempConflictedFiles = [NSMutableArray array];
    for (NSString *file in [self.gameImporter conflictedFiles])
    {
        NSString *extension = [file pathExtension];
        if ([[[PVEmulatorConfiguration sharedInstance] systemIdentifiersForFileExtension:[extension lowercaseString]] count] > 1)
        {
            [tempConflictedFiles addObject:file];
        }
    }
    
    self.conflictedFiles = [tempConflictedFiles copy];
}

- (NSString *)documentsPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return documentsDirectoryPath;
}

- (NSString *)conflictsPath
{
#if TARGET_OS_TV
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
#else
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
#endif
    NSString *documentsDirectoryPath = [paths objectAtIndex:0];
    
    return [documentsDirectoryPath stringByAppendingPathComponent:@"conflicts"];
}

#if TARGET_OS_TV
- (BOOL)tableView:(UITableView *)tableView canFocusRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![self.conflictedFiles count])
    {
        if ([indexPath row] == 2) {
            return YES;
        }
        
        return NO;
    }

    return YES;
}
#endif

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([self.conflictedFiles count])
    {
        return [self.conflictedFiles count];
    }

    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![self.conflictedFiles count])
    {

        UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"EmptyCell"];
        if (!cell)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }

        cell.textLabel.textAlignment = NSTextAlignmentCenter;

        if ([indexPath row] == 0 || [indexPath row] == 1)
        {
            cell.textLabel.text = @"";
        }
        else
        {
            cell.textLabel.text = @"No Conflicts...";
        }

        return cell;
    }

    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    NSString *file = self.conflictedFiles[[indexPath row]];
    NSString *name = [[file lastPathComponent] stringByReplacingOccurrencesOfString:[@"." stringByAppendingString:[file pathExtension]] withString:@""];
    
    [[cell textLabel] setText:name];
    [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];

    if (![self.conflictedFiles count])
    {
        return;
    }

    NSString *path = self.conflictedFiles[[indexPath row]];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Choose a System"
                                                                             message:nil
                                                                      preferredStyle:UIAlertControllerStyleActionSheet];
    [[alertController popoverPresentationController] setSourceView:self.view];
    [[alertController popoverPresentationController] setSourceRect:[self.tableView rectForRowAtIndexPath:indexPath]];
    
    for (NSString *systemID in [[PVEmulatorConfiguration sharedInstance] availableSystemIdentifiers])
    {
        NSArray *supportedExtensions = [[PVEmulatorConfiguration sharedInstance] fileExtensionsForSystemIdentifier:systemID];
        if ([supportedExtensions containsObject:[path pathExtension]])
        {
            NSString *name = [[PVEmulatorConfiguration sharedInstance] shortNameForSystemIdentifier:systemID];
            [alertController addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self.gameImporter resolveConflictsWithSolutions:@{path: systemID}];
                [self.tableView beginUpdates];
                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationTop];
                [self updateConflictedFiles];
                [self.tableView endUpdates];
            }]];
        }
    }
    
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:NULL]];
    [self presentViewController:alertController animated:YES completion:NULL];
}

@end
