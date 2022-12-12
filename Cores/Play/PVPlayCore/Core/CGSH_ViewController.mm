#import "CGSH_ViewController.h"
#import "PVPlayCore.h"

@implementation CGSH_ViewController
-(void)viewDidLoad {
 	[super viewDidLoad];
 	self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
 	if (!self.context) {
 	 	ELOG(@"Failed to create ES context");
 	}
 	GLKView *view = (GLKView *)self.view;
 	view.context = self.context;
 	view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
 	view.drawableMultisample = GLKViewDrawableMultisample4X;
 	view.userInteractionEnabled = NO;
 	view.opaque=YES;
 	view.layer.opaque=YES;
 	view.enableSetNeedsDisplay=NO;
 	auto screenBounds = [[UIScreen mainScreen] bounds];
	float scale = [[UIScreen mainScreen] scale];
	if (scale != 1.0f) {
		view.layer.contentsScale = scale;
 	 	view.layer.rasterizationScale = scale;
 	 	view.contentScaleFactor = scale;
	}
 	CAEAGLLayer *m_layer = (CAEAGLLayer *)view.layer;
 	m_layer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:FALSE],
		kEAGLDrawablePropertyRetainedBacking,
		kEAGLColorFormatRGBA8,
		kEAGLDrawablePropertyColorFormat,
		nil
	];
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
}

@end
