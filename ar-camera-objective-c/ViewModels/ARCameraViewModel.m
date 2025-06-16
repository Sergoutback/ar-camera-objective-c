#import "ARCameraViewModel.h"

@interface ARCameraViewModel ()

@property (nonatomic, strong) id<ARServiceProtocol> arService;
@property (nonatomic, strong) id<MotionServiceProtocol> motionService;
@property (nonatomic, strong) id<LocationServiceProtocol> locationService;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *photoMetaArray;
@property (nonatomic, assign) NSInteger photoCount;

@end

@implementation ARCameraViewModel

- (instancetype)initWithARService:(id<ARServiceProtocol>)arService
                    motionService:(id<MotionServiceProtocol>)motionService
                  locationService:(id<LocationServiceProtocol>)locationService {
    self = [super init];
    if (self) {
        _arService = arService;
        _motionService = motionService;
        _locationService = locationService;
        _photoMetaArray = [NSMutableArray array];
        _photoCount = 0;
    }
    return self;
}

- (void)startServices {
    [self.arService startARSession];
    [self.motionService startMotionUpdates];
    [self.locationService startLocationUpdates];
}

- (void)stopServices {
    [self.arService pauseARSession];
    [self.motionService stopMotionUpdates];
    [self.locationService stopLocationUpdates];
}

- (void)capturePhotoWithCompletion:(void (^)(UIImage * _Nullable, NSDictionary * _Nullable, NSError * _Nullable))completion {
    [self.arService capturePhotoWithCompletion:^(UIImage * _Nullable image, NSError * _Nullable error) {
        if (error) {
            completion(nil, nil, error);
            return;
        }
        
        [self.motionService getCurrentMotionWithCompletion:^(CMDeviceMotion * _Nullable motion, NSError * _Nullable motionError) {
            [self.locationService getCurrentLocationWithCompletion:^(CLLocation * _Nullable location, NSError * _Nullable locationError) {
                
                NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
                
                if (motion) {
                    metadata[@"motion"] = @{
                        @"attitude": @{
                            @"pitch": @(motion.attitude.pitch),
                            @"roll": @(motion.attitude.roll),
                            @"yaw": @(motion.attitude.yaw)
                        }
                    };
                }
                
                if (location) {
                    metadata[@"location"] = @{
                        @"latitude": @(location.coordinate.latitude),
                        @"longitude": @(location.coordinate.longitude),
                        @"altitude": @(location.altitude),
                        @"timestamp": location.timestamp
                    };
                }
                
                [self.photoMetaArray addObject:metadata];
                self.photoCount++;
                
                completion(image, metadata, nil);
            }];
        }];
    }];
}

- (void)resetSession {
    [self.arService resetARSession];
    self.photoCount = 0;
    [self.photoMetaArray removeAllObjects];
}

@end 