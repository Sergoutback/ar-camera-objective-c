#import <Foundation/Foundation.h>
#import "ARServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface ARService : NSObject <ARServiceProtocol, ARSCNViewDelegate, ARSessionDelegate>

- (instancetype)initWithSceneView:(ARSCNView *)sceneView;

@end

NS_ASSUME_NONNULL_END 