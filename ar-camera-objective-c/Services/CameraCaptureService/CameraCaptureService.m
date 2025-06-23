#import "CameraCaptureService.h"
#import <AVFoundation/AVFoundation.h>

@interface CameraCaptureService () <AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, copy) void (^completionHandler)(UIImage * _Nullable, NSError * _Nullable);
@end

@implementation CameraCaptureService

- (void)captureHighResolutionPhoto:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion {
    // Store completion
    self.completionHandler = completion;
    // Always use a dedicated photo session (simpler and ensures ≤12 MP on 48 MP sensors)
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetPhoto;
    // Select back wide-angle camera
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if (!device) {
        if (completion) {
            completion(nil, [NSError errorWithDomain:@"CameraCaptureService" code:0 userInfo:@{NSLocalizedDescriptionKey:@"No camera device"}]);
        }
        return;
    }
    NSError *error = nil;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input || error) {
        if (completion) { completion(nil, error); }
        return;
    }
    if ([self.session canAddInput:input]) {
        [self.session addInput:input];
    }
    self.photoOutput = [[AVCapturePhotoOutput alloc] init];
    self.photoOutput.highResolutionCaptureEnabled = YES;
    if ([self.session canAddOutput:self.photoOutput]) {
        [self.session addOutput:self.photoOutput];
    }
    // Choose the highest resolution ≤ 12 MP to save memory and storage (≈4000×3000)
    const int64_t kMaxPixels = 12192768; // 12 MP
    CMVideoDimensions bestDimensions = (CMVideoDimensions){0,0};
    AVCaptureDeviceFormat *bestFormat = nil;
    for (AVCaptureDeviceFormat *format in device.formats) {
        // Use base format dimensions to estimate JPEG output size (highRes dims are always large on iPhone 15 Pro)
        CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        if (dims.width == 0 || dims.height == 0) { continue; }

        int64_t pixels = (int64_t)dims.width * (int64_t)dims.height;
        if (pixels > kMaxPixels) { continue; } // skip very large (e.g., 48 MP)

        int64_t bestPixels = (int64_t)bestDimensions.width * (int64_t)bestDimensions.height;
        if (pixels > bestPixels) {
            bestDimensions = dims;
            bestFormat = format;
        }
    }
    // If nothing ≤12 MP found (unlikely), fall back to previous highest resolution
    if (!bestFormat) {
        for (AVCaptureDeviceFormat *format in device.formats) {
            CMVideoDimensions dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            int64_t pixels = (int64_t)dims.width * (int64_t)dims.height;
            int64_t bestPixels = (int64_t)bestDimensions.width * (int64_t)bestDimensions.height;
            if (pixels > bestPixels) {
                bestDimensions = dims;
                bestFormat = format;
            }
        }
    }
    if (bestFormat) {
        NSError *fmtErr = nil;
        if ([device lockForConfiguration:&fmtErr]) {
            device.activeFormat = bestFormat;
            // Max out resolution for still capture if supported
            device.activeVideoMinFrameDuration = CMTimeMake(1, 30);
            device.activeVideoMaxFrameDuration = CMTimeMake(1, 30);
            [device unlockForConfiguration];
        } else {
            NSLog(@"Camera format lock error: %@", fmtErr);
        }
    }
    // Start session
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self.session startRunning];
        // Wait small delay to allow exposure to settle
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            AVCapturePhotoSettings *settings = [AVCapturePhotoSettings photoSettings];
            settings.highResolutionPhotoEnabled = NO; // capture at sensor default (≈12 MP)
            if (@available(iOS 15.0, *)) {
                settings.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationSpeed;
            }
            if ([self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeHEVC]) {
                settings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecTypeHEVC}];
                settings.highResolutionPhotoEnabled = NO;
                if (@available(iOS 15.0, *)) {
                    settings.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationSpeed;
                }
            }
            [self.photoOutput capturePhotoWithSettings:settings delegate:self];
        });
    });
}

#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    UIImage *image = nil;
    if (!error) {
        NSData *data = [photo fileDataRepresentation];
        if (data) {
            image = [UIImage imageWithData:data];
        }
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        // Stop session first to release camera resources for ARKit.
        [self.session stopRunning];
        self.session = nil;
        self.photoOutput = nil;
        if (self.completionHandler) {
            self.completionHandler(image, error);
        }
        self.completionHandler = nil;
    });
}

@end 
