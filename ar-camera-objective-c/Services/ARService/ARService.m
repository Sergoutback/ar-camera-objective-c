#import "ARService.h"
#import <simd/simd.h>
#import <Metal/Metal.h>
#import <ARKit/ARSCNPlaneGeometry.h>

@interface ARService ()

@property (nonatomic, strong) ARSCNView *sceneView;
@property (nonatomic, strong) ARSession *session;
@property (nonatomic, strong) ARAnchor *initialAnchor;
@property (nonatomic, assign) BOOL isSessionRunning;
@property (nonatomic, assign) BOOL isSpaceScanned;
@property (nonatomic, strong) NSMutableSet<ARPlaneAnchor *> *detectedPlanes;
@property (nonatomic, strong) NSMutableDictionary<NSUUID *, SCNNode *> *planeNodes;
@property (nonatomic, strong) id<MTLDevice> metalDevice;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;

@end

@implementation ARService

- (instancetype)initWithSceneView:(ARSCNView *)sceneView {
    self = [super init];
    if (self) {
        _sceneView = sceneView;
        _session = sceneView.session;
        _sceneView.delegate = self;
        _sceneView.session.delegate = self;
        _isSessionRunning = NO;
        _isSpaceScanned = NO;
        _detectedPlanes = [NSMutableSet set];
        _planeNodes = [NSMutableDictionary dictionary];
        _sceneView.debugOptions = ARSCNDebugOptionShowFeaturePoints;
        
        // Configure AR session
        _sceneView.automaticallyUpdatesLighting = YES;
        _sceneView.preferredFramesPerSecond = 30;
        
        // Configure Metal with optimized settings
        _sceneView.antialiasingMode = SCNAntialiasingModeNone;
        _sceneView.rendersContinuously = NO;
        
        // Initialize Metal device
        self.metalDevice = MTLCreateSystemDefaultDevice();
        if (!self.metalDevice) {
            NSLog(@"Metal is not supported on this device");
        } else {
            self.commandQueue = [self.metalDevice newCommandQueue];
            if (!self.commandQueue) {
                NSLog(@"Failed to create Metal command queue");
            }
        }
        
        // Configure caching
        NSURL *cacheURL = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] firstObject];
        if (cacheURL) {
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtURL:cacheURL
                                    withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:&error];
            if (error) {
                NSLog(@"Failed to create cache directory: %@", error);
            }
        }
        
        [self setupAR];
    }
    return self;
}

- (void)setupAR {
    // Configure AR session with optimized settings
    ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
    configuration.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
    configuration.environmentTexturing = AREnvironmentTexturingNone;
    
    // Set video format for better performance
    NSArray<ARVideoFormat *> *supportedFormats = [ARWorldTrackingConfiguration supportedVideoFormats];
    if (supportedFormats.count > 0) {
        configuration.videoFormat = supportedFormats.firstObject;
    }
    
    @try {
        [self.sceneView.session runWithConfiguration:configuration];
        self.isSessionRunning = YES;
        if ([self.delegate respondsToSelector:@selector(didUpdateARStatusMessage:)]) {
            [self.delegate didUpdateARStatusMessage:@"ARSession started successfully."];
        }
    } @catch (NSException *exception) {
        NSLog(@"AR Session setup failed: %@", exception);
        [self.sceneView.session runWithConfiguration:configuration options:ARSessionRunOptionResetTracking];
    }
}

- (void)startARSession {
    if (!self.isSessionRunning) {
        ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
        configuration.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
        configuration.environmentTexturing = AREnvironmentTexturingNone;
        
        NSArray<ARVideoFormat *> *supportedFormats = [ARWorldTrackingConfiguration supportedVideoFormats];
        if (supportedFormats.count > 0) {
            configuration.videoFormat = supportedFormats.firstObject;
        }
        
        @try {
            [self.sceneView.session runWithConfiguration:configuration];
            self.isSessionRunning = YES;
        } @catch (NSException *exception) {
            NSLog(@"AR Session start failed: %@", exception);
            [self.sceneView.session runWithConfiguration:configuration options:ARSessionRunOptionResetTracking];
        }
    }
}

- (void)pauseARSession {
    if (self.isSessionRunning) {
        [self.sceneView.session pause];
        self.isSessionRunning = NO;
    }
}

- (void)resetARSession {
    ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
    configuration.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
    configuration.environmentTexturing = AREnvironmentTexturingAutomatic;
    NSArray<ARVideoFormat *> *supportedFormats = [ARWorldTrackingConfiguration supportedVideoFormats];
    if (supportedFormats.count > 0) {
        configuration.videoFormat = supportedFormats.firstObject;
    }
    [self.sceneView.session runWithConfiguration:configuration
                                         options:ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors];
    self.isSessionRunning = YES;
    // Очистить все плоскости и их визуализацию
    [self.detectedPlanes removeAllObjects];
    [self.planeNodes removeAllObjects];
    // Удалить все дочерние узлы с rootNode, кроме камеры и света
    NSArray *childNodes = [self.sceneView.scene.rootNode.childNodes copy];
    for (SCNNode *node in childNodes) {
        [node removeFromParentNode];
    }
}

- (void)updatePreviewPosition:(SCNVector3)position eulerAngles:(SCNVector3)eulerAngles {
    if ([self.delegate respondsToSelector:@selector(didUpdateCameraPosition:eulerAngles:)]) {
        [self.delegate didUpdateCameraPosition:position eulerAngles:eulerAngles];
    }
}

- (void)capturePhotoWithCompletion:(void (^)(UIImage * _Nullable, NSError * _Nullable))completion {
    if (!self.isSessionRunning) {
        NSError *error = [NSError errorWithDomain:@"ARServiceErrorDomain"
                                           code:2
                                       userInfo:@{NSLocalizedDescriptionKey: @"AR session is not running"}];
        if (completion) { completion(nil, error); }
        return;
    }
    
    ARFrame *currentFrame = self.sceneView.session.currentFrame;
    if (!currentFrame) {
        NSError *error = [NSError errorWithDomain:@"ARServiceErrorDomain"
                                           code:3
                                       userInfo:@{NSLocalizedDescriptionKey: @"No current AR frame available"}];
        if (completion) { completion(nil, error); }
        return;
    }
    
    CVPixelBufferRef pixelBuffer = currentFrame.capturedImage;
    if (!pixelBuffer) {
        NSError *error = [NSError errorWithDomain:@"ARServiceErrorDomain"
                                           code:4
                                       userInfo:@{NSLocalizedDescriptionKey: @"Failed to get camera image"}];
        if (completion) { completion(nil, error); }
        return;
    }
    CFRetain(pixelBuffer); // retain for async conversion
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        if (!ciImage) {
            NSError *error = [NSError errorWithDomain:@"ARServiceErrorDomain"
                                               code:5
                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to create image from camera data"}];
            CFRelease(pixelBuffer);
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); });
            return;
        }
        CIContext *context = [CIContext contextWithOptions:nil];
        CGImageRef cgImage = [context createCGImage:ciImage fromRect:ciImage.extent];
        CFRelease(pixelBuffer);
        if (!cgImage) {
            NSError *error = [NSError errorWithDomain:@"ARServiceErrorDomain"
                                               code:6
                                           userInfo:@{NSLocalizedDescriptionKey: @"Failed to create final image"}];
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(nil, error); });
            return;
        }
        UIImage *image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (image) {
                if (completion) completion(image, nil);
            } else {
                NSError *error = [NSError errorWithDomain:@"ARServiceErrorDomain"
                                                   code:7
                                               userInfo:@{NSLocalizedDescriptionKey: @"Failed to create final UIImage"}];
                if (completion) completion(nil, error);
            }
        });
    });
}

- (void)placePhotoInAR:(UIImage *)photo atPosition:(SCNVector3)position withRotation:(SCNVector3)rotation {
    if (!photo) return;
    
    // Create a plane node for the photo
    SCNPlane *plane = [SCNPlane planeWithWidth:0.3 height:0.2];
    SCNMaterial *material = [SCNMaterial new];
    material.diffuse.contents = photo;
    plane.materials = @[material];
    
    SCNNode *photoNode = [SCNNode nodeWithGeometry:plane];
    
    // Get camera position and orientation
    SCNNode *cameraNode = self.sceneView.pointOfView;
    if (cameraNode) {
        // Current camera transform
        simd_float4x4 cameraTransform = self.sceneView.session.currentFrame.camera.transform;

        // 1. Position: use the current camera position (no forward offset)
        simd_float4 worldPosition = cameraTransform.columns[3];
        photoNode.position = SCNVector3Make(worldPosition.x, worldPosition.y, worldPosition.z);

        // 2. Orientation: take ARKit-calculated Euler angles to keep real device roll
        simd_float3 cameraEuler = self.sceneView.session.currentFrame.camera.eulerAngles;
        SCNVector3 camEuler = SCNVector3Make(cameraEuler.x, cameraEuler.y, cameraEuler.z);

        // Apply: pitch / yaw (+180° so the plane faces the user) / roll (+90° to compensate portrait sensor)
        float pitch = camEuler.x;           // rotation around X (pitch)
        float yaw   = camEuler.y;           // directly use yaw – SCNPlane already faces camera
        float roll  = camEuler.z + M_PI_2;  // keep real tilt while fixing portrait orientation

        photoNode.eulerAngles = SCNVector3Make(pitch, yaw, roll);

        // Apply additional rotations
        photoNode.eulerAngles = SCNVector3Make(
            photoNode.eulerAngles.x + rotation.x,
            photoNode.eulerAngles.y + rotation.y,
            photoNode.eulerAngles.z + rotation.z
        );
    } else {
        photoNode.position = position;
        photoNode.eulerAngles = rotation;
    }
    
    // Add to scene
    [self.sceneView.scene.rootNode addChildNode:photoNode];
}

// Helper method to get camera direction vector
- (SCNVector3)getCameraDirection:(SCNNode *)cameraNode {
    // Convert camera's -Z axis to world space
    SCNVector3 direction = SCNVector3Make(0, 0, -1);
    SCNMatrix4 transform = cameraNode.transform;
    
    // Apply rotation part of transform
    direction = SCNVector3Make(
        direction.x * transform.m11 + direction.y * transform.m21 + direction.z * transform.m31,
        direction.x * transform.m12 + direction.y * transform.m22 + direction.z * transform.m32,
        direction.x * transform.m13 + direction.y * transform.m23 + direction.z * transform.m33
    );
    
    return direction;
}

- (SCNNode *)createPlaneNode:(ARPlaneAnchor *)planeAnchor {
    // -------- Plane visualisation --------
    // We draw two geometries for every detected plane:
    // 1. A semi-transparent fill so the user sees the detected area.
    // 2. A wireframe outline so the borders are clearly visible.

    // 1) Build the base geometry using ARSCNPlaneGeometry so that it matches the exact
    //    shape that ARKit has detected (can be a non-rectangular polygon).
    id<MTLDevice> device = self.sceneView.device ?: MTLCreateSystemDefaultDevice();
    if (!device) {
        // Fallback – just return empty node if Metal is not available
        return [SCNNode node];
    }

    ARSCNPlaneGeometry *fillGeometry = [ARSCNPlaneGeometry planeGeometryWithDevice:device];
    [fillGeometry updateFromPlaneGeometry:planeAnchor.geometry];

    // Fill material (semi-transparent colour depends on plane alignment)
    SCNMaterial *fillMaterial = [SCNMaterial material];
    UIColor *planeColor = (planeAnchor.alignment == ARPlaneAnchorAlignmentHorizontal)
        ? [UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:0.6]   // Greenish for horizontal
        : [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:0.6];   // Bluish for vertical
    fillMaterial.diffuse.contents = planeColor;
    // Ensure the fill is rendered even if underlying geometry matches the same plane:
    fillMaterial.readsFromDepthBuffer = NO;    // render on top to avoid z-fighting with outline
    fillMaterial.lightingModelName = SCNLightingModelConstant;
    fillMaterial.doubleSided = YES;
    fillGeometry.materials = @[fillMaterial];
    SCNNode *fillNode = [SCNNode nodeWithGeometry:fillGeometry];

    // 2) Build outline geometry – duplicate of the fill but rendered in line mode
    ARSCNPlaneGeometry *outlineGeometry = [ARSCNPlaneGeometry planeGeometryWithDevice:device];
    [outlineGeometry updateFromPlaneGeometry:planeAnchor.geometry];

    SCNMaterial *outlineMaterial = [SCNMaterial material];
    outlineMaterial.diffuse.contents = [UIColor whiteColor];
    outlineMaterial.lightingModelName = SCNLightingModelConstant;
    outlineMaterial.fillMode = SCNFillModeLines;   // Render as wireframe
    outlineMaterial.doubleSided = YES;
    outlineGeometry.materials = @[outlineMaterial];
    SCNNode *outlineNode = [SCNNode nodeWithGeometry:outlineGeometry];

    // Container node that holds both fill and outline
    SCNNode *containerNode = [SCNNode node];
    [containerNode addChildNode:fillNode];
    [containerNode addChildNode:outlineNode];

    // Position the node at the anchor's centre
    containerNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z);

    // ARSCNPlaneGeometry already matches the anchor orientation, no extra rotation is needed.
    return containerNode;
}

#pragma mark - ARSCNViewDelegate

- (void)renderer:(id<SCNSceneRenderer>)renderer didAddNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
        ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;
        [self.detectedPlanes addObject:planeAnchor];
        
        // Create and add plane visualization
        SCNNode *planeNode = [self createPlaneNode:planeAnchor];
        [node addChildNode:planeNode];
        self.planeNodes[planeAnchor.identifier] = planeNode;
        
        // Check if we have enough planes detected
        [self checkSpaceScanningStatus];
        if ([self.delegate respondsToSelector:@selector(didUpdateARStatusMessage:)]) {
            NSString *msg = [NSString stringWithFormat:@"Plane detected: %@", planeAnchor.alignment == ARPlaneAnchorAlignmentHorizontal ? @"Horizontal" : @"Vertical"];
            [self.delegate didUpdateARStatusMessage:msg];
        }
    }
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didUpdateNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
        ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;
        [self.detectedPlanes addObject:planeAnchor];
        
        // Update plane visualization (both fill and outline geometries)
        SCNNode *planeNode = self.planeNodes[planeAnchor.identifier];
        if (planeNode) {
            // Iterate over the child nodes (fill & outline) and refresh their geometries
            for (SCNNode *child in planeNode.childNodes) {
                if ([child.geometry isKindOfClass:[ARSCNPlaneGeometry class]]) {
                    ARSCNPlaneGeometry *geo = (ARSCNPlaneGeometry *)child.geometry;
                    [geo updateFromPlaneGeometry:planeAnchor.geometry];
                }
            }

            // Keep container node centred on the updated anchor
            planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z);
        }
        
        // Check if we have enough planes detected
        [self checkSpaceScanningStatus];
    }
}

- (void)renderer:(id<SCNSceneRenderer>)renderer didRemoveNode:(SCNNode *)node forAnchor:(ARAnchor *)anchor {
    if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
        ARPlaneAnchor *planeAnchor = (ARPlaneAnchor *)anchor;
        [self.detectedPlanes removeObject:planeAnchor];
        [self.planeNodes removeObjectForKey:planeAnchor.identifier];
        
        // Check if we have enough planes detected
        [self checkSpaceScanningStatus];
    }
}

- (void)checkSpaceScanningStatus {
    BOOL hasHorizontalPlane = NO;
    BOOL hasVerticalPlane = NO;
    int horizontalCount = 0;
    int verticalCount = 0;
    for (ARPlaneAnchor *plane in self.detectedPlanes) {
        if (plane.alignment == ARPlaneAnchorAlignmentHorizontal) {
            hasHorizontalPlane = YES;
            horizontalCount++;
        } else if (plane.alignment == ARPlaneAnchorAlignmentVertical) {
            hasVerticalPlane = YES;
            verticalCount++;
        }
    }
    BOOL wasScanned = self.isSpaceScanned;
    self.isSpaceScanned = hasHorizontalPlane && hasVerticalPlane;
    // Only update the scan status via the delegate
    if (wasScanned != self.isSpaceScanned && [self.delegate respondsToSelector:@selector(didUpdateSpaceScanningStatus:)]) {
        [self.delegate didUpdateSpaceScanningStatus:self.isSpaceScanned];
    }
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame {
    if (self.initialAnchor) {
        matrix_float4x4 anchorTransform = self.initialAnchor.transform;
        matrix_float4x4 cameraTransform = frame.camera.transform;
        matrix_float4x4 relativeTransform = matrix_multiply(matrix_invert(anchorTransform), cameraTransform);
        
        // Extract position and rotation
        SCNVector3 position = SCNVector3Make(relativeTransform.columns[3].x,
                                           relativeTransform.columns[3].y,
                                           relativeTransform.columns[3].z);
        
        // Convert rotation matrix to euler angles
        SCNVector3 eulerAngles = [self extractEulerAnglesFromMatrix:relativeTransform];
        
        [self updatePreviewPosition:position eulerAngles:eulerAngles];
    }
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session didFailWithError:(NSError *)error {
    self.isSessionRunning = NO;
    NSLog(@"AR Session failed: %@", error);
    if ([self.delegate respondsToSelector:@selector(didUpdateARStatusMessage:)]) {
        [self.delegate didUpdateARStatusMessage:[NSString stringWithFormat:@"AR Session failed: %@", error.localizedDescription]];
    }
}

- (void)sessionWasInterrupted:(ARSession *)session {
    self.isSessionRunning = NO;
    NSLog(@"AR Session interrupted");
}

- (void)sessionInterruptionEnded:(ARSession *)session {
    self.isSessionRunning = YES;
    NSLog(@"AR Session interruption ended");
}

- (simd_float4x4)currentCameraTransform {
    ARFrame *frame = self.sceneView.session.currentFrame;
    return frame ? frame.camera.transform : matrix_identity_float4x4;
}

- (simd_float3)currentCameraEulerAngles {
    ARFrame *frame = self.sceneView.session.currentFrame;
    return frame ? frame.camera.eulerAngles : (simd_float3){0,0,0};
}

- (matrix_float3x3)currentCameraIntrinsics {
    ARFrame *frame = self.sceneView.session.currentFrame;
    return frame ? frame.camera.intrinsics : (matrix_float3x3){{{0,0,0},{0,0,0},{0,0,0}}};
}

- (NSTimeInterval)currentFrameTimestamp {
    ARFrame *frame = self.sceneView.session.currentFrame;
    return frame ? frame.timestamp : 0;
}

- (ARFrame *)currentFrame {
    return self.sceneView.session.currentFrame;
}

#pragma mark - Private Methods

- (SCNVector3)extractEulerAnglesFromMatrix:(matrix_float4x4)matrix {
    // Extract rotation matrix
    float m11 = matrix.columns[0].x;
    float m21 = matrix.columns[1].x;
    float m31 = matrix.columns[2].x;
    float m32 = matrix.columns[2].y;
    float m33 = matrix.columns[2].z;
    
    // Calculate euler angles
    float pitch = asin(-m31);
    float yaw = atan2(m11, m21);
    float roll = atan2(m32, m33);
    
    return SCNVector3Make(pitch, yaw, roll);
}

- (void)startARSessionWithWorldMap:(ARWorldMap * _Nullable)worldMap {
    ARWorldTrackingConfiguration *configuration = [[ARWorldTrackingConfiguration alloc] init];
    configuration.planeDetection = ARPlaneDetectionHorizontal | ARPlaneDetectionVertical;
    configuration.environmentTexturing = AREnvironmentTexturingNone;
    // Restore world map if provided and supported
    if (worldMap) {
        if (@available(iOS 12.0, *)) {
            configuration.initialWorldMap = worldMap;
        }
    }
    NSArray<ARVideoFormat *> *supportedFormats = [ARWorldTrackingConfiguration supportedVideoFormats];
    if (supportedFormats.count > 0) {
        configuration.videoFormat = supportedFormats.firstObject;
    }

    @try {
        [self.sceneView.session runWithConfiguration:configuration options:0];
        self.isSessionRunning = YES;
        if ([self.delegate respondsToSelector:@selector(didUpdateARStatusMessage:)]) {
            [self.delegate didUpdateARStatusMessage:@"ARSession restarted with restored map."];
        }
    } @catch (NSException *exception) {
        NSLog(@"AR Session restart failed: %@", exception);
        [self.sceneView.session runWithConfiguration:configuration options:ARSessionRunOptionResetTracking];
    }
}

@end 
