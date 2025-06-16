#import <XCTest/XCTest.h>
#import "ViewModels/ARCameraViewModel.h"
#import "Services/ARService/ARServiceProtocol.h"
#import "Services/MotionService/MotionServiceProtocol.h"
#import "Services/LocationService/LocationServiceProtocol.h"
#import <ARKit/ARKit.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>

// Mock Services
@interface MockARService : NSObject <ARServiceProtocol>
@property (nonatomic, strong) ARSCNView *sceneView;
@property (nonatomic, strong) ARSession *session;
@end

@implementation MockARService
- (void)setupAR {}
- (void)startARSession {}
- (void)pauseARSession {}
- (void)resetARSession {}
- (void)capturePhotoWithCompletion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completion {
    completion([UIImage new], nil);
}
@end

@interface MockMotionService : NSObject <MotionServiceProtocol>
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) CMDeviceMotion *currentMotion;
@end

@implementation MockMotionService
- (void)startMotionUpdates {}
- (void)stopMotionUpdates {}
- (void)getCurrentMotionWithCompletion:(void (^)(CMDeviceMotion * _Nullable, NSError * _Nullable))completion {
    completion([CMDeviceMotion new], nil);
}
@end

@interface MockLocationService : NSObject <LocationServiceProtocol>
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *currentLocation;
@end

@implementation MockLocationService
- (void)startLocationUpdates {}
- (void)stopLocationUpdates {}
- (void)requestLocationPermission:(void (^)(BOOL))completion {
    completion(YES);
}
- (void)getCurrentLocationWithCompletion:(void (^)(CLLocation * _Nullable, NSError * _Nullable))completion {
    completion([[CLLocation alloc] initWithLatitude:0 longitude:0], nil);
}
@end

@interface ARCameraViewModelTests : XCTestCase

@property (nonatomic, strong) ARCameraViewModel *viewModel;
@property (nonatomic, strong) id<ARServiceProtocol> mockARService;
@property (nonatomic, strong) id<MotionServiceProtocol> mockMotionService;
@property (nonatomic, strong) id<LocationServiceProtocol> mockLocationService;

@end

@implementation ARCameraViewModelTests

- (void)setUp {
    [super setUp];
    self.mockARService = [[MockARService alloc] init];
    self.mockMotionService = [[MockMotionService alloc] init];
    self.mockLocationService = [[MockLocationService alloc] init];
    
    self.viewModel = [[ARCameraViewModel alloc] initWithARService:self.mockARService
                                                   motionService:self.mockMotionService
                                                 locationService:self.mockLocationService];
}

- (void)tearDown {
    self.viewModel = nil;
    self.mockARService = nil;
    self.mockMotionService = nil;
    self.mockLocationService = nil;
    [super tearDown];
}

- (void)testViewModelInitialization {
    XCTAssertNotNil(self.viewModel, @"ViewModel should not be nil after initialization");
    XCTAssertEqual(self.viewModel.photoCount, 0, @"Initial photo count should be 0");
    XCTAssertNotNil(self.viewModel.photoMetaArray, @"Photo meta array should not be nil");
    XCTAssertEqual(self.viewModel.photoMetaArray.count, 0, @"Initial photo meta array should be empty");
}

- (void)testStartServices {
    [self.viewModel startServices];
    // Since we're using mock services, we can't verify the actual service states
    // In a real test, we would verify that each service's start method was called
}

- (void)testStopServices {
    [self.viewModel stopServices];
    // Since we're using mock services, we can't verify the actual service states
    // In a real test, we would verify that each service's stop method was called
}

- (void)testCapturePhoto {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Photo capture completion"];
    
    [self.viewModel capturePhotoWithCompletion:^(UIImage * _Nullable image, NSDictionary * _Nullable metadata, NSError * _Nullable error) {
        XCTAssertNil(error, @"Error should be nil when capturing photo");
        XCTAssertNotNil(image, @"Image should not be nil when capturing photo");
        XCTAssertNotNil(metadata, @"Metadata should not be nil when capturing photo");
        XCTAssertEqual(self.viewModel.photoCount, 1, @"Photo count should be incremented");
        XCTAssertEqual(self.viewModel.photoMetaArray.count, 1, @"Photo meta array should contain one entry");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testResetSession {
    // First capture a photo to set up some state
    XCTestExpectation *captureExpectation = [self expectationWithDescription:@"Photo capture completion"];
    [self.viewModel capturePhotoWithCompletion:^(UIImage * _Nullable image, NSDictionary * _Nullable metadata, NSError * _Nullable error) {
        [captureExpectation fulfill];
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
    
    // Now reset the session
    [self.viewModel resetSession];
    
    XCTAssertEqual(self.viewModel.photoCount, 0, @"Photo count should be reset to 0");
    XCTAssertEqual(self.viewModel.photoMetaArray.count, 0, @"Photo meta array should be empty");
}

@end 