//
//  PVLicensesViewController.m
//  Provenance
//
//  Created by Marcel Voß on 20.09.16.
//  Copyright © 2016 James Addyman. All rights reserved.
//

#import "PVLicensesViewController.h"

@interface PVLicensesViewController ()

@property (nonatomic) UIWebView *webView;

@end

@implementation PVLicensesViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    self.title = @"Acknowledgements";
    
    NSString *filesystemPath = [[NSBundle mainBundle] pathForResource:@"licenses" ofType:@"html"];
    NSString *htmlContent = [[NSString alloc] initWithContentsOfFile:filesystemPath encoding:NSUTF8StringEncoding error:nil];
    
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [self.webView loadHTMLString:htmlContent baseURL:nil];
    self.webView.scalesPageToFit = NO;
    self.webView.scrollView.bounces = NO;
    self.webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    [self.view addSubview:self.webView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
