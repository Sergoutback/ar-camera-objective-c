#import "LocationService.h"

@interface LocationService ()

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) CLLocation *currentLocation;

@end

@implementation LocationService

- (instancetype)init {
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    return self;
}

- (void)startLocationUpdates {
    [self.locationManager startUpdatingLocation];
}

- (void)stopLocationUpdates {
    [self.locationManager stopUpdatingLocation];
}

- (void)requestLocationPermission {
    [self.locationManager requestWhenInUseAuthorization];
}

- (void)getCurrentLocationWithCompletion:(void (^)(CLLocation * _Nullable, NSError * _Nullable))completion {
    if (self.currentLocation) {
        completion(self.currentLocation, nil);
    } else {
        NSError *error = [NSError errorWithDomain:@"LocationServiceErrorDomain"
                                           code:1
                                       userInfo:@{NSLocalizedDescriptionKey: @"No location data available"}];
        completion(nil, error);
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    self.currentLocation = locations.lastObject;
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Location manager failed with error: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    switch (status) {
        case kCLAuthorizationStatusAuthorizedWhenInUse:
        case kCLAuthorizationStatusAuthorizedAlways:
            [self startLocationUpdates];
            break;
        default:
            [self stopLocationUpdates];
            break;
    }
}

@end 