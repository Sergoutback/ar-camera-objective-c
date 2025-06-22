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
    // Setup capture session
    self.session = [[AVCaptureSession alloc] init];
    self.session.sessionPreset = AVCaptureSessionPresetInputPriority;
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
    // Select the format with the largest High-Res still dimensions (≈48/50 MP on modern devices)
    CMVideoDimensions bestDimensions = (CMVideoDimensions){0,0};
    AVCaptureDeviceFormat *bestFormat = nil;
    for (AVCaptureDeviceFormat *format in device.formats) {
        CMVideoDimensions dims = format.highResolutionStillImageDimensions;
        int64_t pixels = (int64_t)dims.width * (int64_t)dims.height;
        int64_t bestPixels = (int64_t)bestDimensions.width * (int64_t)bestDimensions.height;
        if (pixels > bestPixels) {
            bestDimensions = dims;
            bestFormat = format;
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
            settings.highResolutionPhotoEnabled = YES;
            if (@available(iOS 15.0, *)) {
                AVCapturePhotoQualityPrioritization maxQ = self.photoOutput.maxPhotoQualityPrioritization;
                settings.photoQualityPrioritization = (maxQ >= AVCapturePhotoQualityPrioritizationQuality) ? AVCapturePhotoQualityPrioritizationQuality : maxQ;
            }
            if ([self.photoOutput.availablePhotoCodecTypes containsObject:AVVideoCodecTypeHEVC]) {
                settings = [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey: AVVideoCodecTypeHEVC}];
                settings.highResolutionPhotoEnabled = YES;
                if (@available(iOS 15.0, *)) {
                    AVCapturePhotoQualityPrioritization maxQ = self.photoOutput.maxPhotoQualityPrioritization;
                    settings.photoQualityPrioritization = (maxQ >= AVCapturePhotoQualityPrioritizationQuality) ? AVCapturePhotoQualityPrioritizationQuality : maxQ;
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