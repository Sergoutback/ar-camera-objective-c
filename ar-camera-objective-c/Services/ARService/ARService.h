#import <Foundation/Foundation.h>
#import "ARServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARService : NSObject <ARServiceProtocol, ARSCNViewDelegate, ARSessionDelegate>

- (instancetype)initWithSceneView:(ARSCNView *)sceneView;
- (ARFrame *)currentFrame;
- (simd_float4x4)currentCameraTransform;
- (simd_float3)currentCameraEulerAngles;
- (matrix_float3x3)currentCameraIntrinsics;
- (NSTimeInterval)currentFrameTimestamp;

@end

NS_ASSUME_NONNULL_END 