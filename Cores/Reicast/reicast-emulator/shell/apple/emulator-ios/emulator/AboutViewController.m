//
//  AboutViewController.m
//  emulator
//
//  Created by Karen Tsai on 2014/3/5.
//  Copyright (c) 2014 Karen Tsai (angelXwind). All rights reserved.
//

#import "AboutViewController.h"
#import "SWRevealViewController.h"

@interface AboutViewController ()

@end

@implementation AboutViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"About";
    
    versionLabel.text = [NSBundle mainBundle].infoDictionary[@"GitVersionString"];
    
    // Set the side bar button action. When it's tapped, it'll show up the sidebar.
    _sidebarButton.target = self.revealViewController;
    _sidebarButton.action = @selector(revealToggle:);
    
    // Set the gesture
//    [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSArray *developerTwitters = @[@"angelXwind"/*, @"LoungeKatt"*/]; //@LoungeKatt is private, so not linking it to the About dialog.
    NSArray *githubframeworks = @[@"John-Lluch/SWRevealViewController"];
    if (indexPath.section == 0 && indexPath.row == 0) //@reicastdc twitter
    {
        NSURL *twitterURL = [NSURL URLWithString:[NSString stringWithFormat:@"twitter://user?screen_name=reicastdc"]];
        if ([[UIApplication sharedApplication] canOpenURL:twitterURL])
            [[UIApplication sharedApplication] openURL:twitterURL];
        else
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://twitter.com/reicastdc"]]];
    } else if (indexPath.section == 0 && indexPath.row == 1) //reicast github
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/reicast/reicast-emulator/"]]];
    } else if (indexPath.section == 1 && indexPath.row < developerTwitters.count) //developer twitter accounts
    {
        NSURL *twitterURL = [NSURL URLWithString:[NSString stringWithFormat:@"twitter://user?screen_name=%@", developerTwitters[indexPath.row]]];
        if ([[UIApplication sharedApplication] canOpenURL:twitterURL])
            [[UIApplication sharedApplication] openURL:twitterURL];
        else
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://twitter.com/%@", developerTwitters[indexPath.row]]]];
    } else if (indexPath.section == 2 && indexPath.row < githubframeworks.count) //third-party frameworks
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"https://github.com/%@", githubframeworks[indexPath.row]]]];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
