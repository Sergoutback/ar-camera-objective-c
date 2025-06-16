//
//  ViewController.m
//  ar-camera-objective-c
//
//  Created by Mac on 14.06.25.
//

#import "ViewController.h"
#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>


@interface ViewController () <ARSCNViewDelegate, CLLocationManagerDelegate, AVCapturePhotoCaptureDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCapturePhotoOutput *photoOutput;
@property (nonatomic, strong) AVCaptureDevice *captureDevice;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, assign) BOOL isCapturing;
@property (nonatomic, strong) UILabel *photoCounterLabel;
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
    self.photoCount = 0;
    self.photoMetaArray = [NSMutableArray array];
    self.isCapturing = NO;
    
    // Setup motion manager
    self.motionManager = [[CMMotionManager alloc] init];
    self.motionManager.deviceMotionUpdateInterval = 1.0/60.0;
    [self.motionManager startDeviceMotionUpdates];
    
    // Setup location manager
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
    
    // Create session queue
    self.sessionQueue = dispatch_queue_create("com.arcamera.sessionQueue", DISPATCH_QUEUE_SERIAL);
    
    // Setup photo capture session
    [self setupPhotoCapture];
    
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
    
    // Add tap gesture recognizer
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.sceneView addGestureRecognizer:tapGesture];
    
    // Setup photo counter label
    [self setupPhotoCounterLabel];
    
    // Update counter
    [self updatePhotoCounter];
}

- (void)setupPhotoCapture {
    dispatch_async(self.sessionQueue, ^{
        self.captureSession = [[AVCaptureSession alloc] init];
        [self.captureSession beginConfiguration];
        
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto;
        
        // Get the back camera
        self.captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if (!self.captureDevice) {
            NSLog(@"📸 No camera available");
            return;
        }
        
        NSError *error;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:self.captureDevice error:&error];
        if (error) {
            NSLog(@"📸 Error setting up camera input: %@", error);
            return;
        }
        
        if ([self.captureSession canAddInput:input]) {
            [self.captureSession addInput:input];
        }
        
        // Setup photo output
        self.photoOutput = [[AVCapturePhotoOutput alloc] init];
        if ([self.captureSession canAddOutput:self.photoOutput]) {
            [self.captureSession addOutput:self.photoOutput];
            
            // Configure for highest quality
            self.photoOutput.maxPhotoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
            
            // Get available formats
            NSArray *formats = self.captureDevice.formats;
            AVCaptureDeviceFormat *highestResolutionFormat = nil;
            for (AVCaptureDeviceFormat *format in formats) {
                CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                if (!highestResolutionFormat || 
                    (dimensions.width * dimensions.height) > 
                    (CMVideoFormatDescriptionGetDimensions(highestResolutionFormat.formatDescription).width * 
                     CMVideoFormatDescriptionGetDimensions(highestResolutionFormat.formatDescription).height)) {
                    highestResolutionFormat = format;
                }
            }
            
            if (highestResolutionFormat) {
                if ([self.captureDevice lockForConfiguration:&error]) {
                    self.captureDevice.activeFormat = highestResolutionFormat;
                    [self.captureDevice unlockForConfiguration];
                    NSLog(@"📸 Using highest resolution format: %dx%d", 
                          CMVideoFormatDescriptionGetDimensions(highestResolutionFormat.formatDescription).width,
                          CMVideoFormatDescriptionGetDimensions(highestResolutionFormat.formatDescription).height);
                }
            }
        }
        
        [self.captureSession commitConfiguration];
        [self.captureSession startRunning];
    });
}

- (NSDictionary *)createPhotoMetadata:(UIImage *)image withMotion:(CMDeviceMotion *)motion andLocation:(CLLocation *)location {
    // Get image dimensions
    CGSize imageSize = image.size;
    
    // Calculate relative motion if we have first motion
    CMQuaternion relativeAttitude = {0, 0, 0, 1};
    CMQuaternion relativeEulerAngles = {0, 0, 0};
    CMQuaternion relativePosition = {0, 0, 0};
    
    if (motion && self.firstMotion) {
        // Calculate relative attitude
        CMQuaternion firstAttitude = self.firstMotion.attitude.quaternion;
        relativeAttitude = [self quaternionMultiply:[self quaternionConjugate:firstAttitude] with:motion.attitude.quaternion];
        
        // Calculate relative euler angles
        relativeEulerAngles = [self quaternionToEulerAngles:relativeAttitude];
        
        // Calculate relative position
        CMAcceleration firstAcceleration = self.firstMotion.userAcceleration;
        CMAcceleration currentAcceleration = motion.userAcceleration;
        relativePosition.x = currentAcceleration.x - firstAcceleration.x;
        relativePosition.y = currentAcceleration.y - firstAcceleration.y;
        relativePosition.z = currentAcceleration.z - firstAcceleration.z;
    }
    
    // Initialize motion data with default values
    NSDictionary *gyroRotationRate = @{
        @"x": @(motion ? motion.rotationRate.x : 0.0),
        @"y": @(motion ? motion.rotationRate.y : 0.0),
        @"z": @(motion ? motion.rotationRate.z : 0.0)
    };
    
    NSDictionary *gyroAttitude = @{
        @"x": @(motion ? motion.attitude.quaternion.x : 0.0),
        @"y": @(motion ? motion.attitude.quaternion.y : 0.0),
        @"z": @(motion ? motion.attitude.quaternion.z : 0.0),
        @"w": @(motion ? motion.attitude.quaternion.w : 1.0)
    };
    
    NSDictionary *gyroEulerAngles = @{
        @"x": @(motion ? motion.attitude.roll : 0.0),
        @"y": @(motion ? motion.attitude.pitch : 0.0),
        @"z": @(motion ? motion.attitude.yaw : 0.0)
    };
    
    // Initialize location data
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
        @"sessionId": [[NSUUID UUID] UUIDString],
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
    
    if (self.isCapturing) {
        NSLog(@"📸 Already capturing photo");
        return;
    }
    
    self.isCapturing = YES;

    CMDeviceMotion *currentMotion = self.motionManager.deviceMotion;
    CLLocation *currentLocation = self.locationManager.location;

#if TARGET_OS_SIMULATOR    
    UIImage *snapshot = [UIImage systemImageNamed:@"camera.fill"];
    NSLog(@"Using placeholder image for simulator");
#else    
    // Pause AR session
    [self.sceneView.session pause];
    
    // Take photo using AVCapturePhotoOutput
    dispatch_async(self.sessionQueue, ^{
        if (!self.captureSession.isRunning) {
            [self.captureSession startRunning];
        }
        
        AVCapturePhotoSettings *settings = [[AVCapturePhotoSettings alloc] init];
        settings.flashMode = AVCaptureFlashModeAuto;
        settings.photoQualityPrioritization = AVCapturePhotoQualityPrioritizationQuality;
        
        [self.photoOutput capturePhotoWithSettings:settings delegate:self];
    });
    return; // Photo will be handled in delegate method
#endif

    // Rest of the existing photo handling code...
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    // Focus camera at tap point
    CGPoint tapPoint = [gesture locationInView:self.sceneView];
    CGPoint focusPoint = CGPointMake(tapPoint.x / self.sceneView.bounds.size.width,
                                    tapPoint.y / self.sceneView.bounds.size.height);
    
    dispatch_async(self.sessionQueue, ^{
        if ([self.captureDevice lockForConfiguration:nil]) {
            if (self.captureDevice.isFocusPointOfInterestSupported) {
                self.captureDevice.focusPointOfInterest = focusPoint;
                self.captureDevice.focusMode = AVCaptureFocusModeAutoFocus;
            }
            [self.captureDevice unlockForConfiguration];
        }
    });
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
        NSDictionary *paths = meta[@"path"];
        if (!paths) {
            NSLog(@"Missing path in metadata");
            continue;
        }
        
        // Copy PNG
        NSString *pngSrc = paths[@"png"];
        if (pngSrc) {
            NSString *pngFilename = [pngSrc lastPathComponent];
            NSString *pngDst = [sessionFolder stringByAppendingPathComponent:pngFilename];
            if ([fileManager fileExistsAtPath:pngSrc]) {
                if (![fileManager copyItemAtPath:pngSrc toPath:pngDst error:&error]) {
                    NSLog(@"Failed to copy PNG photo %@: %@", pngFilename, error);
                }
            }
        }
        
        // Copy HEIC
        NSString *heicSrc = paths[@"heic"];
        if (heicSrc) {
            NSString *heicFilename = [heicSrc lastPathComponent];
            NSString *heicDst = [sessionFolder stringByAppendingPathComponent:heicFilename];
            if ([fileManager fileExistsAtPath:heicSrc]) {
                if (![fileManager copyItemAtPath:heicSrc toPath:heicDst error:&error]) {
                    NSLog(@"Failed to copy HEIC photo %@: %@", heicFilename, error);
                }
            }
        }
    }

    NSLog(@"📁 Session saved to folder: %@", sessionFolder);
    
    // Show success alert with options to view, share, or start new session
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
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Start New Session"
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction * _Nonnull action) {
        [self startNewSession];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                            style:UIAlertActionStyleCancel
                                          handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startNewSession {
    // Reset photo count
    self.photoCount = 0;
    
    // Clear photo metadata array
    [self.photoMetaArray removeAllObjects];
    
    // Reset first motion and location
    self.firstMotion = nil;
    self.firstLocation = nil;
    
    // Update counter
    [self updatePhotoCounter];
    
    // Show confirmation alert
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"New Session"
                                                                 message:@"New session started. You can now take 8 new photos."
                                                          preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                            style:UIAlertActionStyleDefault
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

- (CMQuaternion)quaternionConjugate:(CMQuaternion)q {
    return (CMQuaternion){-q.x, -q.y, -q.z, q.w};
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
    // Convert quaternion to euler angles (roll, pitch, yaw)
    double roll = atan2(2 * (q.w * q.x + q.y * q.z), 1 - 2 * (q.x * q.x + q.y * q.y));
    double pitch = asin(2 * (q.w * q.y - q.z * q.x));
    double yaw = atan2(2 * (q.w * q.z + q.x * q.y), 1 - 2 * (q.y * q.y + q.z * q.z));
    
    return (CMQuaternion){roll, pitch, yaw, 0};
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

#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (error) {
        NSLog(@"📸 Error capturing photo: %@", error);
        // Resume AR session
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.sceneView.session runWithConfiguration:self.sceneView.session.configuration];
            self.isCapturing = NO;
        });
        return;
    }
    
    UIImage *snapshot = [UIImage imageWithData:photo.fileDataRepresentation];
    if (!snapshot) {
        NSLog(@"📸 Failed to create image from photo data");
        // Resume AR session
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.sceneView.session runWithConfiguration:self.sceneView.session.configuration];
            self.isCapturing = NO;
        });
        return;
    }
    
    NSLog(@"📸 Captured photo size: %.0fx%.0f", snapshot.size.width, snapshot.size.height);
    
    // Create metadata
    NSDictionary *metadata = [self createPhotoMetadata:snapshot withMotion:self.motionManager.deviceMotion andLocation:self.locationManager.location];
    
    // Save both PNG and HEIC formats
    NSString *baseFilename = [NSString stringWithFormat:@"photo_%ld", (long)self.photoCount + 1];
    NSString *pngPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFilename stringByAppendingString:@".png"]];
    NSString *heicPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[baseFilename stringByAppendingString:@".heic"]];
    
    // Save PNG
    NSData *pngData = UIImagePNGRepresentation(snapshot);
    BOOL pngSuccess = [pngData writeToFile:pngPath atomically:YES];
    
    // Save HEIC
    BOOL heicSuccess = NO;
    if (@available(iOS 11.0, *)) {
        NSMutableData *heicData = [NSMutableData data];
        CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)heicData, (__bridge CFStringRef)@"public.heic", 1, NULL);
        if (destination) {
            CGImageDestinationAddImage(destination, snapshot.CGImage, (__bridge CFDictionaryRef)@{
                (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(1.0)
            });
            if (CGImageDestinationFinalize(destination)) {
                heicSuccess = [heicData writeToFile:heicPath atomically:YES];
            }
            CFRelease(destination);
        }
    }
    
    if (!pngSuccess || !heicSuccess) {
        NSLog(@"📸 Failed to save photo in one or both formats");
        // Resume AR session
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.sceneView.session runWithConfiguration:self.sceneView.session.configuration];
            self.isCapturing = NO;
        });
        return;
    }
    
    // Save to photo library
    [self saveToPhotoLibrary:snapshot];
    
    // Add paths to metadata
    NSMutableDictionary *mutableMetadata = [metadata mutableCopy];
    mutableMetadata[@"path"] = @{
        @"png": pngPath,
        @"heic": heicPath
    };
    
    [self.photoMetaArray addObject:mutableMetadata];
    self.photoCount++;
    
    // Update counter
    [self updatePhotoCounter];
    
    NSLog(@"📸 Saved photo %ld → PNG: %@, HEIC: %@", (long)self.photoCount, pngPath, heicPath);
    
    // Resume AR session
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.sceneView.session runWithConfiguration:self.sceneView.session.configuration];
        self.isCapturing = NO;
    });
    
    if (self.photoCount == 8) {
        [self exportSessionToFolder];
    }
}

- (void)saveToPhotoLibrary:(UIImage *)image {
    // Request photo library access
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        if (status == PHAuthorizationStatusAuthorized) {
            // Save PNG
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
            
            // Save HEIC if available
            if (@available(iOS 11.0, *)) {
                NSMutableData *heicData = [NSMutableData data];
                CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)heicData, (__bridge CFStringRef)@"public.heic", 1, NULL);
                if (destination) {
                    CGImageDestinationAddImage(destination, image.CGImage, (__bridge CFDictionaryRef)@{
                        (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @(1.0)
                    });
                    if (CGImageDestinationFinalize(destination)) {
                        // Create temporary file for HEIC
                        NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"temp.heic"];
                        [heicData writeToFile:tempPath atomically:YES];
                        
                        // Save HEIC to photo library
                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                            [PHAssetChangeRequest creationRequestForAssetFromImageAtFileURL:[NSURL fileURLWithPath:tempPath]];
                        } completionHandler:^(BOOL success, NSError * _Nullable error) {
                            if (!success) {
                                NSLog(@"Failed to save HEIC to photo library: %@", error);
                            }
                            // Clean up temporary file
                            [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];
                        }];
                    }
                    CFRelease(destination);
                }
            }
        } else {
            NSLog(@"Photo library access denied");
        }
    }];
}

- (void)setupPhotoCounterLabel {
    self.photoCounterLabel = [[UILabel alloc] init];
    self.photoCounterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.photoCounterLabel.textColor = [UIColor whiteColor];
    self.photoCounterLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.photoCounterLabel.textAlignment = NSTextAlignmentCenter;
    self.photoCounterLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    self.photoCounterLabel.layer.cornerRadius = 15;
    self.photoCounterLabel.clipsToBounds = YES;
    
    [self.view addSubview:self.photoCounterLabel];
    
    // Add constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.photoCounterLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.photoCounterLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.photoCounterLabel.widthAnchor constraintGreaterThanOrEqualToConstant:100],
        [self.photoCounterLabel.heightAnchor constraintEqualToConstant:30]
    ]];
}

- (void)updatePhotoCounter {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.photoCounterLabel.text = [NSString stringWithFormat:@"%ld/8", (long)self.photoCount];
    });
}

@end
