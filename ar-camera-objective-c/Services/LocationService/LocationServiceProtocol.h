#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol LocationServiceProtocol <NSObject>

@property (nonatomic, strong, readonly) CLLocationManager *locationManager;
@property (nonatomic, strong, readonly) CLLocation *currentLocation;

- (void)startLocationUpdates;
- (void)stopLocationUpdates;
- (void)requestLocationPermission;
- (void)getCurrentLocationWithCompletion:(void (^)(CLLocation * _Nullable location, NSError * _Nullable error))completion;

@end

NS_ASSUME_NONNULL_END 