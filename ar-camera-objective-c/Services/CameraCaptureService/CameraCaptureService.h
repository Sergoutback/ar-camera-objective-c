#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface CameraCaptureService : NSObject

/// Capture a high-resolution photo (using AVCapturePhotoOutput).
/// The completion is called on the main queue.
- (void)captureHighResolutionPhoto:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END 
