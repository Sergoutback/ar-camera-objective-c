//
//  ViewController.h
//  ar-camera-objective-c
//
//  Created by Mac on 14.06.25.
//

#import <UIKit/UIKit.h>
#import <ARKit/ARKit.h>
#import "Services/ARSpaceService/ARSpaceService.h"

NS_ASSUME_NONNULL_BEGIN

@interface ViewController : UIViewController <ARSpaceServiceDelegate>

@property (nonatomic, strong) ARSCNView *sceneView;

@end

NS_ASSUME_NONNULL_END

