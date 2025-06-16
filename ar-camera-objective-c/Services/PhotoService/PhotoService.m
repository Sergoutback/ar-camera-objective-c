#import "PhotoService.h"
#import <Photos/Photos.h>

@interface PhotoService ()
@property (nonatomic, strong) NSMutableDictionary *photoCache;
@end

@implementation PhotoService

- (instancetype)init {
    self = [super init];
    if (self) {
        self.photoCache = [NSMutableDictionary dictionary];
        
        // Create metadata directory if it doesn't exist
        NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *metadataPath = [documentsPath stringByAppendingPathComponent:@"PhotoMetadata"];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        if (![fileManager fileExistsAtPath:metadataPath]) {
            NSError *error;
            [fileManager createDirectoryAtPath:metadataPath withIntermediateDirectories:YES attributes:nil error:&error];
            if (error) {
                NSLog(@"Error creating metadata directory: %@", error);
            }
        }
    }
    return self;
}

- (void)requestPhotoLibraryPermission:(void (^)(BOOL))completion {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    
    if (status == PHAuthorizationStatusAuthorized) {
        completion(YES);
    } else if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(status == PHAuthorizationStatusAuthorized);
            });
        }];
    } else {
        completion(NO);
    }
}

- (void)savePhoto:(UIImage *)image
        metadata:(NSDictionary *)metadata
      completion:(void (^)(BOOL, NSError * _Nullable))completion {
    
    [self requestPhotoLibraryPermission:^(BOOL granted) {
        if (!granted) {
            NSError *error = [NSError errorWithDomain:@"PhotoServiceErrorDomain"
                                               code:1
                                           userInfo:@{NSLocalizedDescriptionKey: @"Photo library access denied"}];
            completion(NO, error);
            return;
        }
        
        // Generate unique identifier for this photo
        NSString *photoId = [[NSUUID UUID] UUIDString];
        
        // Cache the image
        self.photoCache[photoId] = image;
        
        // Save metadata to JSON file
        if (metadata) {
            NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *metadataPath = [documentsPath stringByAppendingPathComponent:@"PhotoMetadata"];
            NSString *jsonPath = [metadataPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.json", photoId]];
            
            NSError *jsonError;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:metadata
                                                             options:NSJSONWritingPrettyPrinted
                                                               error:&jsonError];
            
            if (jsonError) {
                NSLog(@"Error creating JSON data: %@", jsonError);
            } else {
                BOOL jsonSuccess = [jsonData writeToFile:jsonPath atomically:YES];
                if (!jsonSuccess) {
                    NSLog(@"Error writing JSON file to path: %@", jsonPath);
                }
            }
        }
        
        // Save photo to photo library
        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
            PHAssetCreationRequest *request = [PHAssetCreationRequest creationRequestForAssetFromImage:image];
            
            // Add location metadata if available
            if (metadata[@"location"]) {
                CLLocation *location = [[CLLocation alloc] initWithLatitude:[metadata[@"location"][@"latitude"] doubleValue]
                                                                longitude:[metadata[@"location"][@"longitude"] doubleValue]];
                request.location = location;
            }
            
            // Add photo ID to asset metadata using resource options
            if (metadata) {
                NSMutableDictionary *assetMetadata = [NSMutableDictionary dictionary];
                assetMetadata[@"photoId"] = photoId;
                
                NSData *metadataData = [NSJSONSerialization dataWithJSONObject:assetMetadata
                                                                      options:0
                                                                        error:nil];
                if (metadataData) {
                    PHAssetResourceCreationOptions *options = [[PHAssetResourceCreationOptions alloc] init];
                    options.shouldMoveFile = YES;
                    [request addResourceWithType:PHAssetResourceTypePhoto
                                          data:metadataData
                                       options:options];
                }
            }
            
        } completionHandler:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    NSLog(@"Photo saved successfully with ID: %@", photoId);
                } else {
                    NSLog(@"Error saving photo: %@", error);
                }
                completion(success, error);
            });
        }];
    }];
}

- (void)exportSessionData:(void (^)(NSURL * _Nullable sessionURL, NSError * _Nullable error))completion {
    // Create a temporary directory for the session
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"ARSession"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    // Remove existing temp directory if it exists
    if ([fileManager fileExistsAtPath:tempDir]) {
        [fileManager removeItemAtPath:tempDir error:nil];
    }
    
    // Create new temp directory
    NSError *error;
    [fileManager createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:&error];
    
    if (error) {
        completion(nil, error);
        return;
    }
    
    // Create subdirectories
    NSString *pngDir = [tempDir stringByAppendingPathComponent:@"PNG"];
    NSString *heicDir = [tempDir stringByAppendingPathComponent:@"HEIC"];
    NSString *jsonDir = [tempDir stringByAppendingPathComponent:@"JSON"];
    
    [fileManager createDirectoryAtPath:pngDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fileManager createDirectoryAtPath:heicDir withIntermediateDirectories:YES attributes:nil error:nil];
    [fileManager createDirectoryAtPath:jsonDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Get metadata directory
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *metadataPath = [documentsPath stringByAppendingPathComponent:@"PhotoMetadata"];
    
    // Copy JSON files
    NSArray *jsonFiles = [fileManager contentsOfDirectoryAtPath:metadataPath error:&error];
    if (error) {
        completion(nil, error);
        return;
    }
    
    for (NSString *jsonFile in jsonFiles) {
        if ([jsonFile.pathExtension isEqualToString:@"json"]) {
            NSString *sourcePath = [metadataPath stringByAppendingPathComponent:jsonFile];
            NSString *destPath = [jsonDir stringByAppendingPathComponent:jsonFile];
            [fileManager copyItemAtPath:sourcePath toPath:destPath error:&error];
            if (error) {
                NSLog(@"Error copying JSON file %@: %@", jsonFile, error);
            }
        }
    }
    
    // Save cached images
    dispatch_group_t group = dispatch_group_create();
    
    for (NSString *photoId in self.photoCache) {
        UIImage *image = self.photoCache[photoId];
        
        // Save PNG
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *pngPath = [pngDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png", photoId]];
            NSData *pngData = UIImagePNGRepresentation(image);
            [pngData writeToFile:pngPath atomically:YES];
        });
        
        // Save HEIC
        dispatch_group_async(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *heicPath = [heicDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.heic", photoId]];
            NSData *heicData = UIImageJPEGRepresentation(image, 0.8);
            [heicData writeToFile:heicPath atomically:YES];
        });
    }
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        completion([NSURL fileURLWithPath:tempDir], nil);
    });
}

@end 
