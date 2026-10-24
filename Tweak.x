#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "VCFrameEngine.h"

@interface VCMenuWindow : UIWindow
@end
@implementation VCMenuWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
        self.layer.cornerRadius = 15;
        self.clipsToBounds = YES;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(10, 10, 100, 40);
        [btn setTitle:@"关闭替换" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(toggleVCam) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:btn];
    }
    return self;
}
- (void)toggleVCam {
    [VCFrameEngine shared].isEnabled = ![VCFrameEngine shared].isEnabled;
    self.hidden = YES;
}
@end

static VCMenuWindow *menuWindow = nil;

@interface VCFrameInterceptor : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) id realDelegate;
@end
@implementation VCFrameInterceptor
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CMSampleBufferRef vBuf = [[VCFrameEngine shared] nextSampleBuffer];
    if (vBuf) {
        [self.realDelegate captureOutput:output didOutputSampleBuffer:vBuf fromConnection:connection];
        CFRelease(vBuf);
    } else {
        [self.realDelegate captureOutput:output didOutputSampleBuffer:sampleBuffer fromConnection:connection];
    }
}
@end

%hook AVCaptureVideoDataOutput
- (void)setSampleBufferDelegate:(id)delegate queue:(dispatch_queue_t)queue {
    if (!delegate) { %orig; return; }
    
    NSString *videoPath = @"/var/jb/var/mobile/Documents/vcam/video.mp4";
    if ([[NSFileManager defaultManager] fileExistsAtPath:videoPath]) {
        [[VCFrameEngine shared] loadVideoURL:[NSURL fileURLWithPath:videoPath]];
        [VCFrameEngine shared].isEnabled = YES;
    }
    
    VCFrameInterceptor *interceptor = [VCFrameInterceptor new];
    interceptor.realDelegate = delegate;
    %orig(interceptor, queue);
}
%end

%hook UIApplication
- (void)sendEvent:(UIEvent *)event {
    %orig;
    if (event.type == UIEventTypePresses) {
        if (!menuWindow) {
            menuWindow = [[VCMenuWindow alloc] initWithFrame:CGRectMake(50, 100, 200, 100)];
        }
        menuWindow.hidden = !menuWindow.hidden;
    }
}
%end
