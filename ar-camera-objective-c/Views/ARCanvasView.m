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

- (void)initializeCanvasWithAnchor:(ARAnchor *)anchor {
    if (self.isInitialized) {
        return;
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
    if (!self.isInitialized || !photoPosition.thumbnail) {
        NSLog(@"Cannot add photo: Canvas not initialized or no thumbnail");
        return;
    }
    
    NSLog(@"Adding photo thumbnail with ID: %@", photoPosition.photoId);
    
    SCNNode *photoNode = [self createPhotoNode:photoPosition];
    if (photoNode) {
        [self.canvasNode addChildNode:photoNode];
        self.photoNodes[photoPosition.photoId] = photoNode;
        NSLog(@"Photo node added successfully");
    } else {
        NSLog(@"Failed to create photo node");
    }
}

- (void)updatePhotoThumbnail:(PhotoPosition *)photoPosition {
    SCNNode *existingNode = self.photoNodes[photoPosition.photoId];
    if (existingNode) {
        existingNode.position = photoPosition.relativePosition;
        existingNode.eulerAngles = photoPosition.relativeEulerAngles;
        
        // Update thumbnail if needed
        SCNMaterial *material = existingNode.geometry.firstMaterial;
        material.diffuse.contents = photoPosition.thumbnail;
    }
}

- (void)removePhotoThumbnail:(NSString *)photoId {
    SCNNode *node = self.photoNodes[photoId];
    if (node) {
        [node removeFromParentNode];
        [self.photoNodes removeObjectForKey:photoId];
    }
}

- (void)updateReticlePosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles {
    if (!self.isInitialized) {
        return;
    }
    
    self.reticleNode.position = position;
    self.reticleNode.eulerAngles = eulerAngles;
    self.reticleNode.hidden = NO;
}

- (void)resetCanvas {
    [self.canvasNode removeFromParentNode];
    [self.photoNodes removeAllObjects];
    self.isInitialized = NO;
    self.reticleNode.hidden = YES;
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
    
    // Create node
    SCNNode *node = [SCNNode nodeWithGeometry:plane];
    node.position = photoPosition.relativePosition;
    node.eulerAngles = photoPosition.relativeEulerAngles;
    node.name = photoPosition.photoId;
    
    NSLog(@"Created photo node at position: (%.2f, %.2f, %.2f)", 
          node.position.x, node.position.y, node.position.z);
    
    return node;
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