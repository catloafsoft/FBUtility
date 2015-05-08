//
//  CLSFBAppDelegate.m
//  FBUtilityApp
//
//  Created by Stéphane Peter on 5/30/14.
//  Copyright (c) 2014 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBAppDelegate.h"

@implementation CLSFBAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    // UtilityApp defined as a test app on Facebook

    _fbutil = [[CLSFBUtility alloc] initWithAppID:@"258796227637007"
                                     schemeSuffix:nil
                                      clientToken:@"005e95b1f0936a8a2352410f03905111"
                                     appNamespace:@"clsfbutility"
                                       appStoreID:@"443265532"
                                        fetchUser:YES
                                         delegate:self];
    _fbutil.appName = @"UtilityApp";
    _fbutil.appDescription = @"A test app for Facebook integration.";
    _fbutil.appIconURL = @"http://img.cdn.catloafsoft.com/trainer-hd/fhd.png";
    _fbutil.appURL = [NSURL URLWithString:@"http://www.catloafsoft.com/trainer-hd/"];
    return [_fbutil application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [self.fbutil handleDidBecomeActive];
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    return [self.fbutil application:application openURL:url sourceApplication:sourceApplication annotation:annotation];
}


#pragma mark - CFLFBUtilityDelegate methods

// Notified upon login/logout
- (void)facebookLoggedIn:(NSString *)fullName
{
    NSLog(@"User %@ logged in.", fullName);
}

- (void)facebookLoggedOut
{
    NSLog(@"User logged out.");
}

// Called upon completion of first authentication through dialog or app
- (void)facebookAuthenticated
{
    NSLog(@"Facebook user first authenticated.");
}

// Called upon successful completion of the dialogs
- (void)publishedToFeed
{
    NSLog(@"Published to newsfeed");
}

- (void)sharedWithFriends
{
    NSLog(@"Shared with friends");
}

// Implement these methods to show a HUD to the user while data is being fetched
- (void)startedFetchingFromFacebook:(CLSFBUtility *)fb
{
    NSLog(@"Started fetching data from FB");
}

- (void)endedFetchingFromFacebook:(CLSFBUtility *)fb
{
    NSLog(@"Finished fetching data from FB");
}


@end
