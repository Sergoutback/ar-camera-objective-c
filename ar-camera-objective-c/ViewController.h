//
//  ViewController.h
//  ar-camera-objective-c
//
//  Created by Mac on 14.06.25.
//

#import <UIKit/UIKit.h>
#import <ARKit/ARKit.h>
#import "ViewModels/ARCameraViewModel.h"

@interface ViewController : UIViewController

@property (nonatomic, strong) ARSCNView *sceneView;

@end

