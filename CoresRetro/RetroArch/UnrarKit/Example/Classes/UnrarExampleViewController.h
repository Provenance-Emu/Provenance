//
//  UnrarExampleViewController.h
//  UnrarExample
//
//

#import <UIKit/UIKit.h>

@interface UnrarExampleViewController : UIViewController


@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UITextView *fileListTextView;

@property (weak, nonatomic) IBOutlet UILabel *extractionStepLabel;
@property (weak, nonatomic) IBOutlet UIProgressView *extractionProgressView;


- (IBAction)listFiles:(id)sender;
- (IBAction)extractLargeFile:(id)sender;
- (IBAction)cancelExtraction:(id)sender;

@end

