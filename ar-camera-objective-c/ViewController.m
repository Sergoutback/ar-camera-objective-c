#import "ViewController.h"
#import "Services/ARService/ARServiceProtocol.h"
#import "Services/ARService/ARService.h"
#import "Services/MotionService/MotionService.h"
#import "Services/LocationService/LocationService.h"
#import "Services/PhotoService/PhotoService.h"
#import "Services/ARSpaceService/ARSpaceService.h"
#import "Views/ARCanvasView.h"
#import "ViewModels/ARCameraViewModel.h"
#import "Models/PhotoPosition.h"
#import "Views/ErrorView.h"
#import <AVFoundation/AVFoundation.h>
#import "Services/CameraCaptureService/CameraCaptureService.h"

@interface ViewController () <ARServiceDelegate>

@property (nonatomic, strong) ARCanvasView *canvasView;
@property (nonatomic, strong) ARCameraViewModel *viewModel;
@property (nonatomic, strong) PhotoService *photoService;
@property (nonatomic, strong) NSMutableArray<PhotoPosition *> *photoMetaArray;
@property (nonatomic, strong) id<ARServiceProtocol> arService;
@property (nonatomic, strong) MotionService *motionService;
@property (nonatomic, strong) LocationService *locationService;
@property (nonatomic, strong) ARSpaceService *spaceService;
@property (nonatomic, strong) ARAnchor *initialAnchor;
@property (nonatomic, strong) ErrorView *errorView;
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UILabel *photoCounterLabel;
@property (nonatomic, strong) UIView *scanningStatusView;
@property (nonatomic, strong) UILabel *scanningStatusLabel;
@property (nonatomic, strong) UIStackView *notificationStackView;
@property (nonatomic, strong) CameraCaptureService *cameraService;
@property (nonatomic, strong) NSMutableSet<NSString *> *capturedPhotoIds;

@end

@implementation ViewController

#pragma mark - Dependency Injection Initializer

- (instancetype)initWithSceneView:(ARSCNView *)sceneView
                        arService:(id<ARServiceProtocol>)arService
                    motionService:(MotionService *)motionService
                  locationService:(LocationService *)locationService
                    photoService:(PhotoService *)photoService
                    spaceService:(ARSpaceService *)spaceService {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sceneView = sceneView;
        _arService = arService;
        _motionService = motionService;
        _locationService = locationService;
        _photoService = photoService;
        _spaceService = spaceService;

        // Configure delegate relationships
        _arService.delegate = self;
    }
    return self;
}

// MARK: - unavailable default init
- (instancetype)initWithCoder:(NSCoder *)coder {
    NSAssert(NO, @"Use initWithSceneView:arService:... instead");
    return [super initWithCoder:coder];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Attach injected ARSCNView to the view hierarchy if it's not already added
    self.sceneView.frame = self.view.bounds;
    self.sceneView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (!self.sceneView.superview) {
        [self.view insertSubview:self.sceneView atIndex:0];
    }
    
    // Build canvas view & view model using injected services
    self.canvasView = [[ARCanvasView alloc] initWithSceneView:self.sceneView];
    self.viewModel = [[ARCameraViewModel alloc] initWithARService:self.arService
                                                   motionService:self.motionService
                                                 locationService:self.locationService
                                                   photoService:self.photoService
                                                   spaceService:self.spaceService];
    
    // Note: Services will actually start after permission in initializeAR
    
    // Initialize photo array
    self.photoMetaArray = [NSMutableArray array];
    self.capturedPhotoIds = [NSMutableSet set];
    
    // Initialize camera service for high-resolution captures
    self.cameraService = [[CameraCaptureService alloc] init];
    
    [self setupUI];
    [self requestCameraPermission];
}

- (void)requestCameraPermission {
    [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (granted) {
                [self initializeAR];
            } else {
                [self.errorView showError:@"Camera access is required for AR features" withRetryAction:^{
                    [self requestCameraPermission];
                }];
            }
        });
    }];
}

- (void)initializeAR {
    // Ensure that services are running. If they are already running this is a no-op.
    if (!self.viewModel) {
        NSAssert(NO, @"ViewModel must be created in viewDidLoad before initializeAR is called");
        return;
    }
    [self.viewModel startServices];
}

- (void)setupUI {
    // Setup Error View
    self.errorView = [[ErrorView alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 100)];
    self.errorView.hidden = YES;
    [self.view addSubview:self.errorView];
    
    // Setup Capture Button
    self.captureButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.captureButton setTitle:@"Capture" forState:UIControlStateNormal];
    [self.captureButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.captureButton.backgroundColor = [UIColor systemBlueColor];
    self.captureButton.layer.cornerRadius = 25;
    [self.captureButton addTarget:self action:@selector(captureButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.captureButton];
    
    // Setup Reset Button
    self.resetButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.resetButton setTitle:@"Reset" forState:UIControlStateNormal];
    [self.resetButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.resetButton.backgroundColor = [UIColor systemRedColor];
    self.resetButton.layer.cornerRadius = 25;
    [self.resetButton addTarget:self action:@selector(resetButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.resetButton];
    
    // Setup Export Button
    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.exportButton setTitle:@"Export" forState:UIControlStateNormal];
    [self.exportButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.exportButton.backgroundColor = [UIColor systemGreenColor];
    self.exportButton.layer.cornerRadius = 25;
    [self.exportButton addTarget:self action:@selector(exportButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.exportButton];
    
    // Setup Photo Counter Label
    self.photoCounterLabel = [[UILabel alloc] init];
    self.photoCounterLabel.textColor = [UIColor whiteColor];
    self.photoCounterLabel.textAlignment = NSTextAlignmentCenter;
    self.photoCounterLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    self.photoCounterLabel.layer.cornerRadius = 15;
    self.photoCounterLabel.clipsToBounds = YES;
    [self.view addSubview:self.photoCounterLabel];
    
    // Add scanning status view
    self.scanningStatusView = [[UIView alloc] init];
    self.scanningStatusView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scanningStatusView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.scanningStatusView.layer.cornerRadius = 10;
    [self.view addSubview:self.scanningStatusView];
    
    self.scanningStatusLabel = [[UILabel alloc] init];
    self.scanningStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.scanningStatusLabel.textColor = [UIColor whiteColor];
    self.scanningStatusLabel.textAlignment = NSTextAlignmentCenter;
    self.scanningStatusLabel.text = @"Move camera to scan walls and floor";
    self.scanningStatusLabel.font = [UIFont systemFontOfSize:14];
    self.scanningStatusLabel.numberOfLines = 0;
    [self.scanningStatusView addSubview:self.scanningStatusLabel];
    
    // Auto Layout notificationStackView (добавляем первым)
    self.notificationStackView = [[UIStackView alloc] init];
    self.notificationStackView.axis = UILayoutConstraintAxisVertical;
    self.notificationStackView.spacing = 8;
    self.notificationStackView.alignment = UIStackViewAlignmentFill;
    self.notificationStackView.distribution = UIStackViewDistributionEqualSpacing;
    self.notificationStackView.userInteractionEnabled = NO;
    self.notificationStackView.translatesAutoresizingMaskIntoConstraints = NO;
    self.notificationStackView.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.08]; // для отладки
    [self.view insertSubview:self.notificationStackView atIndex:0];
    [NSLayoutConstraint activateConstraints:@[
        [self.notificationStackView.topAnchor constraintEqualToAnchor:self.scanningStatusView.bottomAnchor constant:10],
        [self.notificationStackView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.notificationStackView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10],
        [self.notificationStackView.bottomAnchor constraintLessThanOrEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10]
    ]];
    
    // Layout
    self.captureButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.resetButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.exportButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.photoCounterLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        // Capture Button
        [self.captureButton.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.captureButton.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [self.captureButton.widthAnchor constraintEqualToConstant:100],
        [self.captureButton.heightAnchor constraintEqualToConstant:100],
        
        // Reset Button
        [self.resetButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.resetButton.centerYAnchor constraintEqualToAnchor:self.captureButton.centerYAnchor],
        [self.resetButton.widthAnchor constraintEqualToConstant:80],
        [self.resetButton.heightAnchor constraintEqualToConstant:80],
        
        // Export Button
        [self.exportButton.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [self.exportButton.centerYAnchor constraintEqualToAnchor:self.captureButton.centerYAnchor],
        [self.exportButton.widthAnchor constraintEqualToConstant:80],
        [self.exportButton.heightAnchor constraintEqualToConstant:80],
        
        // Photo Counter Label (above capture button)
        [self.photoCounterLabel.centerXAnchor constraintEqualToAnchor:self.captureButton.centerXAnchor],
        [self.photoCounterLabel.bottomAnchor constraintEqualToAnchor:self.captureButton.topAnchor constant:-10],
        [self.photoCounterLabel.widthAnchor constraintEqualToConstant:90],
        [self.photoCounterLabel.heightAnchor constraintEqualToConstant:30],
        
        [self.scanningStatusView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.scanningStatusView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.scanningStatusView.widthAnchor constraintEqualToConstant:250],
        [self.scanningStatusView.heightAnchor constraintEqualToConstant:60],
        
        [self.scanningStatusLabel.centerXAnchor constraintEqualToAnchor:self.scanningStatusView.centerXAnchor],
        [self.scanningStatusLabel.centerYAnchor constraintEqualToAnchor:self.scanningStatusView.centerYAnchor],
        [self.scanningStatusLabel.leadingAnchor constraintEqualToAnchor:self.scanningStatusView.leadingAnchor constant:10],
        [self.scanningStatusLabel.trailingAnchor constraintEqualToAnchor:self.scanningStatusView.trailingAnchor constant:-10]
    ]];
    
    // Initially hide capture button until space is scanned
    self.captureButton.enabled = NO;
    self.captureButton.alpha = 0.5;
    
    [self updatePhotoCounter];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.viewModel startServices];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.viewModel stopServices];
}

#pragma mark - Actions

- (void)captureButtonTapped {
    [self showNotification:@"Capture button tapped!"];
    
    if (!self.canvasView.isInitialized) {
        // Create initial anchor at current camera position
        ARFrame *currentFrame = self.sceneView.session.currentFrame;
        if (currentFrame) {
            matrix_float4x4 transform = currentFrame.camera.transform;
            self.initialAnchor = [[ARAnchor alloc] initWithTransform:transform];
            [self.sceneView.session addAnchor:self.initialAnchor];
            [self.canvasView initializeCanvasWithAnchor:self.initialAnchor];
        }
    }
    
    // Generate photoId now to reuse between AR and high-res
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *dateStr = [df stringFromDate:[NSDate date]];
    NSString *photoId = [NSString stringWithFormat:@"Photo_%lu_%@", (unsigned long)self.photoMetaArray.count + 1, dateStr];

    __weak typeof(self) weakSelf = self;
    [self.viewModel capturePhotoWithId:photoId completion:^(PhotoPosition * _Nullable photoPosition, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error capturing photo: %@", error);
            return;
        }

        if (photoPosition) {
            // Skip if we have already added this photoId (can happen if ARService duplicates callbacks)
            if ([weakSelf.capturedPhotoIds containsObject:photoPosition.photoId]) {
                NSLog(@"Duplicate photo %@ ignored", photoPosition.photoId);
                return;
            }
            [weakSelf.capturedPhotoIds addObject:photoPosition.photoId];
            [weakSelf.photoMetaArray addObject:photoPosition];
            [weakSelf updatePhotoCounter];
            [weakSelf.canvasView addPhotoThumbnail:photoPosition];
        }

        // Pause AR session AFTER snapshot succeeds
        [weakSelf.arService pauseARSession];

        [weakSelf.cameraService captureHighResolutionPhoto:^(UIImage * _Nullable image, NSError * _Nullable error) {
            // Restart AR session after slight delay to ensure camera resources are released
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf.arService startARSession];
            });
            if (error) {
                NSLog(@"High-res capture error: %@", error);
                return;
            }
            if (image) {
                NSDictionary *meta = @{ @"photoId": photoId };
                [weakSelf.photoService savePhoto:image metadata:meta completion:^(BOOL success, NSError * _Nullable saveError) {
                    if (saveError) {
                        NSLog(@"Save high-res photo error: %@", saveError);
                    }
                }];
            }
        }];
    }];
}

- (void)resetButtonTapped {
    [self.arService resetARSession];
    [self.canvasView resetCanvas];
    [self.photoMetaArray removeAllObjects];
    [self.capturedPhotoIds removeAllObjects];
    [self.photoService resetSession];
    [self updatePhotoCounter];
    // Сбросим статус сканирования
    self.scanningStatusLabel.text = @"Move camera to scan walls and floor";
    self.scanningStatusView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.scanningStatusView.alpha = 1.0;
    self.captureButton.enabled = NO;
    self.captureButton.alpha = 0.5;
}

- (void)exportButtonTapped {
    // 1. Create a temporary folder for AR snapshots & meta
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    [fileManager createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error];
    if (error) {
        [self showAlertWithTitle:@"Export error" message:error.localizedDescription];
        return;
    }

    // 1a. Collect positional metadata (no PNG thumbnails required)
    NSMutableArray *photoDicts = [NSMutableArray array];
    for (PhotoPosition *photo in self.photoMetaArray) {
        [photoDicts addObject:[photo toDictionary]];
    }

    // 1b. Create JSON with positions
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"yyyyMMdd_HHmmss";
    NSString *dateStr = [df stringFromDate:[NSDate date]];
    NSString *jsonName = [NSString stringWithFormat:@"Session_%@.json", dateStr];
    NSString *jsonPath = [tempDir stringByAppendingPathComponent:jsonName];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:photoDicts options:NSJSONWritingPrettyPrinted error:&error];
    if (jsonData) {
        [jsonData writeToFile:jsonPath atomically:YES];
    }

    // 2. Ask PhotoService to export captured high-res images (PNG + HEIC)
    __weak typeof(self) weakSelf = self;
    [self.photoService exportSessionData:^(NSURL * _Nullable sessionURL, NSError * _Nullable exportError) {
        if (exportError) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf showAlertWithTitle:@"Export error" message:exportError.localizedDescription];
            });
            return;
        }
        // 3. Build payload directory containing only HEIC + JSON (exclude PNG)
        NSString *payloadDir = [tempDir stringByAppendingPathComponent:@"payload"];
        [fileManager createDirectoryAtPath:payloadDir withIntermediateDirectories:YES attributes:nil error:nil];

        // Copy HEIC dir
        NSURL *srcHEIC = [sessionURL URLByAppendingPathComponent:@"HEIC" isDirectory:YES];
        NSURL *destHEIC = [NSURL fileURLWithPath:[payloadDir stringByAppendingPathComponent:@"HEIC"]];
        [fileManager copyItemAtURL:srcHEIC toURL:destHEIC error:nil];

        // Copy positional JSON we created earlier
        [fileManager copyItemAtPath:jsonPath toPath:[payloadDir stringByAppendingPathComponent:jsonName] error:nil];

        // Create ZIP archive with payload
        NSString *zipName = [NSString stringWithFormat:@"ARSession_%@.zip", dateStr];
        NSString *zipPath = [tempDir stringByAppendingPathComponent:zipName];
        NSURL *zipURL = [NSURL fileURLWithPath:zipPath];
        BOOL zipOK = NO;
        SEL compressSel = NSSelectorFromString(@"compressItemAtURL:toURL:error:");
        if ([fileManager respondsToSelector:compressSel]) {
            typedef BOOL (*CompressIMP)(id, SEL, NSURL *, NSURL *, NSError *__autoreleasing *);
            CompressIMP imp = (CompressIMP)[fileManager methodForSelector:compressSel];
            NSError * __autoreleasing zipErr = nil;
            zipOK = imp(fileManager, compressSel, [NSURL fileURLWithPath:payloadDir], zipURL, &zipErr);
        }
        NSArray *activityItems = nil;
        if (zipOK) {
            activityItems = @[zipURL];
        } else {
            // Zip not available on this iOS version – share individual files to avoid directory errors
            NSMutableArray<NSURL *> *urls = [NSMutableArray array];
            NSDirectoryEnumerator *enumerator = [fileManager enumeratorAtURL:[NSURL fileURLWithPath:payloadDir]
                                                includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                   options:0
                                                              errorHandler:nil];
            for (NSURL *url in enumerator) {
                NSNumber *isDir = nil;
                [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:nil];
                if (isDir && !isDir.boolValue) {
                    [urls addObject:url];
                }
            }
            activityItems = urls;
        }

        // 4. Present share sheet on main queue
        dispatch_async(dispatch_get_main_queue(), ^{
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];

            activityVC.completionWithItemsHandler = ^(UIActivityType _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError) {
                NSTimeInterval delay = 5.0; // give extension time to close files
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                    [fileManager removeItemAtPath:tempDir error:nil];
                    [fileManager removeItemAtURL:sessionURL error:nil];
                });

                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completed) {
                        // Start fresh session only when user actually shared the files
                        [weakSelf resetButtonTapped];
                    }
                });
            };
            [weakSelf presentViewController:activityVC animated:YES completion:nil];
        });
    }];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    if (self.presentedViewController) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)updatePhotoCounter {
    self.photoCounterLabel.text = [NSString stringWithFormat:@"Photos: %lu", (unsigned long)self.photoMetaArray.count];
}

#pragma mark - ARServiceDelegate

- (void)didUpdateCameraPosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles {
    if (self.canvasView.isInitialized) {
        [self.canvasView updateReticlePosition:position eulerAngles:eulerAngles];
    }
}

- (void)didUpdateSpaceScanningStatus:(BOOL)isScanned {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (isScanned) {
            self.scanningStatusLabel.text = @"Space ready!\nYou can now take photos";
            self.scanningStatusView.backgroundColor = [[UIColor greenColor] colorWithAlphaComponent:0.7];
            self.captureButton.enabled = YES;
            [UIView animateWithDuration:0.3 animations:^{
                self.captureButton.alpha = 1.0;
                self.captureButton.transform = CGAffineTransformMakeScale(1.15, 1.15);
            } completion:^(BOOL finished) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.captureButton.transform = CGAffineTransformIdentity;
                }];
            }];
            // Hide status view after delay
            [UIView animateWithDuration:0.5 delay:3.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.scanningStatusView.alpha = 0;
            } completion:nil];
        } else {
            self.scanningStatusLabel.text = @"Move camera to scan walls and floor";
            self.scanningStatusView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
            self.scanningStatusView.alpha = 1.0;
            self.captureButton.enabled = NO;
            self.captureButton.alpha = 0.5;
        }
    });
}

- (void)didUpdateARStatusMessage:(NSString *)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self showNotification:message];
    });
}

#pragma mark - Private Methods

- (void)showNotification:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = text;
    label.layer.cornerRadius = 8;
    label.layer.masksToBounds = YES;
    label.numberOfLines = 0;
    
    [label.heightAnchor constraintGreaterThanOrEqualToConstant:32].active = YES;
    
    if (self.notificationStackView.arrangedSubviews.count >= 4) {
        UIView *first = self.notificationStackView.arrangedSubviews.firstObject;
        [self.notificationStackView removeArrangedSubview:first];
        [first removeFromSuperview];
    }
    [self.notificationStackView addArrangedSubview:label];
    [self.view layoutIfNeeded];
    [self.view bringSubviewToFront:self.notificationStackView];
    [UIView animateWithDuration:0.5 delay:2.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        label.alpha = 0;
    } completion:^(BOOL finished) {
        [self.notificationStackView removeArrangedSubview:label];
        [label removeFromSuperview];
    }];
}

- (UIImage *)createThumbnailFromImage:(UIImage *)image {
    CGSize size = CGSizeMake(100, 100);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *thumbnail = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return thumbnail;
}

- (SCNVector3)extractEulerAnglesFromMatrix:(matrix_float4x4)matrix {
    // Extract rotation matrix
    float m11 = matrix.columns[0].x;
    float m12 = matrix.columns[0].y;
    float m13 = matrix.columns[0].z;
    float m21 = matrix.columns[1].x;
    float m22 = matrix.columns[1].y;
    float m23 = matrix.columns[1].z;
    float m31 = matrix.columns[2].x;
    float m32 = matrix.columns[2].y;
    float m33 = matrix.columns[2].z;
    
    // Calculate euler angles
    float pitch = asin(-m31);
    float yaw = atan2(m11, m21);
    float roll = atan2(m32, m33);
    
    return SCNVector3Make(pitch, yaw, roll);
}

@end 
