#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PhotoServiceProtocol <NSObject>

- (void)savePhoto:(UIImage *)image
        metadata:(NSDictionary *)metadata
      completion:(void (^)(BOOL success, NSError * _Nullable error))completion;

- (void)requestPhotoLibraryPermission:(void (^)(BOOL granted))completion;

@end

NS_ASSUME_NONNULL_END 