#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol ARServiceProtocol <NSObject>

@property (nonatomic, strong, readonly) ARSCNView *sceneView;
@property (nonatomic, strong, readonly) ARSession *session;

- (void)setupAR;
- (void)startARSession;
- (void)pauseARSession;
- (void)resetARSession;
- (void)capturePhotoWithCompletion:(void (^)(UIImage * _Nullable image, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END 