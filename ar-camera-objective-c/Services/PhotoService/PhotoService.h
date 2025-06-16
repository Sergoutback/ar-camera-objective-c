#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "PhotoServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PhotoServiceProtocol <NSObject>

- (void)requestPhotoLibraryPermission:(void (^)(BOOL))completion;
- (void)savePhoto:(UIImage *)image metadata:(NSDictionary *)metadata completion:(void (^)(BOOL, NSError * _Nullable))completion;
- (void)exportSessionData:(void (^)(NSURL * _Nullable sessionURL, NSError * _Nullable error))completion;

@end

@interface PhotoService : NSObject <PhotoServiceProtocol>

- (instancetype)init;

@end

NS_ASSUME_NONNULL_END 