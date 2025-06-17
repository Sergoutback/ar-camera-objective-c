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

@end 
