/**
 * @file ARCameraViewModel.h
 * @brief ViewModel for managing AR camera functionality
 *
 * This ViewModel is responsible for coordinating between AR, motion, and location services
 * to provide a unified interface for capturing photos with metadata.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "../Services/ARService/ARServiceProtocol.h"
#import "../Services/MotionService/MotionServiceProtocol.h"
#import "../Services/LocationService/LocationServiceProtocol.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * @class ARCameraViewModel
 * @brief Manages the business logic for AR camera functionality
 *
 * This class coordinates between AR, motion, and location services to provide
 * a unified interface for capturing photos with metadata. It maintains the state
 * of the camera session and provides methods for controlling the camera and
 * capturing photos.
 */
@interface ARCameraViewModel : NSObject

/// The AR service used for camera functionality
@property (nonatomic, strong, readonly) id<ARServiceProtocol> arService;

/// The motion service used for device motion data
@property (nonatomic, strong, readonly) id<MotionServiceProtocol> motionService;

/// The location service used for location data
@property (nonatomic, strong, readonly) id<LocationServiceProtocol> locationService;

/// Array of metadata for captured photos
@property (nonatomic, strong, readonly) NSMutableArray<NSDictionary *> *photoMetaArray;

/// Current count of captured photos
@property (nonatomic, assign, readonly) NSInteger photoCount;

/**
 * @brief Initializes the ViewModel with required services
 *
 * @param arService The AR service to use for camera functionality
 * @param motionService The motion service to use for device motion data
 * @param locationService The location service to use for location data
 * @return An initialized instance of ARCameraViewModel
 */
- (instancetype)initWithARService:(id<ARServiceProtocol>)arService
                    motionService:(id<MotionServiceProtocol>)motionService
                  locationService:(id<LocationServiceProtocol>)locationService;

/**
 * @brief Starts all services
 *
 * This method starts the AR session, motion updates, and location updates.
 */
- (void)startServices;

/**
 * @brief Stops all services
 *
 * This method stops the AR session, motion updates, and location updates.
 */
- (void)stopServices;

/**
 * @brief Captures a photo with current motion and location metadata
 *
 * @param completion A block that is called when the photo capture is complete
 *                  The block receives the captured image, metadata dictionary,
 *                  and any error that occurred during capture
 */
- (void)capturePhotoWithCompletion:(void (^)(UIImage * _Nullable image, NSDictionary * _Nullable metadata, NSError * _Nullable error))completion;

/**
 * @brief Resets the camera session
 *
 * This method resets the AR session and clears all captured photo metadata.
 */
- (void)resetSession;

@end

NS_ASSUME_NONNULL_END 