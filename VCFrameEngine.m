#import "VCFrameEngine.h"

@interface VCFrameEngine () {
    AVAssetReader *_reader;
    AVAssetReaderTrackOutput *_readerOutput;
    NSURL *_videoURL;
    CVPixelBufferPoolRef _pool;
    CMVideoFormatDescriptionRef _formatDesc;
}
@end

@implementation VCFrameEngine

+ (instancetype)shared {
    static VCFrameEngine *inst;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ inst = [VCFrameEngine new]; });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSDictionary *attrs = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (id)kCVPixelBufferWidthKey: @(1080),
            (id)kCVPixelBufferHeightKey: @(1920)
        };
        CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef)attrs, &_pool);
        CVPixelBufferRef pb = NULL;
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pool, &pb);
        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pb, &_formatDesc);
        CVPixelBufferRelease(pb);
    }
    return self;
}

- (void)loadVideoURL:(NSURL *)url {
    _videoURL = url;
    [self rebuildReader];
}

- (void)rebuildReader {
    [_reader cancelReading];
    AVAsset *asset = [AVAsset assetWithURL:_videoURL];
    _reader = [AVAssetReader assetReaderWithAsset:asset error:nil];
    AVAssetTrack *track = [[asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (track) {
        _readerOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:track outputSettings:@{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)
        }];
        _readerOutput.alwaysCopiesSampleData = NO;
        [_reader addOutput:_readerOutput];
        [_reader startReading];
    }
}

- (CMSampleBufferRef)nextSampleBuffer CF_RETURNS_RETAINED {
    if (!_isEnabled || !_videoURL) return NULL;
    if (!_reader || _reader.status != AVAssetReaderStatusReading) {
        [self rebuildReader];
    }

    CMSampleBufferRef sb = [_readerOutput copyNextSampleBuffer];
    if (!sb) {
        [self rebuildReader];
        sb = [_readerOutput copyNextSampleBuffer];
        if (!sb) return NULL;
    }

    CVPixelBufferRef imgBuf = CMSampleBufferGetImageBuffer(sb);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imgBuf];
    
    if (_mirrorH) {
        ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeScale(-1, 1)];
        ciImage = [ciImage imageByApplyingTransform:CGAffineTransformMakeTranslation(1080, 0)];
    }

    CVPixelBufferRef newBuf = NULL;
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pool, &newBuf);
    
    static CIContext *context = nil;
    if (!context) context = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
    [context render:ciImage toCVPixelBuffer:newBuf];

    CMSampleTimingInfo timing = { .duration = CMTimeMake(1, 30), .presentationTimeStamp = CMClockGetTime(CMClockGetHostTimeClock()), .decodeTimeStamp = kCMTimeInvalid };
    CMSampleBufferRef finalSb = NULL;
    CMSampleBufferCreateReadyWithImageBuffer(kCFAllocatorDefault, newBuf, _formatDesc, &timing, &finalSb);
    
    CVPixelBufferRelease(newBuf);
    CFRelease(sb);
    return finalSb;
}
@end
