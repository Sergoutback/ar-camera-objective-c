#import "ARService.h"
#import <simd/simd.h>

@interface ARService ()

@property (nonatomic, strong) ARSCNView *sceneView;
@property (nonatomic, strong) ARSession *session;

@end

@implementation ARService

- (instancetype)initWithSceneView:(ARSCNView *)sceneView {
    self = [super init];
    if (self) {
        _sceneView = sceneView;
        _session = sceneView.session;
        [self setupAR];
    }
    return self;
}

- (void)setupAR {
    self.sceneView.delegate = self;
    self.sceneView.session.delegate = self;
    
    // Configure AR session
    ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
    configuration.planeDetection = ARPlaneDetectionHorizontal;
    [self.sceneView.session runWithConfiguration:configuration];
}

- (void)startARSession {
    ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
    configuration.planeDetection = ARPlaneDetectionHorizontal;
    [self.sceneView.session runWithConfiguration:configuration];
}

- (void)pauseARSession {
    [self.sceneView.session pause];
}

- (void)resetARSession {
    [self.sceneView.session runWithConfiguration:self.sceneView.session.configuration
                                    options:ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors];
}

- (void)capturePhotoWithCompletion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completion {
    UIImage *snapshot = [self.sceneView snapshot];
    if (snapshot) {
        completion(snapshot, nil);
    } else {
        NSError *error = [NSError errorWithDomain:@"ARServiceErrorDomain"
                                           code:1
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to capture photo"}];
        completion(nil, error);
    }
}

#pragma mark - ARSCNViewDelegate

- (void)renderer:(id<SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    // Handle anchor addition
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    // Handle anchor updates
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    // Handle session errors
}

- (void)sessionWasInterrupted:(ARSession *)session {
    // Handle session interruption
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    // Handle session interruption ended
}

- (ARFrame *)currentFrame {
    return self.sceneView.session.currentFrame;
}

- (simd_float4x4)currentCameraTransform {
    ARFrame *frame = [self currentFrame];
    return frame ? frame.camera.transform : matrix_identity_float4x4;
}

- (simd_float3)currentCameraEulerAngles {
    ARFrame *frame = [self currentFrame];
    return frame ? frame.camera.eulerAngles : (simd_float3){0,0,0};
}

- (matrix_float3x3)currentCameraIntrinsics {
    ARFrame *frame = [self currentFrame];
    return frame ? frame.camera.intrinsics : (matrix_float3x3){{{0,0,0},{0,0,0},{0,0,0}}};
}

- (NSTimeInterval)currentFrameTimestamp {
    ARFrame *frame = [self currentFrame];
    return frame ? frame.timestamp : 0;
}

@end 
