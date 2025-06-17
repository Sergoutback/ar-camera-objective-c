#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PhotoPosition : NSObject

@property (nonatomic, strong) NSString *photoId;
@property (nonatomic, assign) SCNVector3 relativePosition;
@property (nonatomic, assign) SCNVector3 relativeEulerAngles;
@property (nonatomic, strong) UIImage *thumbnail;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSString *imagePath;

- (instancetype)initWithPhotoId:(NSString *)photoId
                relativePosition:(SCNVector3)position
              relativeEulerAngles:(SCNVector3)eulerAngles
                      thumbnail:(UIImage *)thumbnail;

- (NSDictionary *)toDictionary;

@end

NS_ASSUME_NONNULL_END 