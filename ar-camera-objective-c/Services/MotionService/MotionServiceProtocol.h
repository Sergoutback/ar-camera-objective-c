#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MotionServiceProtocol <NSObject>

@property (nonatomic, strong, readonly) CMMotionManager *motionManager;
@property (nonatomic, strong, readonly) CMDeviceMotion *currentMotion;

- (void)startMotionUpdates;
- (void)stopMotionUpdates;
- (void)getCurrentMotionWithCompletion:(void (^)(CMDeviceMotion * _Nullable motion, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END 