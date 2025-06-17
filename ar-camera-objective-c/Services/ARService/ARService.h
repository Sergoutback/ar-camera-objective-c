#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import "ARServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ARServiceDelegate <NSObject>
- (void)didUpdateCameraPosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles;
- (void)didUpdateSpaceScanningStatus:(BOOL)isScanned;
@end

@interface ARService : NSObject <ARServiceProtocol, ARSCNViewDelegate, ARSessionDelegate>

@property (nonatomic, weak) id<ARServiceDelegate> delegate;
@property (nonatomic, strong, readonly) ARSCNView *sceneView;
@property (nonatomic, assign, readonly) BOOL isSpaceScanned;

- (instancetype)initWithSceneView:(ARSCNView *)sceneView;
- (void)setupAR;
- (void)startARSession;
- (void)pauseARSession;
- (void)resetARSession;
- (void)updatePreviewPosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles;
- (ARFrame *)currentFrame;
- (simd_float4x4)currentCameraTransform;
- (simd_float3)currentCameraEulerAngles;
- (matrix_float3x3)currentCameraIntrinsics;
- (NSTimeInterval)currentFrameTimestamp;

@end

NS_ASSUME_NONNULL_END 