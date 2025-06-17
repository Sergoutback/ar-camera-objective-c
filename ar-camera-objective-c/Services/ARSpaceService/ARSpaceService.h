#import <Foundation/Foundation.h>
#import <ARKit/ARKit.h>
#import <SceneKit/SceneKit.h>
#import "../../Models/PhotoPosition.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ARSpaceServiceDelegate <NSObject>
- (void)didUpdatePhotoPositions:(NSArray<PhotoPosition *> *)positions;
@end

@interface ARSpaceService : NSObject

@property (nonatomic, weak) id<ARSpaceServiceDelegate> delegate;
@property (nonatomic, strong, readonly) SCNNode *photoCanvasNode;
@property (nonatomic, assign, readonly) BOOL isInitialized;

- (instancetype)initWithSceneView:(ARSCNView *)sceneView;
- (void)initializeSpaceWithAnchor:(ARAnchor *)anchor;
- (void)addPhotoThumbnail:(PhotoPosition *)photoPosition;
- (void)updatePhotoThumbnail:(PhotoPosition *)photoPosition;
- (void)removePhotoThumbnail:(NSString *)photoId;
- (void)resetSpace;
- (void)updatePreviewPosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles;

@end

NS_ASSUME_NONNULL_END 