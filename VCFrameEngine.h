#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface VCFrameEngine : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL isEnabled;
@property (nonatomic, assign) BOOL mirrorH;
@property (nonatomic, assign) BOOL rotate90;
- (void)loadVideoURL:(NSURL *)url;
- (CMSampleBufferRef)nextSampleBuffer CF_RETURNS_RETAINED;
@end
