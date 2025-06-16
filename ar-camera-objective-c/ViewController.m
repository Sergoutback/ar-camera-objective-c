#import "ViewController.h"
#import "Services/ARService/ARService.h"
#import "Services/MotionService/MotionService.h"
#import "Services/LocationService/LocationService.h"
#import "Services/PhotoService/PhotoService.h"
#import "Views/ErrorView.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()

@property (nonatomic, strong) ARCameraViewModel *viewModel;
@property (nonatomic, strong) id<PhotoServiceProtocol> photoService;
@property (nonatomic, strong) ErrorView *errorView;
@property (nonatomic, strong) UIButton *captureButton;
@property (nonatomic, strong) UIButton *resetButton;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) UILabel *photoCounterLabel;
@property (nonatomic, assign) NSInteger lastShareCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    // Initialize AR Scene View
    self.sceneView = [[ARSCNView alloc] initWithFrame:self.view.bounds];
    self.sceneView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view insertSubview:self.sceneView atIndex:0];
    
    // Initialize services
    ARService *arService = [[ARService alloc] initWithSceneView:self.sceneView];
    MotionService *motionService = [[MotionService alloc] init];
    LocationService *locationService = [[LocationService alloc] init];
    self.photoService = [[PhotoService alloc] init];
    
    // Initialize view model
    self.viewModel = [[ARCameraViewModel alloc] initWithARService:arService
                                                    motionService:motionService
                                                  locationService:locationService];
    
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
        [self.photoCounterLabel.heightAnchor constraintEqualToConstant:30]
    ]];
    
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
    [self.viewModel capturePhotoWithCompletion:^(UIImage * _Nullable image, NSDictionary * _Nullable metadata, NSError * _Nullable error) {
        if (error) {
            [self.errorView showError:error.localizedDescription withRetryAction:^{
                [self captureButtonTapped];
            }];
            return;
        }
        
        if (image) {
            [self.photoService savePhoto:image metadata:metadata completion:^(BOOL success, NSError * _Nullable error) {
                if (!success) {
                    [self.errorView showError:error.localizedDescription withRetryAction:^{
                        [self.photoService savePhoto:image metadata:metadata completion:nil];
                    }];
                }
                [self updatePhotoCounter];
            }];
        }
    }];
}

- (void)resetButtonTapped {
    [self.viewModel resetSession];
    [self updatePhotoCounter];
}

- (void)exportButtonTapped {
    if (self.viewModel.photoCount == 0) {
        [self.errorView showError:@"No photos to export" withRetryAction:nil];
        return;
    }
    
    // Show loading indicator
    UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    activityIndicator.center = self.view.center;
    [self.view addSubview:activityIndicator];
    [activityIndicator startAnimating];
    
    // Disable buttons during export
    self.captureButton.enabled = NO;
    self.resetButton.enabled = NO;
    self.exportButton.enabled = NO;
    
    [self.photoService exportSessionData:^(NSURL * _Nullable sessionURL, NSError * _Nullable error) {
        [activityIndicator stopAnimating];
        [activityIndicator removeFromSuperview];
        
        // Re-enable buttons
        self.captureButton.enabled = YES;
        self.resetButton.enabled = YES;
        self.exportButton.enabled = YES;
        
        if (error) {
            [self.errorView showError:error.localizedDescription withRetryAction:^{
                [self exportButtonTapped];
            }];
            return;
        }
        
        if (sessionURL) {
            // Create activity view controller
            NSMutableArray *activityItems = [NSMutableArray array];
            [activityItems addObject:@"AR Session Export"];
            [activityItems addObject:sessionURL];
            
            UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
            
            // Present the sharing dialog
            [self presentViewController:activityVC animated:YES completion:nil];
            
            // Clean up after sharing
            activityVC.completionWithItemsHandler = ^(UIActivityType __nullable activityType, BOOL completed, NSArray * __nullable returnedItems, NSError * __nullable activityError) {
                NSFileManager *fileManager = [NSFileManager defaultManager];
                [fileManager removeItemAtPath:sessionURL.path error:nil];
            };
        }
    }];
}

#pragma mark - Private Methods

- (void)updatePhotoCounter {
    NSInteger currentCount = self.viewModel.photoCount;
    self.photoCounterLabel.text = [NSString stringWithFormat:@"Photos: %ld", (long)currentCount];
    
    // Check if we need to show sharing dialog
    if (currentCount > 0 && currentCount % 8 == 0 && currentCount != self.lastShareCount) {
        self.lastShareCount = currentCount;
        [self showSharingDialog];
    }
}

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

@end 
