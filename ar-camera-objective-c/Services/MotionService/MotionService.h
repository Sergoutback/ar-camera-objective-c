#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

NS_ASSUME_NONNULL_BEGIN

@interface MotionService : NSObject

@property (nonatomic, strong, readonly) CMDeviceMotion *currentMotion;

- (void)startMotionUpdates;
- (void)stopMotionUpdates;

@end

NS_ASSUME_NONNULL_END 