#import "ARCanvasView.h"

@interface ARCanvasView ()

@property (nonatomic, strong) ARSCNView *sceneView;
@property (nonatomic, strong) SCNNode *canvasNode;
@property (nonatomic, strong) SCNNode *reticleNode;
@property (nonatomic, strong) NSMutableDictionary<NSString *, SCNNode *> *photoNodes;
@property (nonatomic, assign) BOOL isInitialized;
@property (nonatomic, assign) float canvasDistance;

@end

@implementation ARCanvasView

- (instancetype)initWithSceneView:(ARSCNView *)sceneView {
    self = [super init];
    if (self) {
        _sceneView = sceneView;
        _photoNodes = [NSMutableDictionary dictionary];
        _isInitialized = NO;
        _canvasDistance = 1.5;
        
        // Create reticle node
        _reticleNode = [self createReticleNode];
        _reticleNode.hidden = YES;
        [sceneView.scene.rootNode addChildNode:_reticleNode];
    }
    return self;
}

// Helper to ensure SceneKit mutations happen on the main thread
static inline BOOL EnsureMainThread(void (^block)(void)) {
    if (NSThread.isMainThread) {
        return NO; // already on main
    }
    dispatch_async(dispatch_get_main_queue(), block);
    return YES; // scheduled on main, caller must return
}

- (void)initializeCanvasWithAnchor:(ARAnchor *)anchor {
    if (EnsureMainThread(^{ [self initializeCanvasWithAnchor:anchor]; })) { return; }
    
    if (self.isInitialized) {
        return;
    }
    
    // Safety: remove any previous PhotoCanvas that may still be in the scene
    SCNNode *oldCanvas = [self.sceneView.scene.rootNode childNodeWithName:@"PhotoCanvas" recursively:YES];
    if (oldCanvas) {
        [oldCanvas removeFromParentNode];
    }
    
    // Get current camera transform
    ARFrame *currentFrame = self.sceneView.session.currentFrame;
    if (!currentFrame) {
        return;
    }
    
    // Create canvas node
    self.canvasNode = [SCNNode node];
    self.canvasNode.name = @"PhotoCanvas";
    
    // Position canvas in front of the camera
    matrix_float4x4 cameraTransform = currentFrame.camera.transform;
    simd_float3 cameraPosition = simd_make_float3(cameraTransform.columns[3].x,
                                                cameraTransform.columns[3].y,
                                                cameraTransform.columns[3].z);
    simd_float3 cameraForward = simd_make_float3(-cameraTransform.columns[2].x,
                                                -cameraTransform.columns[2].y,
                                                -cameraTransform.columns[2].z);
    simd_float3 canvasPosition = cameraPosition + (cameraForward * self.canvasDistance);
    
    // Create anchor node at canvas position
    SCNNode *anchorNode = [SCNNode node];
    anchorNode.name = @"AnchorNode";
    anchorNode.position = SCNVector3Make(canvasPosition.x, canvasPosition.y, canvasPosition.z);
    
    // Rotate canvas to face camera
    simd_float3 up = simd_make_float3(0, 1, 0);
    simd_float3 right = simd_normalize(simd_cross(cameraForward, up));
    simd_float3 newUp = simd_normalize(simd_cross(right, cameraForward));
    
    SCNMatrix4 transform = SCNMatrix4Identity;
    transform.m11 = right.x; transform.m12 = right.y; transform.m13 = right.z;
    transform.m21 = newUp.x; transform.m22 = newUp.y; transform.m23 = newUp.z;
    transform.m31 = -cameraForward.x; transform.m32 = -cameraForward.y; transform.m33 = -cameraForward.z;
    
    anchorNode.transform = transform;
    
    [self.sceneView.scene.rootNode addChildNode:anchorNode];
    [anchorNode addChildNode:self.canvasNode];
    
    self.isInitialized = YES;
}

- (void)addPhotoThumbnail:(PhotoPosition *)photoPosition {
    if (EnsureMainThread(^{ [self addPhotoThumbnail:photoPosition]; })) { return; }
    
    if (!self.isInitialized || !photoPosition.thumbnail) {
        NSLog(@"Cannot add photo: Canvas not initialized or no thumbnail");
        return;
    }
    
    NSLog(@"Adding photo thumbnail with ID: %@", photoPosition.photoId);
    
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0];
    // Remove old node with same photoId if it exists (prevent duplicate insertion assertions)
    SCNNode *existingNode = self.photoNodes[photoPosition.photoId];
    if (existingNode) {
        [existingNode removeFromParentNode];
        [self.photoNodes removeObjectForKey:photoPosition.photoId];
    }

    // Additionally, check direct children of canvasNode in case dictionary was out of sync
    SCNNode *dupChild = [self.canvasNode childNodeWithName:photoPosition.photoId recursively:NO];
    if (dupChild) {
        [dupChild removeFromParentNode];
    }

    SCNNode *photoNode = [self createPhotoNode:photoPosition];
    if (photoNode) {
        [self.canvasNode addChildNode:photoNode];
        self.photoNodes[photoPosition.photoId] = photoNode;
        NSLog(@"Photo node added successfully");
    } else {
        NSLog(@"Failed to create photo node");
    }
    [SCNTransaction commit];
}

- (void)updatePhotoThumbnail:(PhotoPosition *)photoPosition {
    if (EnsureMainThread(^{ [self updatePhotoThumbnail:photoPosition]; })) { return; }
    
    SCNNode *existingNode = self.photoNodes[photoPosition.photoId];
    if (existingNode) {
        // Convert world space to canvas local
        SCNVector3 localPosition = [self.canvasNode convertPosition:photoPosition.relativePosition fromNode:nil];
        existingNode.position = localPosition;
        SCNVector3 e2 = photoPosition.relativeEulerAngles;
        e2.z = 0; // ignore roll
        existingNode.eulerAngles = e2;
        
        // Update thumbnail if needed
        SCNMaterial *material = existingNode.geometry.firstMaterial;
        material.diffuse.contents = photoPosition.thumbnail;
    }
}

- (void)removePhotoThumbnail:(NSString *)photoId {
    if (EnsureMainThread(^{ [self removePhotoThumbnail:photoId]; })) { return; }
    
    SCNNode *node = self.photoNodes[photoId];
    if (node) {
        [node removeFromParentNode];
        [self.photoNodes removeObjectForKey:photoId];
    }
}

- (void)updateReticlePosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles {
    if (EnsureMainThread(^{ [self updateReticlePosition:position eulerAngles:eulerAngles]; })) { return; }
    
    if (!self.isInitialized) {
        return;
    }
    
    self.reticleNode.position = position;
    self.reticleNode.eulerAngles = eulerAngles;
    self.reticleNode.hidden = NO;
}

- (void)resetCanvas {
    if (EnsureMainThread(^{ [self resetCanvas]; })) { return; }
    
    // Replace entire scene with a fresh one to avoid residual nodes and threading issues
    self.sceneView.scene = [SCNScene scene];
    
    // Reset state holders
    [self.photoNodes removeAllObjects];
    self.canvasNode   = nil;
    
    // Create a new hidden reticle and add to fresh scene
    self.reticleNode = [self createReticleNode];
    self.reticleNode.hidden = YES;
    [self.sceneView.scene.rootNode addChildNode:self.reticleNode];
    
    self.isInitialized = NO;
    return;
}

#pragma mark - Private Methods

- (SCNNode *)createPhotoNode:(PhotoPosition *)photoPosition {
    if (!photoPosition.thumbnail) {
        NSLog(@"No thumbnail available for photo");
        return nil;
    }
    
    // Create plane geometry for photo
    SCNPlane *plane = [SCNPlane planeWithWidth:0.2 height:0.2];
    
    // Create material with photo thumbnail
    SCNMaterial *material = [SCNMaterial material];
    material.diffuse.contents = photoPosition.thumbnail;
    plane.materials = @[material];
    
    // Plane node rotated +90° around Z to compensate portrait roll (visual only)
    SCNNode *planeNode = [SCNNode nodeWithGeometry:plane];
    // Rotate +90° to compensate roll, then +180° to flip upside-down image
    planeNode.eulerAngles = SCNVector3Make(0, 0, M_PI_2 + M_PI);
    
    // Wrapper node that carries local position/euler relative to canvas
    SCNNode *wrapper = [SCNNode node];
    // Convert world space position to canvas local space for stable placement
    SCNVector3 localPosition = [self.canvasNode convertPosition:photoPosition.relativePosition fromNode:nil];
    wrapper.position = localPosition;
    SCNVector3 e = photoPosition.relativeEulerAngles;
    e.z = 0; // ignore roll so portrait/landscape does not flip plane
    wrapper.eulerAngles = e;
    wrapper.name = photoPosition.photoId;
    [wrapper addChildNode:planeNode];
    
    NSLog(@"Created photo node at position: (%.2f, %.2f, %.2f)",
          wrapper.position.x, wrapper.position.y, wrapper.position.z);
    
    return wrapper;
}

- (SCNNode *)createReticleNode {
    // Create reticle geometry
    SCNPlane *plane = [SCNPlane planeWithWidth:0.15 height:0.15];
    
    // Create material with reticle texture
    SCNMaterial *material = [SCNMaterial material];
    material.diffuse.contents = [self createReticleTexture];
    material.doubleSided = YES;
    plane.materials = @[material];
    
    // Create node
    SCNNode *node = [SCNNode nodeWithGeometry:plane];
    node.name = @"ReticleNode";
    
    return node;
}

- (UIImage *)createReticleTexture {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(256, 256), NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Draw reticle frame
    CGRect rect = CGRectMake(0, 0, 256, 256);
    CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(context, 4.0);
    
    // Draw outer frame
    CGContextStrokeRect(context, CGRectInset(rect, 20, 20));
    
    // Draw inner frame
    CGContextStrokeRect(context, CGRectInset(rect, 60, 60));
    
    // Draw crosshair
    CGFloat center = 128;
    CGContextMoveToPoint(context, center - 40, center);
    CGContextAddLineToPoint(context, center + 40, center);
    CGContextMoveToPoint(context, center, center - 40);
    CGContextAddLineToPoint(context, center, center + 40);
    CGContextStrokePath(context);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)dealloc {
    [self.reticleNode removeFromParentNode];
    [self.canvasNode removeFromParentNode];
}

@end 
