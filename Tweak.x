#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import <objc/runtime.h>
#import "VCFrameEngine.h"

@interface VCamWindow : UIWindow
@property (nonatomic, strong) UIButton *toggleBtn;
@property (nonatomic, strong) UIButton *mirrorBtn;
@end

@interface VCamWindow () <PHPickerViewControllerDelegate>
@end

@implementation VCamWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1;
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.85];
        self.layer.cornerRadius = 15;
        self.clipsToBounds = YES;
        
        self.toggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        self.toggleBtn.frame = CGRectMake(10, 10, 120, 30);
        [self.toggleBtn setTitle:@"开关替换" forState:UIControlStateNormal];
        [self.toggleBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [self.toggleBtn addTarget:self action:@selector(toggleVCam) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.toggleBtn];
        
        UIButton *pickBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        pickBtn.frame = CGRectMake(10, 45, 120, 30);
        [pickBtn setTitle:@"选择视频" forState:UIControlStateNormal];
        [pickBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
        [pickBtn addTarget:self action:@selector(pickVideo) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:pickBtn];
        
        self.mirrorBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        self.mirrorBtn.frame = CGRectMake(10, 80, 120, 30);
        [self.mirrorBtn setTitle:@"开启镜像" forState:UIControlStateNormal];
        [self.mirrorBtn setTitleColor:[UIColor yellowColor] forState:UIControlStateNormal];
        [self.mirrorBtn addTarget:self action:@selector(toggleMirror) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.mirrorBtn];
    }
    return self;
}

- (void)toggleVCam {
    [VCFrameEngine shared].isEnabled = ![VCFrameEngine shared].isEnabled;
}

- (void)toggleMirror {
    [VCFrameEngine shared].mirrorH = ![VCFrameEngine shared].mirrorH;
    [self.mirrorBtn setTitle:[VCFrameEngine shared].mirrorH ? @"关闭镜像" : @"开启镜像" forState:UIControlStateNormal];
}

- (UIViewController *)getTopViewController {
    Class appClass = objc_getClass("UIApplication");
    id app = ((id (*)(id, SEL))objc_msgSend)((id)appClass, sel_registerName("sharedApplication"));
    id window = ((id (*)(id, SEL))objc_msgSend)(app, sel_registerName("keyWindow"));
    if (!window) {
        NSArray *windows = ((NSArray * (*)(id, SEL))objc_msgSend)(app, sel_registerName("windows"));
        if (windows.count > 0) window = windows.firstObject;
    }
    UIViewController *vc = ((UIViewController * (*)(id, SEL))objc_msgSend)(window, sel_registerName("rootViewController"));
    while (vc.presentedViewController) {
        vc = vc.presentedViewController;
    }
    return vc;
}

- (void)pickVideo {
    self.hidden = YES;
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = PHPickerFilter.videosFilter;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = (id<PHPickerViewControllerDelegate>)self;
    [[self getTopViewController] presentViewController:picker animated:YES completion:nil];
}

- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count > 0) {
        NSItemProvider *provider = results.firstObject.itemProvider;
        if ([provider hasItemConformingToTypeIdentifier:@"public.movie"]) {
            [provider loadFileRepresentationForTypeIdentifier:@"public.movie" completionHandler:^(NSURL *url, NSError *error) {
                if (url) {
                    NSString *destPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"vcam_video.mp4"];
                    NSURL *destURL = [NSURL fileURLWithPath:destPath];
                    [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
                    [[NSFileManager defaultManager] copyItemAtURL:url toURL:destURL error:nil];
                    
                    [[NSUserDefaults standardUserDefaults] setObject:destPath forKey:@"VCamVideoPath"];
                    [[NSUserDefaults standardUserDefaults] synchronize];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[VCFrameEngine shared] loadVideoURL:destURL];
                        [VCFrameEngine shared].isEnabled = YES;
                    });
                }
            }];
        }
    }
    self.hidden = NO;
}
@end

static VCamWindow *menuWindow = nil;

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
    if (!delegate) { %orig; return; }
    
    NSString *savedPath = [[NSUserDefaults standardUserDefaults] objectForKey:@"VCamVideoPath"];
    if (savedPath && [[NSFileManager defaultManager] fileExistsAtPath:savedPath]) {
        [[VCFrameEngine shared] loadVideoURL:[NSURL fileURLWithPath:savedPath]];
        [VCFrameEngine shared].isEnabled = YES;
    }
    
    VCFrameInterceptor *interceptor = [VCFrameInterceptor new];
    interceptor.realDelegate = delegate;
    %orig(interceptor, queue);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!menuWindow) {
            menuWindow = [[VCamWindow alloc] initWithFrame:CGRectMake(20, 100, 140, 120)];
        }
        menuWindow.hidden = NO;
    });
}
%end
