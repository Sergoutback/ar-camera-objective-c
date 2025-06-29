#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>

@protocol ARServiceDelegate;

NS_ASSUME_NONNULL_BEGIN

@protocol ARServiceProtocol <NSObject>

@property (nonatomic, strong, readonly) ARSCNView *sceneView;
@property (nonatomic, strong, readonly) ARSession *session;
@property (nonatomic, weak) id<ARServiceDelegate> delegate;

- (void)setupAR;
- (void)startARSession;
- (void)pauseARSession;
- (void)resetARSession;
- (void)capturePhotoWithCompletion:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion;
- (simd_float4x4)currentCameraTransform;
- (matrix_float3x3)currentCameraIntrinsics;
- (simd_float3)currentCameraEulerAngles;
- (NSTimeInterval)currentFrameTimestamp;
- (void)startARSessionWithWorldMap:(nullable ARWorldMap *)worldMap;

@end

NS_ASSUME_NONNULL_END 