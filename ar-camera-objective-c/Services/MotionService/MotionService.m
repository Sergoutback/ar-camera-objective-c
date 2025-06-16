#import "MotionService.h"

@interface MotionService ()

@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) CMDeviceMotion *currentMotion;

@end

@implementation MotionService

- (instancetype)init {
    self = [super init];
    if (self) {
        _motionManager = [[CMMotionManager alloc] init];
        _motionManager.deviceMotionUpdateInterval = 0.1;
    }
    return self;
}

- (void)startMotionUpdates {
    if (self.motionManager.isDeviceMotionAvailable) {
        [self.motionManager startDeviceMotionUpdatesToQueue:[NSOperationQueue mainQueue]
                                               withHandler:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error getting motion updates: %@", error);
                return;
            }
            self.currentMotion = motion;
        }];
    }
}

- (void)stopMotionUpdates {
    [self.motionManager stopDeviceMotionUpdates];
}

- (void)getCurrentMotionWithCompletion:(void (^)(CMDeviceMotion * _Nullable, NSError * _Nullable))completion {
    if (self.currentMotion) {
        completion(self.currentMotion, nil);
    } else {
        NSError *error = [NSError errorWithDomain:@"MotionServiceErrorDomain"
                                           code:1
                                       userInfo:@{NSLocalizedDescriptionKey: @"No motion data available"}];
        completion(nil, error);
    }
}

@end 