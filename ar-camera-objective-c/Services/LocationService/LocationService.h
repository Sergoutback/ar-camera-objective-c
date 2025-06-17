#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LocationService : NSObject

@property (nonatomic, strong, readonly) CLLocation *currentLocation;

- (void)startLocationUpdates;
- (void)stopLocationUpdates;

@end

NS_ASSUME_NONNULL_END 