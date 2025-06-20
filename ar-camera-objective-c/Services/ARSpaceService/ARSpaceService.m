#import "ARSpaceService.h"

@interface ARSpaceService ()

@property (nonatomic, strong) ARSCNView *sceneView;
@property (nonatomic, strong) SCNNode *photoCanvasNode;
@property (nonatomic, strong) NSMutableDictionary<NSString *, SCNNode *> *photoNodes;
@property (nonatomic, strong) SCNNode *previewNode;
@property (nonatomic, assign) BOOL isInitialized;

@end

@implementation ARSpaceService

- (instancetype)initWithSceneView:(ARSCNView *)sceneView {
    self = [super init];
    if (self) {
        _sceneView = sceneView;
        _photoNodes = [NSMutableDictionary dictionary];
        _isInitialized = NO;
        
        // Create preview node
        _previewNode = [self createPreviewNode];
        _previewNode.hidden = YES;
        [sceneView.scene.rootNode addChildNode:_previewNode];
    }
    return self;
}

- (void)initializeSpaceWithAnchor:(ARAnchor *)anchor {
    if (self.isInitialized) {
        return;
    }
    
    // Create canvas node
    self.photoCanvasNode = [SCNNode node];
    self.photoCanvasNode.name = @"PhotoCanvas";
    
    // Add canvas to anchor
    SCNNode *anchorNode = [SCNNode node];
    anchorNode.name = @"AnchorNode";
    [self.sceneView.scene.rootNode addChildNode:anchorNode];
    [anchorNode addChildNode:self.photoCanvasNode];
    
    self.isInitialized = YES;
}

- (void)addPhotoThumbnail:(PhotoPosition *)photoPosition {
    if (!self.isInitialized) {
        return;
    }
    
    SCNNode *photoNode = [self createPhotoNode:photoPosition];
    [self.photoCanvasNode addChildNode:photoNode];
    self.photoNodes[photoPosition.photoId] = photoNode;
    
    [self notifyDelegate];
}

- (void)updatePhotoThumbnail:(PhotoPosition *)photoPosition {
    SCNNode *existingNode = self.photoNodes[photoPosition.photoId];
    if (existingNode) {
        existingNode.position = photoPosition.relativePosition;
        SCNVector3 e2 = photoPosition.relativeEulerAngles;
        e2.z = 0;
        existingNode.eulerAngles = e2;
        
        // Update thumbnail if needed
        SCNMaterial *material = existingNode.geometry.firstMaterial;
        material.diffuse.contents = photoPosition.thumbnail;
    }
    
    [self notifyDelegate];
}

- (void)removePhotoThumbnail:(NSString *)photoId {
    SCNNode *node = self.photoNodes[photoId];
    if (node) {
        [node removeFromParentNode];
        [self.photoNodes removeObjectForKey:photoId];
    }
    
    [self notifyDelegate];
}

- (void)resetSpace {
    [self.photoCanvasNode removeFromParentNode];
    [self.photoNodes removeAllObjects];
    self.isInitialized = NO;
    self.previewNode.hidden = YES;
    
    [self notifyDelegate];
}

- (void)updatePreviewPosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles {
    if (!self.isInitialized) {
        return;
    }
    
    self.previewNode.position = position;
    self.previewNode.eulerAngles = eulerAngles;
    self.previewNode.hidden = NO;
}

#pragma mark - Private Methods

- (SCNNode *)createPhotoNode:(PhotoPosition *)photoPosition {
    // Create plane geometry for photo
    SCNPlane *plane = [SCNPlane planeWithWidth:0.1 height:0.1];
    
    // Create material with photo thumbnail
    SCNMaterial *material = [SCNMaterial material];
    material.diffuse.contents = photoPosition.thumbnail;
    material.doubleSided = YES;
    plane.materials = @[material];
    
    // Plane node with +90° Z rotation (visual compensation only)
    SCNNode *planeNode = [SCNNode nodeWithGeometry:plane];
    planeNode.eulerAngles = SCNVector3Make(0, 0, M_PI_2 + M_PI);
    
    // Wrapper node with raw orientation
    SCNNode *wrapper = [SCNNode node];
    wrapper.position = photoPosition.relativePosition;
    SCNVector3 e = photoPosition.relativeEulerAngles;
    e.z = 0; // ignore roll
    wrapper.eulerAngles = e;
    wrapper.name = photoPosition.photoId;
    [wrapper addChildNode:planeNode];
    
    return wrapper;
}

- (SCNNode *)createPreviewNode {
    // Create plane geometry for preview
    SCNPlane *plane = [SCNPlane planeWithWidth:0.1 height:0.1];
    
    // Create material with semi-transparent white
    SCNMaterial *material = [SCNMaterial material];
    material.diffuse.contents = [[UIColor whiteColor] colorWithAlphaComponent:0.5];
    material.doubleSided = YES;
    plane.materials = @[material];
    
    // Create node
    SCNNode *node = [SCNNode nodeWithGeometry:plane];
    node.name = @"PreviewNode";
    
    return node;
}

- (void)notifyDelegate {
    NSMutableArray *positions = [NSMutableArray array];
    [self.photoNodes enumerateKeysAndObjectsUsingBlock:^(NSString *photoId, SCNNode *node, BOOL *stop) {
        PhotoPosition *position = [[PhotoPosition alloc] initWithPhotoId:photoId
                                                        relativePosition:node.position
                                                      relativeEulerAngles:node.eulerAngles
                                                              thumbnail:(UIImage *)node.geometry.firstMaterial.diffuse.contents];
        [positions addObject:position];
    }];
    
    if ([self.delegate respondsToSelector:@selector(didUpdatePhotoPositions:)]) {
        [self.delegate didUpdatePhotoPositions:positions];
    }
}

@end 