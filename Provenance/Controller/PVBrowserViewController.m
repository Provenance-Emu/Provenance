//
//  PVBrowserViewController.m
//  Provenance
//
//  Created by David on 11/2/2013.
//  Copyright (c) 2013 James Addyman. All rights reserved.
//

#import "PVBrowserViewController.h"

@interface PVBrowserViewController () <UIWebViewDelegate>

@end

@implementation PVBrowserViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    
    UIWebView *webview = [[UIWebView alloc] initWithFrame:self.view.frame];
    webview.delegate = self;
    self.view = webview;
    
    NSURL *url = [NSURL URLWithString:@"http://coolrom.com/roms/genesis"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [webview loadRequest:request];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)done:(id)sender
{
	[[self presentingViewController] dismissViewControllerAnimated:YES completion:NULL];
}

#pragma mark - UIWebview delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // detect rom download
    if ([request.URL.host isEqualToString:@"dl.coolrom.com"])
    {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];

        [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            
            NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
            
            NSString *sourcePath = [request.URL path];
            NSString *filename = [sourcePath lastPathComponent];
            NSString *destinationPath = [documentsDirectory stringByAppendingPathComponent:filename];
            NSError *error = nil;
            
            BOOL success = [data writeToFile:destinationPath atomically:YES];
            
            if (!success || error)
            {
                NSLog(@"Unable to move file from %@ to %@ because %@", sourcePath, destinationPath, [error localizedDescription]);
            }
            
            [self done:nil];
            
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];

        }];
        
        return NO;
    }
    
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

@end
