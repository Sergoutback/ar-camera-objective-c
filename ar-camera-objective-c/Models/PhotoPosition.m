#import "PhotoPosition.h"

@implementation PhotoPosition

- (instancetype)initWithPhotoId:(NSString *)photoId
                relativePosition:(SCNVector3)position
              relativeEulerAngles:(SCNVector3)eulerAngles
                      thumbnail:(UIImage *)thumbnail {
    self = [super init];
    if (self) {
        _photoId = photoId;
        _relativePosition = position;
        _relativeEulerAngles = eulerAngles;
        _thumbnail = thumbnail;
        _timestamp = [NSDate date];
    }
    return self;
}

- (NSDictionary *)toDictionary {
    return @{
        @"photoId": self.photoId ?: @"",
        @"imagePath": self.imagePath ?: @"",
        @"relativePosition": @{
            @"x": @(self.relativePosition.x),
            @"y": @(self.relativePosition.y),
            @"z": @(self.relativePosition.z)
        },
        @"relativeEulerAngles": @{
            @"x": @(self.relativeEulerAngles.x),
            @"y": @(self.relativeEulerAngles.y),
            @"z": @(self.relativeEulerAngles.z)
        },
        @"timestamp": self.timestamp ? @([self.timestamp timeIntervalSince1970]) : @(0)
    };
}

@end 
