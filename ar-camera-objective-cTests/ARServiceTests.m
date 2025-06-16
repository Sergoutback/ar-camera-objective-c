#import <XCTest/XCTest.h>
#import "Services/ARService/ARService.h"
#import "Services/ARService/ARServiceProtocol.h"
#import <ARKit/ARKit.h>

@interface ARServiceTests : XCTestCase

@property (nonatomic, strong) ARSCNView *mockSceneView;
@property (nonatomic, strong) id<ARServiceProtocol> arService;

@end

@implementation ARServiceTests

- (void)setUp {
    [super setUp];
    self.mockSceneView = [[ARSCNView alloc] init];
    self.arService = [[ARService alloc] initWithSceneView:self.mockSceneView];
}

- (void)tearDown {
    self.mockSceneView = nil;
    self.arService = nil;
    [super tearDown];
}

- (void)testARServiceInitialization {
    XCTAssertNotNil(self.arService, @"AR Service should not be nil after initialization");
    XCTAssertNotNil(self.arService.sceneView, @"Scene view should not be nil after initialization");
    XCTAssertNotNil(self.arService.session, @"Session should not be nil after initialization");
}

- (void)testStartARSession {
    [self.arService startARSession];
    XCTAssertTrue(self.arService.session.isRunning, @"AR session should be running after start");
}

- (void)testPauseARSession {
    [self.arService startARSession];
    [self.arService pauseARSession];
    XCTAssertFalse(self.arService.session.isRunning, @"AR session should not be running after pause");
}

- (void)testResetARSession {
    [self.arService startARSession];
    [self.arService resetARSession];
    XCTAssertTrue(self.arService.session.isRunning, @"AR session should be running after reset");
}

- (void)testCapturePhoto {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Photo capture completion"];
    
    [self.arService capturePhotoWithCompletion:^(UIImage * _Nullable image, NSError * _Nullable error) {
        XCTAssertNil(error, @"Error should be nil when capturing photo");
        XCTAssertNotNil(image, @"Image should not be nil when capturing photo");
        [expectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end 