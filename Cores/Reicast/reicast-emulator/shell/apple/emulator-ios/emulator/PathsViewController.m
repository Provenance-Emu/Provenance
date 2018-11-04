//
//  PathsViewController.m
//  emulator
//
//  Created by Karen Tsai on 2014/3/5.
//  Copyright (c) 2014 Karen Tsai (angelXwind). All rights reserved.
//

#import "PathsViewController.h"
//#import "SWRevealViewController.h"
#import "EmulatorViewController.h"
#import "DiskViewCell.h"

@interface PathsViewController ()

@end

@implementation PathsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}
- (IBAction)refreshTapped:(id)sender {
	[self updateDiskImages];
}

- (NSURL *)documents
{
#if TARGET_OS_TV
//	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	return [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
#else
	return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];
#endif
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Paths";
    
    // Set the side bar button action. When it's tapped, it'll show up the sidebar.
//    _sidebarButton.target = self.revealViewController;
//    _sidebarButton.action = @selector(revealToggle:);

    // Set the gesture
//    [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	[self updateDiskImages];
}

- (void)updateDiskImages {
	self.diskImages = [[NSMutableArray alloc] init];
	NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[self documents].path error:NULL];
	NSPredicate *diskPredicate = [NSPredicate predicateWithFormat:@"self ENDSWITH '.chd' || self ENDSWITH '.gdi' || self ENDSWITH '.cdi' || self ENDSWITH '.CHD' || self ENDSWITH '.GDI' || self ENDSWITH '.CDI'"];
	self.diskImages = [NSMutableArray arrayWithArray:[files filteredArrayUsingPredicate:diskPredicate]];

	NSLog(@"Put files in %@", [self documents].path);
	[self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

-(NSInteger)numberOfSectionsInTableView: (UITableView*)tableView
{
	return 1;
}

-(NSInteger)tableView: (UITableView *)tableView numberOfRowsInSection: (NSInteger)section
{
	return [self.diskImages count];
}

-(NSString*)tableView: (UITableView*)tableView titleForHeaderInSection: (NSInteger)section
{
	return @"";
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	return 80;
	// Assign the specific cell height to prevent issues with custom size
}

-(UITableViewCell*)tableView: (UITableView*)tableView cellForRowAtIndexPath: (NSIndexPath*)indexPath
{
	static NSString *CellIdentifier = @"Cell";
	
	DiskViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
	NSString* imagePath = [self.diskImages objectAtIndex: indexPath.row];
	
	cell.nameLabel.text = [[imagePath lastPathComponent] stringByDeletingPathExtension];
	
	return cell;
}

-(void)prepareForSegue: (UIStoryboardSegue*)segue sender: (id)sender
{
	if ([segue.identifier isEqualToString:@"emulatorView"]) {
		NSIndexPath* indexPath = self.tableView.indexPathForSelectedRow;
		NSString* filePath = [self.diskImages objectAtIndex: indexPath.row];
		NSString* diskPath = [[self documents].path stringByAppendingPathComponent: filePath];
		EmulatorViewController* emulatorView = segue.destinationViewController;
		emulatorView.diskImage = diskPath;
	}
}

-(void)tableView: (UITableView*)tableView didSelectRowAtIndexPath: (NSIndexPath*)indexPath
{
	[self performSegueWithIdentifier: @"emulatorView" sender: self];
}

@end
