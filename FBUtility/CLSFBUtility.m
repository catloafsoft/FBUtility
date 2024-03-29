//
//  CLSFBUtility.m
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011-2019 Catloaf Software, LLC. All rights reserved.
//


@import Bolts;
@import FBSDKCoreKit;
@import FBSDKLoginKit;
@import FBSDKShareKit;

#import <FBSDKCoreKit/FBSDKGraphErrorRecoveryProcessor.h>

#import "CLSFBUtility.h"
#import "CLSFBShareApp.h"
#import "CLSFBFeedPublish.h"

@interface CLSFBUtility () <FBSDKGraphErrorRecoveryProcessorDelegate, FBSDKSharingDelegate>
- (void)processAchievementData:(id)result;
@end

@implementation CLSFBUtility
{
    FBSDKLoginManager *_loginManager;
    BOOL _reset, _fetchProfile;
    NSMutableSet *_achievements;
    NSMutableSet *_deniedPermissions;
    CLSFBShareApp *_shareDialog;
    CLSFBFeedPublish *_feedDialog;
    NSString *_namespace, *_appID, *_appSuffix, *_appStoreID;
    void (^_afterLogin)(BOOL success);
    void (^_afterShare)(NSDictionary *results);
}

@synthesize appName = _appName,
    delegate = _delegate, fullName = _fullname, userID = _userID,
    appStoreID = _appStoreID, appIconURL = _appIconURL, appDescription = _appDescription;
@synthesize gender = _gender, birthDay = _birthDay, location = _location;

+ (void)initialize {
	if (self == [CLSFBUtility class]) {
        [NSUserDefaults.standardUserDefaults registerDefaults:@{@"facebook_timeline": @(YES)}];
    }
}

- (void)fetchProfileInfoAndNotify:(BOOL)notify
{
    FBSDKProfile *profile = [FBSDKProfile currentProfile];
    if (profile) {
        _fullname = [profile.name copy];
        _userID = [profile.userID copy];
        
        // It's possible we're only looking at the cached data right now
        if (FBSDKAccessToken.currentAccessToken == nil) {
            if ([_delegate respondsToSelector:@selector(facebookIsLoggedIn:)]) {
                [_delegate facebookIsLoggedIn:_fullname];
            }
            return;
        }
        
        if (!_fetchProfile) {
            if (notify) {
                if ([self->_delegate respondsToSelector:@selector(facebookIsLoggedIn:)]) {
                    [self->_delegate facebookIsLoggedIn:self->_fullname];
                }
            }
            return;
        }
        
        // Fetch gender, location and birthday
        FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me"
                                                                       parameters:@{@"fields": @"age_range,birthday,location,name,gender"}];
        if ([self.delegate respondsToSelector:@selector(startedFetchingFromFacebook:)]) {
            [self.delegate startedFetchingFromFacebook:self];
        }
        [request startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error fetching profile information: %@, result = %@", error, result);
            } else {
#ifdef DEBUG
                NSLog(@"Fetched me: %@", result);
#endif
                self->_gender = [result[@"gender"] copy];
                if (result[@"location"]) {
                    // TODO: Grab location name, may need additional permissions
                    self->_location = [result[@"location"][@"name"] copy];
                }
                if (result[@"birthday"]) { // May need permissions, look at age range if available
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    formatter.dateFormat = @"MM/dd/yyyy";
                    self->_birthDay = [formatter dateFromString:result[@"birthday"]];
                } else if (result[@"age_range"]) {
                    // Convert to a fake birthday depending on the value
                    NSDictionary *range = result[@"age_range"];
                    if (range[@"max"]) {
                        NSUInteger years = [range[@"max"] integerValue] - 1;
                        self->_birthDay = [NSDate dateWithTimeIntervalSinceNow:-years*365.25*24*3600];
                    } else if (range[@"min"]) {
                        NSUInteger years = [range[@"min"] integerValue] + 1;
                        self->_birthDay = [NSDate dateWithTimeIntervalSinceNow:-years*365.25*24*3600];
                    } else {
                        self->_birthDay = nil;
                    }
                } else {
                    self->_birthDay = nil;
                }
                if (notify) {
                    if ([self->_delegate respondsToSelector:@selector(facebookLoggedIn:)]) {
                        [self->_delegate facebookLoggedIn:self->_fullname];
                    }
                    if ([self->_delegate respondsToSelector:@selector(facebookIsLoggedIn:)]) {
                        [self->_delegate facebookIsLoggedIn:self->_fullname];
                    }

                    [NSNotificationCenter.defaultCenter postNotificationName:kFBUtilLoggedInNotification
                                                                      object:self];
                }
            }
            if ([self.delegate respondsToSelector:@selector(endedFetchingFromFacebook:)]) {
                [self.delegate endedFetchingFromFacebook:self];
            }
        }];
    }
}

- (void)profileDidChange:(NSNotification *)notif
{
    [self fetchProfileInfoAndNotify:YES];
}

- (void)runLoginBlock:(BOOL)success
{
    @synchronized(self) {
        // Run it exactly once
        if (_afterLogin) {
            _afterLogin(success);
            _afterLogin = nil;
        }
    }
}

- (void)accessTokenDidChangeUserID:(NSNotification *)notif
{
    if ([FBSDKAccessToken currentAccessToken]) {
        // Logged in as new user
        [self fetchProfileInfoAndNotify:YES];
        
        [self runLoginBlock:YES];
    } else {
        // Logged out
        _fullname = nil;
        _userID = nil;

        if ([_delegate respondsToSelector:@selector(facebookLoggedOut)]) {
            [_delegate facebookLoggedOut];
        }
        [NSNotificationCenter.defaultCenter postNotificationName:kFBUtilLoggedOutNotification
                                                          object:self];
    }
}

- (instancetype)initWithAppID:(NSString *)appID
                 schemeSuffix:(NSString *)suffix
                  clientToken:(NSString *)token
                 appNamespace:(NSString *)ns
                   appStoreID:(NSString *)appStoreID
                 fetchProfile:(BOOL)fetchProfile
                     delegate:(id<CLSFBUtilityDelegate>)delegate
{
    self = [super init];
    if (self) {
        _namespace = [ns copy];
        _appID = [appID copy];
        _appSuffix = [suffix copy];
        _appStoreID = [appStoreID copy];
        _delegate = delegate;
        _appDescription = @"";
        _fetchProfile = fetchProfile;
        _achievements = [[NSMutableSet alloc] init];
        NSArray *denied = [NSUserDefaults.standardUserDefaults objectForKey:@"facebook_denied"];
        if (denied) {
            _deniedPermissions = [[NSMutableSet alloc] initWithArray:denied];
        } else {
            _deniedPermissions = [[NSMutableSet alloc] init];
        }
        _loginManager = [[FBSDKLoginManager alloc] init];
        _loginManager.defaultAudience = FBSDKDefaultAudienceEveryone;
        
        [FBSDKSettings.sharedSettings setClientToken:token];
        [FBSDKSettings.sharedSettings setAppID:appID];
        [FBSDKSettings.sharedSettings setIsGraphErrorRecoveryEnabled:YES];
#ifdef DEBUG
        FBSDKSettings.sharedSettings.loggingBehaviors = [NSSet setWithObjects:FBSDKLoggingBehaviorAppEvents,FBSDKLoggingBehaviorDeveloperErrors,nil];
#endif
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(accessTokenDidChangeUserID:)
                                                   name:FBSDKAccessTokenDidChangeUserIDKey
                                                 object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(profileDidChange:)
                                                   name:FBSDKAccessTokenDidChangeNotification
                                                 object:nil];
        
        [self login:NO from:nil andThen:nil];
        [NSNotificationCenter.defaultCenter addObserver:self
                                               selector:@selector(userDefaultsChanged:)
                                                   name:NSUserDefaultsDidChangeNotification
                                                 object:nil];
    }
    return self;
}

- (instancetype) init {
    NSAssert(0, @"Call initWithAppID:... instead.");
    return [self initWithAppID:nil schemeSuffix:nil clientToken:nil appNamespace:nil appStoreID:nil fetchProfile:NO delegate:nil];
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

- (BOOL) publishTimeline {
    return [NSUserDefaults.standardUserDefaults boolForKey:@"facebook_timeline"];
}


// Various error handling methods

- (void)processorDidAttemptRecovery:(FBSDKGraphErrorRecoveryProcessor *)processor
                         didRecover:(BOOL)didRecover
                              error:(NSError *)error
{
    if (!didRecover) {
        NSLog(@"Failed to recover: %@", error);
    }
}

- (void)handleError:(NSError *)error request:(FBSDKGraphRequest *)request
{
    FBSDKGraphErrorRecoveryProcessor *errorProcessor = [[FBSDKGraphErrorRecoveryProcessor alloc] init];

    if ([errorProcessor processError:error request:request delegate:self] == NO) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:error.userInfo[FBSDKErrorLocalizedTitleKey]
                                                                       message:error.userInfo[FBSDKErrorLocalizedDescriptionKey]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"OK",@"Alert button")
                                                  style:UIAlertActionStyleCancel handler:nil]];
        [UIApplication.sharedApplication.keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
    }
}

/**
 * Open a Facebook page in the FB app or Safari.
 */

+ (void)openPage:(unsigned long long)uid {
	NSString *fburl = [NSString stringWithFormat:@"fb://profile/%lld",uid];
    [UIApplication.sharedApplication openURL:[NSURL URLWithString:fburl]
                                     options:@{} completionHandler:^(BOOL success) {
        if (success == NO){
            // We can redirect iPad users to the regular site
            NSString *site = UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone ? @"touch" : @"www";
            NSString *url = [NSString stringWithFormat:@"https://%@.facebook.com/profile.php?id=%lld",site,uid];
            [UIApplication.sharedApplication openURL:[NSURL URLWithString:url] options:@{}
                                   completionHandler:^(BOOL success) {
                
            }];
        }
    }];
}

+ (BOOL)appInstalled
{
    return [UIApplication.sharedApplication canOpenURL:[NSURL URLWithString:@"fb://profile"]];
}

+ (NSString *)sdkVersion
{
    return FBSDKSettings.sharedSettings.sdkVersion;
}

+ (BOOL)inBlockedCountry
{
    NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:NSLocale.currentLocale.localeIdentifier];
    if ([components[NSLocaleCountryCode] isEqualToString:@"CN"]) { // China
        return YES;
    }
    return NO;
}

- (NSURL *)appStoreURL
{
    return [NSURL URLWithString:[NSString stringWithFormat:@"https://apps.apple.com/app/id%@?mt=8&uo=4&at=11l4W7",
                                 self.appStoreID]];
}

- (void)handleDidBecomeActive
{
    [FBSDKAppEvents.shared activateApp];
    
    // Do the following if you use Mobile App Engagement Ads to get the deferred
    // app link after your app is installed.
    [FBSDKAppLinkUtility fetchDeferredAppLink:^(NSURL *url, NSError *error) {
        if (error) {
            NSLog(@"Received error while fetching deferred app link %@", error);
        }
        if (url) {
            [UIApplication.sharedApplication openURL:url options:@{}
                                   completionHandler:^(BOOL success) {
                
            }];
        }
    }];
}

+ (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [FBSDKProfile enableUpdatesOnAccessTokenChange:YES];
    return [FBSDKApplicationDelegate.sharedInstance application:application
                                  didFinishLaunchingWithOptions:launchOptions];
}

+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    return [FBSDKApplicationDelegate.sharedInstance application:application
                                                        openURL:url
                                              sourceApplication:sourceApplication
                                                     annotation:annotation];
}

+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options
{
    return [FBSDKApplicationDelegate.sharedInstance application:application
                                                        openURL:url
                                                        options:options];
}

- (BOOL)login:(BOOL)doAuthorize withPublishPermissions:(NSArray *)perms from:(UIViewController *)vc andThen:(void (^)(BOOL success))handler
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    BOOL facebook_reset = [defaults boolForKey:@"facebook_reset"];
    if (facebook_reset) {
        [self logout];
        [defaults setBool:NO forKey:@"facebook_reset"]; // Don't do it on the next start
        [defaults synchronize];
    }
    
    if (doAuthorize) {
        _afterLogin = [handler copy];
        [_loginManager logInWithPermissions:perms
                         fromViewController:vc
                                    handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
                                               if (error || result.isCancelled) {
                                                   NSLog(@"Failed to login with permissions %@: %@", perms, error);
                                                   [self runLoginBlock:NO];
                                               } else {
                                                   [self fetchProfileInfoAndNotify:YES];
                                                   [self runLoginBlock:YES];
                                               }
                                           }];
        _reset = NO;
    } else if (self.loggedIn) {
        [FBSDKAccessToken refreshCurrentAccessTokenWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Failed to refresh access token: %@, result = %@", error, result);
#ifdef DEBUG
            } else {
                NSLog(@"Token refreshed, result = %@", result);
#endif
            }
            // The profile is now always getting fetched upon login
            [self fetchProfileInfoAndNotify:YES];
        }];
        if (handler)
            handler(YES);
    }
    return self.loggedIn; // This might be too early to do
}

- (void) denyPermission:(NSString *)permission
{
    [_deniedPermissions addObject:permission];
    [NSUserDefaults.standardUserDefaults setObject:_deniedPermissions.allObjects forKey:@"facebook_denied"];
    [NSUserDefaults.standardUserDefaults synchronize];
}

- (void) userDefaultsChanged:(NSNotification *)notification
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    
    if ([defaults boolForKey:@"facebook_reset"] && !_reset) {
        _reset = YES;
        [self logout];
        // Can't change the key here as it triggers an infinite loop
        // Instead, look at setting it to NO on the first explicit user login
    }
}

- (BOOL)login:(BOOL)doAuthorize from:(UIViewController *)vc andThen:(void (^)(BOOL success))handler {
    return [self login:doAuthorize withPublishPermissions:nil from:vc andThen:handler];
}

- (void)logout {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:@"facebook_denied"]; // We can ask again when we log in
    [NSUserDefaults.standardUserDefaults synchronize];
    [_loginManager logOut];
}

- (BOOL)loggedIn {
    return [FBSDKAccessToken currentAccessToken] != nil;
}

- (UIView *)profilePictureViewOfSize:(CGFloat)side {
    FBSDKProfilePictureView *profileView = [[FBSDKProfilePictureView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, side, side)];
    profileView.pictureMode = FBSDKProfilePictureModeSquare;
    profileView.profileID = self.userID;
    profileView.bounds = CGRectMake(0.0f, 0.0f, side, side);
    return profileView;
}

/**
 * A function for parsing URL parameters.
 */
+ (NSDictionary*)parseURLParams:(NSString *)query {
    NSArray *pairs = [query componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [[NSMutableDictionary alloc] init];
    for (NSString *pair in pairs) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        if (kv.count > 1) {
            NSString *val = [kv[1] stringByRemovingPercentEncoding];
            params[kv[0]] = val;
        }
    }
    return params;
}

- (NSURL *)getTargetURL:(NSURL *)url
{
    NSDictionary *params = [CLSFBUtility parseURLParams:url.fragment];
    // Check if target URL exists
    NSString *urlString = [params valueForKey:@"target_url"];
    if (urlString) {
        return [NSURL URLWithString:urlString];
    } else { // Parse with Bolts AppLink code
        BFURL *parsedUrl = [BFURL URLWithURL:url];
        return parsedUrl.targetURL;
    }
}

- (void)doWithPermission:(NSString *)permission
                    from:(UIViewController *)vc
                    toDo:(void (^)(BOOL granted))handler
{
#ifdef DEBUG
    NSLog(@"Available permissions: %@, declined: %@, denied: %@, needed: %@",
          FBSDKAccessToken.currentAccessToken.permissions, FBSDKAccessToken.currentAccessToken.declinedPermissions, _deniedPermissions, permission);
#endif
    if (permission == nil || [FBSDKAccessToken.currentAccessToken hasGranted:permission]) {
        if (handler)
            handler(YES);
    } else if ([FBSDKAccessToken.currentAccessToken.declinedPermissions containsObject:permission] ||
               [_deniedPermissions containsObject:permission]) {
        if (handler)
            handler(NO);
    } else {
#ifdef DEBUG
        NSLog(@"Requesting new permission: %@", permission);
#endif
        [_loginManager logInWithPermissions:@[permission]
                         fromViewController:vc
                                    handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
            if (error) {
                NSLog(@"Failed to login with permission %@: %@", permission, error);
                [self runLoginBlock:NO];
            } else {
                [self runLoginBlock:!result.isCancelled];
                if (result.isCancelled) {
                    [self denyPermission:permission];
                }
                if (handler)
                    handler([result.grantedPermissions containsObject:permission]);
            }
        }];
    }
}

- (void)doWithReadPermission:(NSString *)permission
                        from:(UIViewController *)vc
                        toDo:(void (^)(BOOL granted))handler
{
    [self doWithPermission:permission from:vc toDo:handler];
}


- (void)doWithPublishPermission:(NSString *)permission
                           from:(UIViewController *)vc
                           toDo:(void (^)(BOOL granted))handler
{
    [self doWithPermission:permission from:vc toDo:handler];
}

#pragma mark - Utility dialog methods

- (void)publishToFeedWithCaption:(NSString *)caption
                     description:(NSString *)desc
                 textDescription:(NSString *)text
                            name:(NSString *)name
                      properties:(NSDictionary *)props
                         hashtag:(NSString *)hashtag
                expandProperties:(BOOL)expand
                       imagePath:(NSString *)imgPath
                           image:(UIImage *)image
                        imageURL:(NSURL *)img
                      contentURL:(NSURL *)contentURL
                            from:(UIViewController *)vc
                            then:(void (^)(NSDictionary *result))success
{
    [self doWithPermission:nil from:vc toDo:^(BOOL granted) {
        if (!granted)
            return;
        self->_feedDialog = [[CLSFBFeedPublish alloc] initWithFacebookUtil:self
                                                                   caption:caption
                                                               description:desc
                                                           textDescription:text
                                                                      name:name
                                                                properties:props
                                                                   hashtag:hashtag
                                                                 imagePath:imgPath
                                                                     image:image
                                                                  imageURL:img
                                                                contentURL:contentURL];
        self->_feedDialog.expandProperties = expand;
        [self->_feedDialog showDialogFrom:vc then:success];
    }];
}


- (void)shareAppWithFriendsFrom:(UIViewController *)vc {
    _shareDialog = [[CLSFBShareApp alloc] initWithFacebookUtil:self];
    [_shareDialog presentFromViewController:vc];
}

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results
{
    if (_afterShare) {
        _afterShare(results);
        _afterShare = nil;
    }
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error
{
    NSLog(@"Share dialog failed with error: %@", error);
    if (_afterShare) {
        _afterShare(nil);
        _afterShare = nil;
    }
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer
{
    if (_afterShare) {
        _afterShare(nil);
        _afterShare = nil;
    }
}


- (void)publishWatch:(NSString *)videoURL from:(UIViewController * _Nullable)vc
{
    if (!self.publishTimeline)
        return;
    
    [self doWithPermission:nil from:vc toDo:^(BOOL granted) {
        if (!granted)
            return;
        
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/video.watches"
                                                                   parameters:@{ @"video" : videoURL }
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error publishing video watch: %@", error);
#ifdef DEBUG
            } else {
                NSLog(@"Published video watch for %@, result = %@", videoURL, result);
#endif
            }
        }];
    }];
}


- (void)publishLike:(NSString *)url from:(UIViewController * _Nullable)vc andThen:(void (^ _Nullable)(NSString *))completion
{
    if (!self.publishTimeline) {
        if (completion)
            completion(nil);
        return;
    }

    NSDictionary *params = @{ @"object" : url };
    
    [self doWithPublishPermission:nil from:vc toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/og.likes"
                                                                   parameters:params
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSDictionary *errDict = error.userInfo[@"error"];
                if ([errDict[@"code"] integerValue] != 3501) { // Duplicate error code from FB
                    NSLog(@"Error publishing like: %@", error);
                }
            } else if (completion) {
                completion(result[@"id"]);
            }
        }];
    }];
}

- (void)publishUnlike:(NSString *)likeID from:(UIViewController * _Nullable)vc andThen:(void (^ _Nullable)(BOOL))completion
{
    if (!self.publishTimeline)
        return;
    
    [self doWithPublishPermission:nil from:vc toDo:^(BOOL granted) {
        if (!granted)
            return;
        
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:likeID
                                                                   parameters:@{}
                                                                   HTTPMethod:@"DELETE"];
        [req startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error deleting like: %@", error);
            }
            if (completion)
                completion(error == nil);
        }];
    }];
}

// Submit the URL to a registered achievement page
- (BOOL)publishAchievement:(NSString *)achievementURL from:(UIViewController * _Nullable)vc
{
    if (!self.publishTimeline)
        return NO;
    
    if ([_achievements containsObject:achievementURL])
        return YES;
    
    [self doWithPublishPermission:nil from:vc toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/achievements"
                                                                   parameters:@{@"achievement":achievementURL}
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSDictionary *errDict = error.userInfo[@"error"];
                if ([errDict[@"code"] integerValue] != 3501) { // Duplicate achievement error code from FB
                    NSLog(@"Error publishing achievement: %@", error);
                } else {
                    [self->_achievements addObject:achievementURL];
                }
            } else {
                [self->_achievements addObject:achievementURL];
            }
        }];
    }];
    return NO;
}

- (void)removeAchievement:(NSString *)achievementURL from:(UIViewController * _Nullable)vc
{
    if (![_achievements containsObject:achievementURL])
        return;
    
    [self doWithPublishPermission:nil from:vc toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/achievements"
                                                                   parameters:@{@"achievement":achievementURL}
                                                                   HTTPMethod:@"DELETE"];
        [req startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSDictionary *errDict = error.userInfo[@"error"];
                if ([errDict[@"code"] integerValue] != 3404) { // No such achievement for user error code from FB
                    NSLog(@"Error deleting achievement: %@", error);
                } else {
                    [self->_achievements removeObject:achievementURL];
                }
            } else {
                [self->_achievements removeObject:achievementURL];
            }
        }];
    }];

}

- (void)removeAllAchievementsFrom:(UIViewController *)vc
{
    if (_achievements.count == 0) {
#ifdef DEBUG
        NSLog(@"No achievements to remove.");
#endif
        return;
    }
 
    [self doWithPublishPermission:nil from:vc toDo:^(BOOL granted) {
        if (!granted)
            return;
        
        // Batch the requests
        FBSDKGraphRequestConnection *conn = [[FBSDKGraphRequestConnection alloc] init];
        
        for (NSString *achievementURL in self->_achievements) {
            FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/achievements"
                                                                       parameters:@{@"achievement" : achievementURL}
                                                                       HTTPMethod:@"DELETE"];
            [conn addRequest:req completion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
                if (error) {
                    NSDictionary *errDict = error.userInfo[@"error"];
                    if ([errDict[@"code"] integerValue] != 3404) { // No such achievement for user error code from FB
                        NSLog(@"Error deleting achievement: %@", error);
                    }
                }
            }];
        }
        [conn start];
        [self->_achievements removeAllObjects];
    }];

}

- (void)processAchievementData:(id)result {

    for (NSDictionary *dict in result[@"data"]) {
        if (dict[@"data"]) { // New October 2013 style data change
            [_achievements addObject:dict[@"data"][@"achievement"][@"url"]];
        } else if (dict[@"achievement"]) {
            [_achievements addObject:dict[@"achievement"][@"url"]];
        }
    }
    NSDictionary *paging = result[@"paging"];
    if (paging[@"next"]) { // need to send another request
        FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:paging[@"next"]
                                                                       parameters:@{}];
        [request startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error processing paging: %@", error);
            } else {
                [self processAchievementData:result];
            }
        }];
    }
}

// Retrieve the list of achievements earned from Facebook
- (void)fetchAchievementsAndThen:(void (^)(NSSet *achievements))handler
{
    // We probably don't need to request extended permissions just to get the list of earned achievements
    [self doWithReadPermission:@"public_profile" from:nil toDo:^(BOOL granted) {
        if (!granted)
            return;

        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/achievements"
                                                                   parameters:@{@"fields" : @"data"}
                                                                   HTTPMethod:@"GET"];
        [req startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                [self handleError:error request:req];
            } else {
                [self->_achievements removeAllObjects];
                [self processAchievementData:result];
                if (handler) {
                    handler(self->_achievements);
                }
            }
        }];
    }];
}

- (void)publishScore:(int64_t)score from:(UIViewController * _Nullable)vc
{
    if (!self.publishTimeline)
        return;

    [self doWithPublishPermission:nil from:vc toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me/scores"
                                                                   parameters:@{@"score":[NSString stringWithFormat:@"%@",@(score)]}
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletion:^(id<FBSDKGraphRequestConnecting>  _Nullable connection, id  _Nullable result, NSError * _Nullable error) {
            if (error) {
                NSLog(@"Error publishing score: %@", error);
#ifdef DEBUG
            } else {
                NSLog(@"Published score: %@, result = %@", @(score), result);
#endif
            }
        }];
    }];
}

#pragma mark - FB App Events

+ (void)logLevelReached:(NSUInteger)level
{
    [FBSDKAppEvents.shared logEvent:FBSDKAppEventNameAchievedLevel
                         parameters:@{FBSDKAppEventParameterNameLevel : @(level)}];
}

+ (void)logAchievement:(NSString *)description
{
    [FBSDKAppEvents.shared logEvent:FBSDKAppEventNameUnlockedAchievement
                         parameters:@{FBSDKAppEventParameterNameDescription : description}];
}

+ (void)logTutorialCompleted
{
    [FBSDKAppEvents.shared logEvent:FBSDKAppEventNameCompletedTutorial];
}

+ (void) logViewedContentID:(NSString *)contentID type:(NSString *)type
{
    [FBSDKAppEvents.shared logEvent:FBSDKAppEventNameViewedContent
                         parameters:@{FBSDKAppEventParameterNameContentID : contentID,
                                      FBSDKAppEventParameterNameContentType : type}];
}

+ (void) logPurchase:(NSString *)item amount:(double)amount currency:(NSString *)currency {
    [FBSDKAppEvents.shared logPurchase:amount
                              currency:currency
                            parameters:@{@"Item":item}];
}

@end
