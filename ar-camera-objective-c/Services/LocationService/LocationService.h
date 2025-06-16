#import <Foundation/Foundation.h>
#import "LocationServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocationService : NSObject <LocationServiceProtocol, CLLocationManagerDelegate>

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END 