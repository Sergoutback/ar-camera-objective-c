//
//  ViewController.m
//  ar-camera-objective-c
//
//  Created by Mac on 14.06.25.
//

#import "ViewController.h"
#import <ARKit/ARKit.h>
#import <CoreLocation/CoreLocation.h>


@interface ViewController () <ARSCNViewDelegate>

@property (weak, nonatomic) IBOutlet ARSCNView *sceneView;

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *photoMetaArray;

@property (nonatomic, assign) NSInteger photoCount;

@end


@implementation ViewController

- (IBAction)onTakePhoto:(id)sender {
    if (self.photoCount >= 8) {
        NSLog(@"📸 Already took 8 photos");
        return;
    }

    UIImage *snapshot;

#if TARGET_OS_SIMULATOR    
    snapshot = [UIImage systemImageNamed:@"camera.fill"];
    NSLog(@"Using placeholder image for simulator");
#else
    
    snapshot = [self.sceneView snapshot];
#endif

    if (!snapshot) {
        NSLog(@"Snapshot failed");
        return;
    }

    NSData *pngData = UIImagePNGRepresentation(snapshot);
    if (!pngData) {
        NSLog(@"Failed to convert snapshot to PNG");
        return;
    }

    NSString *filename = [NSString stringWithFormat:@"photo_%ld.png", (long)self.photoCount + 1];
    NSString *photoPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];

    BOOL success = [pngData writeToFile:photoPath atomically:YES];
    if (!success) {
        NSLog(@"Failed to save photo");
        return;
    }

    NSDictionary *meta = @{
        @"photoId": [[NSUUID UUID] UUIDString],
        @"timestamp": [NSDate.date description],
        @"path": photoPath
    };
    [self.photoMetaArray addObject:meta];
    self.photoCount++;

    NSLog(@"Saved photo %ld → %@", (long)self.photoCount, photoPath);

    if (self.photoCount == 8) {
        [self exportSessionToFolder];
    }
}




- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.sceneView.delegate = self;
    self.sceneView.showsStatistics = YES;

    ARWorldTrackingConfiguration *config = [ARWorldTrackingConfiguration new];
    [self.sceneView.session runWithConfiguration:config];
    
    self.photoMetaArray = [NSMutableArray array];
    self.photoCount = 0;
}

- (void)exportSessionToFolder {
    
    NSString *sessionFolder = [NSTemporaryDirectory() stringByAppendingPathComponent:@"SessionExport"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:sessionFolder]) {
        [fileManager createDirectoryAtPath:sessionFolder withIntermediateDirectories:YES attributes:nil error:nil];
    }

    
    NSString *jsonPath = [sessionFolder stringByAppendingPathComponent:@"Session.json"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self.photoMetaArray options:NSJSONWritingPrettyPrinted error:nil];
    [jsonData writeToFile:jsonPath atomically:YES];

    
    for (NSDictionary *meta in self.photoMetaArray) {
        NSString *src = meta[@"path"];
        NSString *filename = [src lastPathComponent];
        NSString *dst = [sessionFolder stringByAppendingPathComponent:filename];
        [fileManager copyItemAtPath:src toPath:dst error:nil];
    }

    
    NSLog(@"📁 Session saved to folder: %@", sessionFolder);
}
@end
