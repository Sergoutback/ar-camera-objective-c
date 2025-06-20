#import "ARCameraViewModel.h"
#import "../Services/ARService/ARServiceProtocol.h"
#import <simd/simd.h>
#import <ARKit/ARKit.h>
#import <UIKit/UIKit.h>

@interface ARCameraViewModel ()

@property (nonatomic, strong) id<ARServiceProtocol> arService;
@property (nonatomic, strong) MotionService *motionService;
@property (nonatomic, strong) LocationService *locationService;
@property (nonatomic, strong) PhotoService *photoService;
@property (nonatomic, strong) ARSpaceService *spaceService;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *photoMetaArray;
@property (nonatomic, assign) NSInteger photoCount;

@end

// Helper to rotate UIImage 90° counter-clockwise (portrait upright)
static UIImage *RotateImagePortrait(UIImage *image) {
    CGSize size = CGSizeMake(image.size.height, image.size.width);
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(ctx, size.width / 2.0, size.height / 2.0);
    CGContextRotateCTM(ctx, M_PI_2);
    CGContextTranslateCTM(ctx, -image.size.width / 2.0, -image.size.height / 2.0);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *rotated = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return rotated;
}

@implementation ARCameraViewModel

- (instancetype)initWithARService:(id<ARServiceProtocol>)arService
                    motionService:(MotionService *)motionService
                  locationService:(LocationService *)locationService {
    PhotoService *defaultPhotoService = [[PhotoService alloc] init];
    ARSpaceService *defaultSpaceService = nil;
    if (arService.sceneView) {
        defaultSpaceService = [[ARSpaceService alloc] initWithSceneView:arService.sceneView];
    } else {
        ARSCNView *dummyView = [[ARSCNView alloc] initWithFrame:CGRectZero];
        defaultSpaceService = [[ARSpaceService alloc] initWithSceneView:dummyView];
    }
    return [self initWithARService:arService
                      motionService:motionService
                    locationService:locationService
                      photoService:defaultPhotoService
                      spaceService:defaultSpaceService];
}

- (instancetype)initWithARService:(id<ARServiceProtocol>)arService
                    motionService:(MotionService *)motionService
                  locationService:(LocationService *)locationService
                    photoService:(PhotoService *)photoService
                    spaceService:(ARSpaceService *)spaceService {
    self = [super init];
    if (self) {
        _arService = arService;
        _motionService = motionService;
        _locationService = locationService;
        _photoService = photoService;
        _spaceService = spaceService;
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

- (void)resetSession {
    [self.arService resetARSession];
    [self.photoMetaArray removeAllObjects];
    self.photoCount = 0;
}

- (void)capturePhotoWithCompletion:(void (^)(PhotoPosition * _Nullable photoPosition, NSError * _Nullable error))completion {
    [self.arService capturePhotoWithCompletion:^(UIImage * _Nullable image, NSError * _Nullable error) {
        if (error) {
            if (completion) {
                completion(nil, error);
            }
            return;
        }
        
        if (image) {
            // Get current camera position relative to initial anchor
            matrix_float4x4 cameraTransform = [self.arService currentCameraTransform];
            simd_float3 eulerAngles = [self.arService currentCameraEulerAngles];
            // Формируем photoId: Photo_<номер>_<yyyyMMdd_HHmmss>
            NSInteger photoNumber = self.photoCount + 1;
            NSDateFormatter *df = [[NSDateFormatter alloc] init];
            df.dateFormat = @"yyyyMMdd_HHmmss";
            NSString *dateStr = [df stringFromDate:[NSDate date]];
            NSString *photoId = [NSString stringWithFormat:@"Photo_%ld_%@", (long)photoNumber, dateStr];
            PhotoPosition *photoPosition = [[PhotoPosition alloc] initWithPhotoId:photoId
                                                                relativePosition:SCNVector3Make(cameraTransform.columns[3].x,
                                                                                               cameraTransform.columns[3].y,
                                                                                               cameraTransform.columns[3].z)
                                                              relativeEulerAngles:SCNVector3Make(eulerAngles.x,
                                                                                                eulerAngles.y,
                                                                                                eulerAngles.z)
                                                                      thumbnail:image];
            // Сохраняем PNG-файл
            UIImage *exportImage = RotateImagePortrait(image);
            NSData *pngData = UIImagePNGRepresentation(exportImage);
            NSString *fileName = [NSString stringWithFormat:@"%@.png", photoId];
            NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
            NSString *filePath = [cacheDir stringByAppendingPathComponent:fileName];
            [pngData writeToFile:filePath atomically:YES];
            photoPosition.imagePath = filePath;
            self.photoCount++;
            if (completion) {
                completion(photoPosition, nil);
            }
        }
    }];
}

@end 