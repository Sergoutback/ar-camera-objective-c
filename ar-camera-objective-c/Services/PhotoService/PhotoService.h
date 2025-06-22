#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PhotoServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface PhotoService : NSObject <PhotoServiceProtocol>

- (instancetype)init;

/// Clears cached images and metadata so a fresh capture session can begin.
- (void)resetSession;

@end

NS_ASSUME_NONNULL_END 