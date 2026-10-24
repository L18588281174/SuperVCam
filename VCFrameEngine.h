#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@interface VCFrameEngine : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL mirrorH;
- (void)loadVideoURL:(NSURL *)url;
- (CMSampleBufferRef)nextSampleBuffer CF_RETURNS_RETAINED;
@end
