//
//  ViewController.h
//  ar-camera-objective-c
//
//  Created by Mac on 14.06.25.
//

#import <UIKit/UIKit.h>
#import <ARKit/ARKit.h>
#import "Services/ARService/ARServiceProtocol.h"
#import "Services/MotionService/MotionService.h"
#import "Services/LocationService/LocationService.h"
#import "Services/PhotoService/PhotoService.h"
#import "Services/ARSpaceService/ARSpaceService.h"

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : UIViewController

@property (nonatomic, strong) ARSCNView *sceneView;

- (instancetype)initWithSceneView:(ARSCNView *)sceneView
                        arService:(id<ARServiceProtocol>)arService
                    motionService:(MotionService *)motionService
                  locationService:(LocationService *)locationService
                    photoService:(PhotoService *)photoService
                    spaceService:(ARSpaceService *)spaceService NS_DESIGNATED_INITIALIZER;

// Provide default init that calls designated initializer with nils for storyboard compatibility (will assert).
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

