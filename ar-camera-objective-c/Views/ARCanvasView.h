#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>
#import "../Models/PhotoPosition.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARCanvasView : NSObject

@property (nonatomic, strong, readonly) SCNNode *canvasNode;
@property (nonatomic, strong, readonly) SCNNode *reticleNode;
@property (nonatomic, assign, readonly) BOOL isInitialized;

- (instancetype)initWithSceneView:(ARSCNView *)sceneView;
- (void)initializeCanvasWithAnchor:(ARAnchor *)anchor;
- (void)addPhotoThumbnail:(PhotoPosition *)photoPosition;
- (void)updatePhotoThumbnail:(PhotoPosition *)photoPosition;
- (void)removePhotoThumbnail:(NSString *)photoId;
- (void)updateReticlePosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles;
- (void)resetCanvas;

@end

NS_ASSUME_NONNULL_END 
 