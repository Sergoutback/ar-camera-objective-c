//
//  SceneDelegate.m
//  ar-camera-objective-c
//
//  Created by Mac on 14.06.25.
//

#import "SceneDelegate.h"
#import "ViewController.h"
#import <ARKit/ARKit.h>
#import "Services/ARService/ARService.h"
#import "Services/MotionService/MotionService.h"
#import "Services/LocationService/LocationService.h"
#import "Services/PhotoService/PhotoService.h"
#import "Services/ARSpaceService/ARSpaceService.h"
#import "Services/ARService/ARServiceProtocol.h"

@interface SceneDelegate ()

@end

@implementation SceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    if ([scene isKindOfClass:[UIWindowScene class]]) {
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        
        // Create window with the correct frame
        CGRect windowFrame = windowScene.coordinateSpace.bounds;
        self.window = [[UIWindow alloc] initWithFrame:windowFrame];
        self.window.windowScene = windowScene;
        
        // Instantiate shared ARSCNView that will be passed to services and VC
        ARSCNView *sceneView = [[ARSCNView alloc] initWithFrame:windowFrame];
        
        // Build services
        id<ARServiceProtocol> arService = [[ARService alloc] initWithSceneView:sceneView];
        MotionService *motionService = [[MotionService alloc] init];
        LocationService *locationService = [[LocationService alloc] init];
        PhotoService *photoService = [[PhotoService alloc] init];
        ARSpaceService *spaceService = [[ARSpaceService alloc] initWithSceneView:sceneView];
        
        // Create and setup view controller with DI
        ViewController *viewController = [[ViewController alloc] initWithSceneView:sceneView
                                                                          arService:arService
                                                                      motionService:motionService
                                                                    locationService:locationService
                                                                      photoService:photoService
                                                                      spaceService:spaceService];
        UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:viewController];
        
        // Set root view controller and make window visible
        self.window.rootViewController = navigationController;
        [self.window makeKeyAndVisible];
    }
}

- (void)sceneDidDisconnect:(UIScene *)scene {
    // Called as the scene is being released by the system.
    // This occurs shortly after the scene enters the background, or when its session is discarded.
    // Release any resources associated with this scene that can be re-created the next time the scene connects.
    // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    // Called when the scene has moved from an inactive state to an active state.
    // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
}

- (void)sceneWillResignActive:(UIScene *)scene {
    // Called when the scene will move from an active state to an inactive state.
    // This may occur due to temporary interruptions (ex. an incoming phone call).
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    // Called as the scene transitions from the background to the foreground.
    // Use this method to undo the changes made on entering the background.
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    // Called as the scene transitions from the foreground to the background.
    // Use this method to save data, release shared resources, and store enough scene-specific state information
    // to restore the scene back to its current state.
}

@end
