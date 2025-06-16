//
//  ViewController.h
//  ar-camera-objective-c
//
//  Created by Mac on 14.06.25.
//

#import <UIKit/UIKit.h>
#import <ARKit/ARKit.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreLocation/CoreLocation.h>

@interface ViewController : UIViewController <ARSCNViewDelegate, ARSessionDelegate, CLLocationManagerDelegate, UICollectionViewDelegate, UICollectionViewDataSource>

@property (nonatomic, weak) IBOutlet ARSCNView *sceneView;
@property (nonatomic, strong) CMMotionManager *motionManager;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *photoMetaArray;
@property (nonatomic, assign) NSInteger photoCount;
@property (nonatomic, strong) CMDeviceMotion *firstMotion;
@property (nonatomic, strong) CLLocation *firstLocation;

@end

