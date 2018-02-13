//
//  PVLicensesViewController.m
//  Provenance
//
//  Created by Marcel Voß on 20.09.16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVLicensesViewController.h"

@implementation PVLicensesViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"Acknowledgements";
    
    NSString *filesystemPath = [[NSBundle mainBundle] pathForResource:@"licenses" ofType:@"html"];
    NSString *htmlContent = [[NSString alloc] initWithContentsOfFile:filesystemPath encoding:NSUTF8StringEncoding error:nil];
    
    UIWebView *webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [webView loadHTMLString:htmlContent baseURL:nil];
    webView.scalesPageToFit = NO;
    webView.scrollView.bounces = NO;
    webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    [self.view addSubview:webView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
