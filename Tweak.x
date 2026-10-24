#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "VCFrameEngine.h"

@interface VCFrameInterceptor : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, weak) id<AVCaptureVideoDataOutputSampleBufferDelegate> realDelegate;
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
- (void)setSampleBufferDelegate:(id<AVCaptureVideoDataOutputSampleBufferDelegate>)delegate queue:(dispatch_queue_t)queue {
    if (!delegate) { 
        %orig; 
        return; 
    }
    
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
