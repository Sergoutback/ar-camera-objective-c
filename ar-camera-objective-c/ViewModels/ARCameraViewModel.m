#import "ARCameraViewModel.h"
#import "../Services/ARService/ARServiceProtocol.h"
#import <simd/simd.h>

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
                
                // ARKit metadata
                simd_float4x4 transform = [self.arService currentCameraTransform];
                matrix_float3x3 intrinsics = [self.arService currentCameraIntrinsics];
                simd_float3 eulerAngles = [self.arService currentCameraEulerAngles];
                NSTimeInterval arTimestamp = [self.arService currentFrameTimestamp];
                
                metadata[@"arTransform"] = @[@[@(transform.columns[0][0]), @(transform.columns[0][1]), @(transform.columns[0][2]), @(transform.columns[0][3])],
                                               @[@(transform.columns[1][0]), @(transform.columns[1][1]), @(transform.columns[1][2]), @(transform.columns[1][3])],
                                               @[@(transform.columns[2][0]), @(transform.columns[2][1]), @(transform.columns[2][2]), @(transform.columns[2][3])],
                                               @[@(transform.columns[3][0]), @(transform.columns[3][1]), @(transform.columns[3][2]), @(transform.columns[3][3])]];
                metadata[@"arIntrinsics"] = @[@[@(intrinsics.columns[0][0]), @(intrinsics.columns[0][1]), @(intrinsics.columns[0][2])],
                                                @[@(intrinsics.columns[1][0]), @(intrinsics.columns[1][1]), @(intrinsics.columns[1][2])],
                                                @[@(intrinsics.columns[2][0]), @(intrinsics.columns[2][1]), @(intrinsics.columns[2][2])]];
                metadata[@"arEulerAngles"] = @[@(eulerAngles.x), @(eulerAngles.y), @(eulerAngles.z)];
                metadata[@"arTimestamp"] = @(arTimestamp);
                
                // Motion metadata
                if (motion) {
                    metadata[@"gyroRotationRate"] = @[@(motion.rotationRate.x), @(motion.rotationRate.y), @(motion.rotationRate.z)];
                    metadata[@"gyroAttitude"] = @[@(motion.attitude.pitch), @(motion.attitude.roll), @(motion.attitude.yaw)];
                } else {
                    metadata[@"gyroRotationRate"] = [NSNull null];
                    metadata[@"gyroAttitude"] = [NSNull null];
                }
                
                // Location metadata
                if (location) {
                    metadata[@"latitude"] = @(location.coordinate.latitude);
                    metadata[@"longitude"] = @(location.coordinate.longitude);
                    metadata[@"altitude"] = @(location.altitude);
                } else {
                    metadata[@"latitude"] = [NSNull null];
                    metadata[@"longitude"] = [NSNull null];
                    metadata[@"altitude"] = [NSNull null];
                }
                
                // Timestamp
                metadata[@"timestamp"] = @([[NSDate date] timeIntervalSince1970]);
                
                // Остальные поля для совместимости
                metadata[@"relativeGyroAttitude"] = [NSNull null];
                metadata[@"relativeEulerAngles"] = [NSNull null];
                metadata[@"relativePosition"] = [NSNull null];
                metadata[@"gyroEulerAngles"] = [NSNull null];
                metadata[@"focalLength"] = [NSNull null];
                metadata[@"sensorSize"] = [NSNull null];
                metadata[@"resolution"] = [NSNull null];
                metadata[@"principalPoint"] = [NSNull null];
                
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