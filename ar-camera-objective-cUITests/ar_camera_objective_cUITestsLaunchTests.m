//
//  ar_camera_objective_cUITestsLaunchTests.m
//  ar-camera-objective-cUITests
//
//  Created by Mac on 14.06.25.
//

#import <XCTest/XCTest.h>

@interface ar_camera_objective_cUITestsLaunchTests : XCTestCase

@end

@implementation ar_camera_objective_cUITestsLaunchTests

+ (BOOL)runsForEachTargetApplicationUIConfiguration {
    return YES;
}

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)testLaunch {
    XCUIApplication *app = [[XCUIApplication alloc] init];
    [app launch];

    // Insert steps here to perform after app launch but before taking a screenshot,
    // such as logging into a test account or navigating somewhere in the app

    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];
    attachment.name = @"Launch Screen";
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

@end
