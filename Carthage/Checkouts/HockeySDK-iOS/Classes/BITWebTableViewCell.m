/*
 * Author: Andreas Linde <mail@andreaslinde.de>
 *         Peter Steinberger
 *
 * Copyright (c) 2012-2014 HockeyApp, Bit Stadium GmbH.
 * Copyright (c) 2011-2012 Peter Steinberger.
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 */

#import "HockeySDK.h"

#if HOCKEYSDK_FEATURE_UPDATES

#import "BITWebTableViewCell.h"

@implementation BITWebTableViewCell

static NSString* BITWebTableViewCellHtmlTemplate = @"\
<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\" \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">\
<html xmlns=\"http://www.w3.org/1999/xhtml\">\
<head>\
<style type=\"text/css\">\
body { font: 13px 'Helvetica Neue', Helvetica; color:#626262; word-wrap:break-word; padding:8px;} ul {padding-left: 18px;}\
</style>\
<meta name=\"viewport\" content=\"user-scalable=no width=%@\" /></head>\
<body>\
%@\
</body>\
</html>\
";


#pragma mark - private

- (void)addWebView {
  if(self.webViewContent) {
    CGRect webViewRect = CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
    if(!self.webView) {
      self.webView = [[UIWebView alloc] initWithFrame:webViewRect];
      [self addSubview:self.webView];
      self.webView.hidden = YES;
      self.webView.backgroundColor = self.cellBackgroundColor;
      self.webView.opaque = NO;
      self.webView.delegate = self;
      self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
      
      for(UIView* subView in self.webView.subviews){
        if([subView isKindOfClass:[UIScrollView class]]){
          // disable scrolling
          UIScrollView *sv = (UIScrollView *)subView;
          sv.scrollEnabled = NO;
          sv.bounces = NO;
          
          // hide shadow
          for (UIView* shadowView in [subView subviews]) {
            if ([shadowView isKindOfClass:[UIImageView class]]) {
              shadowView.hidden = YES;
            }
          }
        }
      }
    }
    else
      self.webView.frame = webViewRect;
    
    NSString *deviceWidth = [NSString stringWithFormat:@"%.0f", (double)CGRectGetWidth(self.bounds)];
    
    //HockeySDKLog(@"%@\n%@\%@", PSWebTableViewCellHtmlTemplate, deviceWidth, self.webViewContent);
    NSString *contentHtml = [NSString stringWithFormat:BITWebTableViewCellHtmlTemplate, deviceWidth, self.webViewContent];
    [self.webView loadHTMLString:contentHtml baseURL:[NSURL URLWithString:@"about:blank"]];
  }
}

- (void)showWebView {
  self.webView.hidden = NO;
  self.textLabel.text = @"";
  [self setNeedsDisplay];
}


- (void)removeWebView {
  if(self.webView) {
    self.webView.delegate = nil;
    [self.webView resignFirstResponder];
    [self.webView removeFromSuperview];
  }
  self.webView = nil;
  [self setNeedsDisplay];
}


- (void)setWebViewContent:(NSString *)aWebViewContent {
  if (_webViewContent != aWebViewContent) {
    _webViewContent = aWebViewContent;
    
    // add basic accessibility (prevents "snarfed from ivar layout") logs
    self.accessibilityLabel = aWebViewContent;
  }
}


#pragma mark - NSObject

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  if((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
    self.cellBackgroundColor = [UIColor clearColor];
  }
  return self;
}

- (void)dealloc {
  [self removeWebView];
}


#pragma mark - UIView

- (void)setFrame:(CGRect)aFrame {
  BOOL needChange = !CGRectEqualToRect(aFrame, self.frame);
  [super setFrame:aFrame];
  
  if (needChange) {
    [self addWebView];
  }
}


#pragma mark - UITableViewCell

- (void)prepareForReuse {
	[self removeWebView];
  self.webViewContent = nil;
	[super prepareForReuse];
}


#pragma mark - UIWebViewDelegate

- (BOOL)webView:(UIWebView *) __unused webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
  switch (navigationType) {
    case UIWebViewNavigationTypeLinkClicked:
      [self openURL:request.URL];
      return NO;
    case UIWebViewNavigationTypeOther:
      return YES;
    case UIWebViewNavigationTypeBackForward:
    case UIWebViewNavigationTypeFormResubmitted:
    case UIWebViewNavigationTypeFormSubmitted:
    case UIWebViewNavigationTypeReload:
      return NO;
  }
}

- (void)webViewDidFinishLoad:(UIWebView *) __unused webView {
  if(self.webViewContent)
    [self showWebView];
  
  CGRect frame = self.webView.frame;
  frame.size.height = 1;
  self.webView.frame = frame;
  CGSize fittingSize = [self.webView sizeThatFits:CGSizeZero];
  frame.size = fittingSize;
  self.webView.frame = frame;
  
  // sizeThatFits is not reliable - use javascript for optimal height
  NSString *output = [self.webView stringByEvaluatingJavaScriptFromString:@"document.body.scrollHeight;"];
  self.webViewSize = CGSizeMake(fittingSize.width, [output integerValue]);
}

#pragma mark - Helper

- (void)openURL:(NSURL *)URL {
  [[UIApplication sharedApplication] openURL:URL];
}

@end

#endif /* HOCKEYSDK_FEATURE_UPDATES */
