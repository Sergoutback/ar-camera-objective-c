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

@interface ViewController () <ARServiceDelegate>

@property (nonatomic, strong) ARCanvasView *canvasView;
@property (nonatomic, strong) ARCameraViewModel *viewModel;
@property (nonatomic, strong) PhotoService *photoService;
@property (nonatomic, strong) NSMutableArray<PhotoPosition *> *photoMetaArray;
@property (nonatomic, strong) id<ARServiceProtocol> arService;
@property (nonatomic, strong) MotionService *motionService;
@property (nonatomic, strong) LocationService *locationService;
@property (nonatomic, strong) ARSpaceService *spaceService;
@property (nonatomic, assign) NSInteger lastShareCount;
@property (nonatomic, strong) ARAnchor *initialAnchor;
@property (nonatomic, strong) ErrorView *errorView;
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UILabel *photoCounterLabel;
@property (nonatomic, strong) UIView *scanningStatusView;
@property (nonatomic, strong) UILabel *scanningStatusLabel;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Initialize AR Scene View first
    self.sceneView = [[ARSCNView alloc] initWithFrame:self.view.bounds];
    self.sceneView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.sceneView atIndex:0];
    
    // Initialize photo array
    self.photoMetaArray = [NSMutableArray array];
    
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
    // Initialize canvas view
    self.canvasView = [[ARCanvasView alloc] initWithSceneView:self.sceneView];
    
    // Initialize services
    self.arService = [[ARService alloc] initWithSceneView:self.sceneView];
    self.arService.delegate = self;
    self.motionService = [[MotionService alloc] init];
    self.locationService = [[LocationService alloc] init];
    self.photoService = [[PhotoService alloc] init];
    self.spaceService = [[ARSpaceService alloc] initWithSceneView:self.sceneView];
    
    // Initialize ViewModel with all required services
    self.viewModel = [[ARCameraViewModel alloc] initWithARService:self.arService
                                                   motionService:self.motionService
                                                 locationService:self.locationService
                                                   photoService:self.photoService
                                                   spaceService:self.spaceService];
    
    self.lastShareCount = 0;
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
        
        // Photo Counter Label
        [self.photoCounterLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [self.photoCounterLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [self.photoCounterLabel.widthAnchor constraintEqualToConstant:80],
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
    // Визуальный лог на экран
    UILabel *logLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, self.view.bounds.size.height-150, self.view.bounds.size.width-20, 40)];
    logLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    logLabel.textColor = [UIColor whiteColor];
    logLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    logLabel.textAlignment = NSTextAlignmentCenter;
    logLabel.text = @"Capture button tapped!";
    logLabel.layer.cornerRadius = 8;
    logLabel.layer.masksToBounds = YES;
    [self.view addSubview:logLabel];
    [UIView animateWithDuration:0.5 delay:1.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        logLabel.alpha = 0;
    } completion:^(BOOL finished) {
        [logLabel removeFromSuperview];
    }];
    
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
    
    [self.viewModel capturePhotoWithCompletion:^(PhotoPosition * _Nullable photoPosition, NSError * _Nullable error) {
        if (error) {
            NSLog(@"Error capturing photo: %@", error);
            return;
        }
        
        if (photoPosition) {
            [self.photoMetaArray addObject:photoPosition];
            [self updatePhotoCounter];
            [self.canvasView addPhotoThumbnail:photoPosition];
        }
    }];
}

- (void)resetButtonTapped {
    [self.arService resetARSession];
    [self.canvasView resetCanvas];
    [self.photoMetaArray removeAllObjects];
    [self updatePhotoCounter];
    // Сбросим статус сканирования
    self.scanningStatusLabel.text = @"Move camera to scan walls and floor";
    self.scanningStatusView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.scanningStatusView.alpha = 1.0;
    self.captureButton.enabled = NO;
    self.captureButton.alpha = 0.5;
}

- (void)exportButtonTapped {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export"
                                                                   message:@"Export is not implemented yet."
                                                            preferredStyle:UIAlertControllerStyleAlert];
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

#pragma mark - Private Methods

- (void)showSharingDialog {
    // Get the metadata directory path
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *metadataPath = [documentsPath stringByAppendingPathComponent:@"PhotoMetadata"];
    
    // Create a temporary directory for sharing
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ARPhotos"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Remove existing temp directory if it exists
    if ([fileManager fileExistsAtPath:tempDir]) {
        [fileManager removeItemAtPath:tempDir error:nil];
    }
    
    // Create new temp directory
    NSError *error;
    [fileManager createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error];
    
    if (error) {
        NSLog(@"Error creating temp directory: %@", error);
        return;
    }
    
    // Copy all JSON files to temp directory
    NSArray *jsonFiles = [fileManager contentsOfDirectoryAtPath:metadataPath error:&error];
    if (error) {
        NSLog(@"Error reading metadata directory: %@", error);
        return;
    }
    
    for (NSString *jsonFile in jsonFiles) {
        if ([jsonFile.pathExtension isEqualToString:@"json"]) {
            NSString *sourcePath = [metadataPath stringByAppendingPathComponent:jsonFile];
            NSString *destPath = [tempDir stringByAppendingPathComponent:jsonFile];
            [fileManager copyItemAtPath:sourcePath toPath:destPath error:&error];
            if (error) {
                NSLog(@"Error copying file %@: %@", jsonFile, error);
            }
        }
    }
    
    // Create sharing message
    NSString *message = [NSString stringWithFormat:@"I've captured %ld AR photos with motion and location data!", (long)self.viewModel.photoCount];
    
    // Create activity view controller
    NSMutableArray *activityItems = [NSMutableArray array];
    [activityItems addObject:message];
    [activityItems addObject:[NSURL fileURLWithPath:tempDir]];
    
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    // Present the sharing dialog
    [self presentViewController:activityVC animated:YES completion:nil];
    
    // Clean up temp directory after sharing
    activityVC.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
        [fileManager removeItemAtPath:tempDir error:nil];
    };
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
