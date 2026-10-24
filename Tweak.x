#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import <PhotosUI/PhotosUI.h>
#import "VCFrameEngine.h"

// --- 悬浮窗 UI ---
@interface VCamWindow : UIWindow
@property (nonatomic, strong) UIButton *toggleBtn;
@end

@implementation VCamWindow
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.windowLevel = UIWindowLevelAlert + 1; // 保证盖在相机上面
        self.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
        self.layer.cornerRadius = 15;
        self.clipsToBounds = YES;
        
        // 开关按钮
        self.toggleBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        self.toggleBtn.frame = CGRectMake(10, 10, 120, 40);
        [self.toggleBtn setTitle:@"开启/关闭" forState:UIControlStateNormal];
        [self.toggleBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [self.toggleBtn addTarget:self action:@selector(toggleVCam) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.toggleBtn];
        
        // 选视频按钮
        UIButton *pickBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        pickBtn.frame = CGRectMake(10, 60, 120, 40);
        [pickBtn setTitle:@"从相册选择" forState:UIControlStateNormal];
        [pickBtn setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
        [pickBtn addTarget:self action:@selector(pickVideo) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:pickBtn];
    }
    return self;
}

- (void)toggleVCam {
    [VCFrameEngine shared].isEnabled = ![VCFrameEngine shared].isEnabled;
}

- (void)pickVideo {
    self.hidden = YES; // 隐藏窗口去选视频
    PHPickerConfiguration *config = [[PHPickerConfiguration alloc] init];
    config.filter = PHPickerFilter.videosFilter;
    PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
    picker.delegate = self;
    
    // 获取当前最顶层的 ViewController 来展示相册
    UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
    [rootVC presentViewController:picker animated:YES completion:nil];
}

// 选了视频之后
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (results.count > 0) {
        NSItemProvider *provider = results.firstObject.itemProvider;
        if ([provider hasItemConformingToTypeIdentifier:UTTypeMovie.identifier]) {
            [provider loadFileRepresentationForTypeIdentifier:UTTypeMovie.identifier completionHandler:^(NSURL *url, NSError *error) {
                if (url) {
                    // 将视频拷贝到我们插件的临时目录
                    NSString *destPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"vcam_video.mp4"];
                    NSURL *destURL = [NSURL fileURLWithPath:destPath];
                    [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
                    [[NSFileManager defaultManager] copyItemAtURL:url toURL:destURL error:nil];
                    
                    // 保存路径并加载
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

// --- 拦截器 ---
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

// --- 注入相机 ---
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
    
    // 初始化悬浮窗
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!menuWindow) {
            menuWindow = [[VCamWindow alloc] initWithFrame:CGRectMake(20, 150, 140, 110)];
        }
        menuWindow.hidden = NO;
    });
}
%end

// --- 拦截音量键 ---
%hook SBVolumeControl
- (void)increaseVolume {
    %orig;
    if (menuWindow) menuWindow.hidden = !menuWindow.hidden;
}
- (void)decreaseVolume {
    %orig;
    if (menuWindow) menuWindow.hidden = !menuWindow.hidden;
}
%end
