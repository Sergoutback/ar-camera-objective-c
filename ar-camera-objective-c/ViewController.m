//
//  ViewController.m
//  ar-camera-objective-c
//
//  Created by Mac on 14.06.25.
//

#import "ViewController.h"
#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>


@interface ViewController () <ARSCNViewDelegate>
@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Setup AR
    self.sceneView.delegate = self;
    self.sceneView.showsStatistics = YES;
    self.sceneView.autoenablesDefaultLighting = YES;
    self.sceneView.automaticallyUpdatesLighting = YES;
    
    // Create and configure AR session
    ARWorldTrackingConfiguration *config = [ARWorldTrackingConfiguration new];
    config.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
    config.environmentTexturing = AREnvironmentTexturingAutomatic;
    
    // Run the session
    [self.sceneView.session runWithConfiguration:config options:ARSessionRunOptionResetSceneReconstruction | ARSessionRunOptionRemoveExistingAnchors];
    
    // Initialize arrays and counters
    self.photoMetaArray = [NSMutableArray array];
    self.photoCount = 0;
    
    // Setup motion manager
    self.motionManager = [[CMMotionManager alloc] init];
    if (self.motionManager.deviceMotionAvailable) {
        self.motionManager.deviceMotionUpdateInterval = 1.0/60.0;
        [self.motionManager startDeviceMotionUpdates];
    } else {
        NSLog(@"Device motion is not available");
    }
    
    // Setup location manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
    
    // Setup photo button
    UIButton *photoButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [photoButton setTitle:@"Photo" forState:UIControlStateNormal];
    [photoButton addTarget:self action:@selector(onTakePhoto:) forControlEvents:UIControlEventTouchUpInside];
    photoButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:photoButton];
    
    // Add constraints for the button
    [NSLayoutConstraint activateConstraints:@[
        [photoButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [photoButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [photoButton.widthAnchor constraintEqualToConstant:69],
        [photoButton.heightAnchor constraintEqualToConstant:35]
    ]];
    
    // Make button more visible
    photoButton.backgroundColor = [UIColor systemBlueColor];
    [photoButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    photoButton.layer.cornerRadius = 17.5;
}

- (NSDictionary *)createPhotoMetadata:(UIImage *)image withMotion:(CMDeviceMotion *)motion andLocation:(CLLocation *)location {
    // Get image dimensions
    CGSize imageSize = image.size;
    
    // Calculate relative motion if we have first motion
    CMQuaternion relativeAttitude = {0, 0, 0, 1};
    CMQuaternion relativeEulerAngles = {0, 0, 0};
    CMQuaternion relativePosition = {0, 0, 0};
    
    // Initialize motion data with default values
    NSDictionary *gyroRotationRate = @{
        @"x": @(0.0),
        @"y": @(0.0),
        @"z": @(0.0)
    };
    
    NSDictionary *gyroAttitude = @{
        @"x": @(0.0),
        @"y": @(0.0),
        @"z": @(0.0),
        @"w": @(1.0)
    };
    
    NSDictionary *gyroEulerAngles = @{
        @"x": @(0.0),
        @"y": @(0.0),
        @"z": @(0.0)
    };
    
    if (motion) {
        gyroRotationRate = @{
            @"x": @(motion.rotationRate.x),
            @"y": @(motion.rotationRate.y),
            @"z": @(motion.rotationRate.z)
        };
        
        gyroAttitude = @{
            @"x": @(motion.attitude.quaternion.x),
            @"y": @(motion.attitude.quaternion.y),
            @"z": @(motion.attitude.quaternion.z),
            @"w": @(motion.attitude.quaternion.w)
        };
        
        gyroEulerAngles = @{
            @"x": @(motion.attitude.pitch),
            @"y": @(motion.attitude.yaw),
            @"z": @(motion.attitude.roll)
        };
        
        if (self.firstMotion) {
            // Calculate relative attitude
            CMQuaternion firstAttitude = self.firstMotion.attitude.quaternion;
            CMQuaternion currentAttitude = motion.attitude.quaternion;
            relativeAttitude = [self quaternionMultiply:[self quaternionInverse:firstAttitude] with:currentAttitude];
            
            // Calculate relative euler angles
            relativeEulerAngles = [self quaternionToEulerAngles:relativeAttitude];
            
            // Calculate relative position (simplified - using ARKit's transform)
            if (self.sceneView.session.currentFrame) {
                matrix_float4x4 transform = self.sceneView.session.currentFrame.camera.transform;
                relativePosition = (CMQuaternion){
                    transform.columns[3].x,
                    transform.columns[3].y,
                    transform.columns[3].z,
                    1.0
                };
            }
        } else {
            self.firstMotion = motion;
        }
    }
    
    // Initialize location data with default values
    NSNumber *latitude = @(0.0);
    NSNumber *longitude = @(0.0);
    
    if (location) {
        latitude = @(location.coordinate.latitude);
        longitude = @(location.coordinate.longitude);
        if (!self.firstLocation) {
            self.firstLocation = location;
        }
    }
    
    // Get camera intrinsics if available
    simd_float3x3 intrinsics = matrix_identity_float3x3;
    if (self.sceneView.session.currentFrame) {
        intrinsics = self.sceneView.session.currentFrame.camera.intrinsics;
    }
    
    // Create metadata dictionary
    return @{
        @"photoId": [[NSUUID UUID] UUIDString],
        @"timestamp": [NSDate.date description],
        @"width": @(imageSize.width),
        @"height": @(imageSize.height),
        @"quality": @(1.0), // 100% quality for PNG
        @"gyroRotationRate": gyroRotationRate,
        @"gyroAttitude": gyroAttitude,
        @"relativeGyroAttitude": @{
            @"x": @(relativeAttitude.x),
            @"y": @(relativeAttitude.y),
            @"z": @(relativeAttitude.z),
            @"w": @(relativeAttitude.w)
        },
        @"relativeEulerAngles": @{
            @"x": @(relativeEulerAngles.x),
            @"y": @(relativeEulerAngles.y),
            @"z": @(relativeEulerAngles.z)
        },
        @"relativePosition": @{
            @"x": @(relativePosition.x),
            @"y": @(relativePosition.y),
            @"z": @(relativePosition.z)
        },
        @"gyroEulerAngles": gyroEulerAngles,
        @"latitude": latitude,
        @"longitude": longitude,
        @"focalLength": @{
            @"x": @(intrinsics.columns[0][0]),
            @"y": @(intrinsics.columns[1][1])
        },
        @"sensorSize": @{
            @"x": @(5.76), // Typical iPhone sensor width in mm
            @"y": @(4.29)  // Typical iPhone sensor height in mm
        },
        @"resolution": @{
            @"x": @(imageSize.width),
            @"y": @(imageSize.height)
        },
        @"principalPoint": @{
            @"x": @(intrinsics.columns[2][0]),
            @"y": @(intrinsics.columns[2][1])
        }
    };
}

- (IBAction)onTakePhoto:(id)sender {
    NSLog(@"📸 Photo button tapped");
    
    if (self.photoCount >= 8) {
        NSLog(@"📸 Already took 8 photos");
        return;
    }

    // Check if AR session is running
    if (self.sceneView.session.currentFrame == nil) {
        NSLog(@"📸 AR session is not ready");
        return;
    }

    UIImage *snapshot;
    CMDeviceMotion *currentMotion = self.motionManager.deviceMotion;
    CLLocation *currentLocation = self.locationManager.location;

#if TARGET_OS_SIMULATOR    
    snapshot = [UIImage systemImageNamed:@"camera.fill"];
    NSLog(@"Using placeholder image for simulator");
#else    
    // Get the current frame from AR session
    ARFrame *currentFrame = self.sceneView.session.currentFrame;
    if (currentFrame) {
        // Get the captured image
        CVPixelBufferRef pixelBuffer = currentFrame.capturedImage;
        if (pixelBuffer) {
            CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
            CIContext *context = [CIContext contextWithOptions:nil];
            CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
            snapshot = [UIImage imageWithCGImage:cgImage];
            CGImageRelease(cgImage);
        }
    }
    
    if (!snapshot) {
        snapshot = [self.sceneView snapshot];
    }
    NSLog(@"📸 Taking snapshot");
#endif

    if (!snapshot) {
        NSLog(@"📸 Snapshot failed");
        return;
    }

    // Create metadata
    NSDictionary *metadata = [self createPhotoMetadata:snapshot withMotion:currentMotion andLocation:currentLocation];
    
    // Save image with maximum quality
    NSData *imageData;
    NSString *extension;
    
    // Try to save as HEIC first
    if (@available(iOS 11.0, *)) {
        NSMutableData *heicData = [NSMutableData data];
        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)heicData, (__bridge CFStringRef)@"public.heic", 1, NULL);
        if (destination) {
            CGImageDestinationAddImage(destination, snapshot.CGImage, (__bridge CFDictionaryRef)@{
                (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(1.0)
            });
            if (CGImageDestinationFinalize(destination)) {
                imageData = heicData;
                extension = @"heic";
            }
            CFRelease(destination);
        }
    }
    
    // Fallback to PNG if HEIC fails
    if (!imageData) {
        imageData = UIImagePNGRepresentation(snapshot);
        extension = @"png";
    }
    
    if (!imageData) {
        NSLog(@"📸 Failed to convert snapshot to image data");
        return;
    }

    NSString *filename = [NSString stringWithFormat:@"photo_%ld.%@", (long)self.photoCount + 1, extension];
    NSString *photoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];

    BOOL success = [imageData writeToFile:photoPath atomically:YES];
    if (!success) {
        NSLog(@"📸 Failed to save photo");
        return;
    }

    // Add path to metadata
    NSMutableDictionary *mutableMetadata = [metadata mutableCopy];
    mutableMetadata[@"path"] = photoPath;
    
    [self.photoMetaArray addObject:mutableMetadata];
    self.photoCount++;

    NSLog(@"📸 Saved photo %ld → %@", (long)self.photoCount, photoPath);

    if (self.photoCount == 8) {
        [self exportSessionToFolder];
    }
}

- (void)exportSessionToFolder {
    NSString *sessionFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SessionExport"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    
    // Create directory if it doesn't exist
    if (![fileManager fileExistsAtPath:sessionFolder]) {
        if (![fileManager createDirectoryAtPath:sessionFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create export directory: %@", error);
            return;
        }
    }

    // Create JSON with all metadata
    NSString *jsonPath = [sessionFolder stringByAppendingPathComponent:@"Session.json"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.photoMetaArray options:NSJSONWritingPrettyPrinted error:&error];
    if (!jsonData) {
        NSLog(@"Failed to create JSON data: %@", error);
        return;
    }
    
    if (![jsonData writeToFile:jsonPath atomically:YES]) {
        NSLog(@"Failed to write JSON file");
        return;
    }

    // Copy all photos
    for (NSDictionary *meta in self.photoMetaArray) {
        NSString *src = meta[@"path"];
        if (!src) {
            NSLog(@"Missing path in metadata");
            continue;
        }
        
        NSString *filename = [src lastPathComponent];
        NSString *dst = [sessionFolder stringByAppendingPathComponent:filename];
        
        if ([fileManager fileExistsAtPath:src]) {
            if (![fileManager copyItemAtPath:src toPath:dst error:&error]) {
                NSLog(@"Failed to copy photo %@: %@", filename, error);
            }
        } else {
            NSLog(@"Source photo not found: %@", src);
        }
    }

    NSLog(@"📁 Session saved to folder: %@", sessionFolder);
    
    // Show success alert with options to view or share
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Session Complete"
                                                                 message:@"Photos and metadata have been saved. What would you like to do?"
                                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"View Photos"
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction * _Nonnull action) {
        [self showPhotoGallery];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Share Session"
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction * _Nonnull action) {
        [self shareSession];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showPhotoGallery {
    // Create a collection view controller to display photos
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake(100, 100);
    layout.minimumInteritemSpacing = 10;
    layout.minimumLineSpacing = 10;
    
    UICollectionViewController *galleryVC = [[UICollectionViewController alloc] initWithCollectionViewLayout:layout];
    galleryVC.collectionView.delegate = self;
    galleryVC.collectionView.dataSource = self;
    [galleryVC.collectionView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"PhotoCell"];
    
    // Present the gallery
    [self presentViewController:galleryVC animated:YES completion:nil];
}

- (void)shareSession {
    NSString *sessionFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SessionExport"];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:sessionFolder error:nil];
    NSMutableArray *itemsToShare = [NSMutableArray array];
    
    for (NSString *file in files) {
        NSString *filePath = [sessionFolder stringByAppendingPathComponent:file];
        [itemsToShare addObject:[NSURL fileURLWithPath:filePath]];
    }
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:itemsToShare applicationActivities:nil];
    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.photoMetaArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"PhotoCell" forIndexPath:indexPath];
    
    // Get the photo path from metadata
    NSDictionary *meta = self.photoMetaArray[indexPath.item];
    NSString *photoPath = meta[@"path"];
    
    if (photoPath) {
        UIImage *image = [UIImage imageWithContentsOfFile:photoPath];
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:cell.contentView.bounds];
        imageView.image = image;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        [cell.contentView addSubview:imageView];
    }
    
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // Show full screen photo
    NSDictionary *meta = self.photoMetaArray[indexPath.item];
    NSString *photoPath = meta[@"path"];
    
    if (photoPath) {
        UIImage *image = [UIImage imageWithContentsOfFile:photoPath];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        imageView.backgroundColor = [UIColor blackColor];
        imageView.frame = self.view.bounds;
        imageView.userInteractionEnabled = YES;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissFullScreenPhoto:)];
        [imageView addGestureRecognizer:tap];
        
        [self.view addSubview:imageView];
    }
}

- (void)dismissFullScreenPhoto:(UITapGestureRecognizer *)tap {
    [tap.view removeFromSuperview];
}

#pragma mark - Helper Methods

- (CMQuaternion)quaternionInverse:(CMQuaternion)q {
    float norm = q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w;
    return (CMQuaternion){
        -q.x / norm,
        -q.y / norm,
        -q.z / norm,
        q.w / norm
    };
}

- (CMQuaternion)quaternionMultiply:(CMQuaternion)q1 with:(CMQuaternion)q2 {
    return (CMQuaternion){
        q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
        q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
        q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
        q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
    };
}

- (CMQuaternion)quaternionToEulerAngles:(CMQuaternion)q {
    // Convert quaternion to Euler angles (in degrees)
    float pitch = asin(2 * (q.w * q.y - q.x * q.z)) * 180.0 / M_PI;
    float yaw = atan2(2 * (q.w * q.z + q.x * q.y), 1 - 2 * (q.y * q.y + q.z * q.z)) * 180.0 / M_PI;
    float roll = atan2(2 * (q.w * q.x + q.y * q.z), 1 - 2 * (q.x * q.x + q.y * q.y)) * 180.0 / M_PI;
    
    return (CMQuaternion){pitch, yaw, roll, 1.0};
}

- (void)dealloc {
    [self.motionManager stopDeviceMotionUpdates];
    [self.locationManager stopUpdatingLocation];
}

// Add AR session delegate methods
- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    NSLog(@"AR Session failed: %@", error);
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    // This will be called every frame, so we can use it to check session state
    if (frame.camera.trackingState == ARTrackingStateNormal) {
        // AR session is working normally
    } else if (frame.camera.trackingState == ARTrackingStateLimited) {
        NSLog(@"AR tracking is limited");
    } else {
        NSLog(@"AR tracking is not available");
    }
}

- (void)sessionWasInterrupted:(ARSession *)session {
    NSLog(@"AR Session was interrupted");
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    NSLog(@"AR Session interruption ended");
    // Reset the session
    ARWorldTrackingConfiguration *config = [ARWorldTrackingConfiguration new];
    config.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
    config.environmentTexturing = AREnvironmentTexturingAutomatic;
    [self.sceneView.session runWithConfiguration:config options:ARSessionRunOptionResetSceneReconstruction | ARSessionRunOptionRemoveExistingAnchors];
}

@end
