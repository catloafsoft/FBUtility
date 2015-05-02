//
//  CLSFBUtility.m
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011-2015 Catloaf Software, LLC. All rights reserved.
//


@import FBSDKCoreKit;
@import FBSDKLoginKit;
@import FBSDKShareKit;

#import <FBSDKCoreKit/FBSDKGraphErrorRecoveryProcessor.h>

#import "CLSFBUtility.h"
#import "FBShareApp.h"
#import "FBFeedPublish.h"

@interface CLSFBUtility () <FBSDKGraphErrorRecoveryProcessorDelegate>
- (void)processAchievementData:(id)result;
@end

@implementation CLSFBUtility
{
    FBSDKLoginManager *_loginManager;
    BOOL _loggedIn, _fetchUserInfo, _fromDialog, _reset;
    NSMutableSet *_achievements;
    FBShareApp *_shareDialog;
    FBFeedPublish *_feedDialog;
    NSString *_namespace, *_appID, *_appSuffix, *_appStoreID;
    void (^_afterLogin)(void);
}

@synthesize loggedIn = _loggedIn, appName = _appName,
    delegate = _delegate, fullName = _fullname, userID = _userID,
    appStoreID = _appStoreID, appIconURL = _appIconURL, appDescription = _appDescription;
@synthesize gender = _gender, birthDay = _birthDay, location = _location;

+ (void)initialize {
	if (self == [CLSFBUtility class]) {
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{@"facebook_timeline": @(YES)}];
    }
}

- (void)profileDidChange:(NSNotification *)notif
{
    FBSDKProfile *profile = [FBSDKProfile currentProfile];
    if (profile) {
        _fullname = [profile.name copy];
        _userID = [profile.userID copy];
        
        // TODO: Fetch gender, location and birthday
        FBSDKGraphRequest *request = [[FBSDKGraphRequest alloc] initWithGraphPath:@"me" parameters:nil];
        [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (!error) {
#ifdef DEBUG
                NSLog(@"Fetched me: %@", result);
#endif
                _gender = [result[@"gender"] copy];
                if (result[@"location"]) {
                    // TODO: Grab location name
                }
                if (result[@"birthday"]) {
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"MM/dd/yyyy"];
                    _birthDay = [formatter dateFromString:result[@"birthday"]];
                } else {
                    _birthDay = nil;
                }
            }
        }];
    }
}

- (void)accessTokenDidChangeUserID:(NSNotification *)notif
{
    if ([FBSDKAccessToken currentAccessToken]) {
        // Logged in as new user
        [self profileDidChange:nil];
        
        if ([_delegate respondsToSelector:@selector(facebookLoggedIn:)])
            [_delegate facebookLoggedIn:_fullname];
        if (_fromDialog && [_delegate respondsToSelector:@selector(facebookAuthenticated)]) {
            [_delegate facebookAuthenticated];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedInNotification
                                                            object:self];
        if (_afterLogin) {
            _afterLogin();
        }
    } else {
        // Logged out
        _fullname = nil;
        _userID = nil;
        _loggedIn = NO;

        if ([_delegate respondsToSelector:@selector(facebookLoggedOut)]) {
            [_delegate facebookLoggedOut];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedOutNotification
                                                            object:self];
    }
}

- (instancetype)initWithAppID:(NSString *)appID
                 schemeSuffix:(NSString *)suffix
                  clientToken:(NSString *)token
                 appNamespace:(NSString *)ns
                   appStoreID:(NSString *)appStoreID
                    fetchUser:(BOOL)fetch
                     delegate:(id<CLSFBUtilityDelegate>)delegate
{
    self = [super init];
    if (self) {
        _fetchUserInfo = fetch;
        _namespace = [ns copy];
        _appID = [appID copy];
        _appSuffix = [suffix copy];
        _appStoreID = [appStoreID copy];
        _delegate = delegate;
        _appDescription = @"";
        _achievements = [[NSMutableSet alloc] init];
        _loginManager = [[FBSDKLoginManager alloc] init];
        _loginManager.defaultAudience = FBSDKDefaultAudienceEveryone;
        _loginManager.loginBehavior = FBSDKLoginBehaviorSystemAccount; // Try system accounts first
        
        [FBSDKSettings setClientToken:token];
        [FBSDKSettings setAppID:appID];
        [FBSDKSettings setGraphErrorRecoveryDisabled:NO];
#ifdef DEBUG
        [FBSDKSettings setLoggingBehavior:[NSSet setWithObjects:FBSDKLoggingBehaviorAppEvents,FBSDKLoggingBehaviorDeveloperErrors,nil]];
#endif
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(accessTokenDidChangeUserID:)
                                                     name:FBSDKAccessTokenDidChangeUserID
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(profileDidChange:)
                                                     name:FBSDKProfileDidChangeNotification
                                                   object:nil];

        [self login:NO andThen:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(userDefaultsChanged:)
                                                     name:NSUserDefaultsDidChangeNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (BOOL) publishTimeline {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"facebook_timeline"];
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
        [[[UIAlertView alloc] initWithTitle:error.userInfo[FBSDKErrorLocalizedTitleKey]
                                    message:error.userInfo[FBSDKErrorLocalizedDescriptionKey]
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                          otherButtonTitles:nil] show];
    }
}

/**
 * Open a Facebook page in the FB app or Safari.
 * @return boolean - whether the page was successfully opened.
 */

+ (BOOL)openPage:(unsigned long long)uid {
	NSString *fburl = [NSString stringWithFormat:@"fb://profile/%lld",uid];
	if ([[UIApplication sharedApplication] openURL:[NSURL URLWithString:fburl]] == NO) {
        // We can redirect iPad users to the regular site
        NSString *site = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) ? @"touch" : @"www";
		NSString *url = [NSString stringWithFormat:@"http://%@.facebook.com/profile.php?id=%lld",site,uid];
		return [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
	}
	return NO;
}

+ (NSString *)sdkVersion
{
    return [FBSDKSettings sdkVersion];
}

+ (BOOL)inBlockedCountry
{
    NSDictionary *components = [NSLocale componentsFromLocaleIdentifier:[[NSLocale currentLocale] localeIdentifier]];
    if ([components[NSLocaleCountryCode] isEqualToString:@"CN"]) { // China
        return YES;
    }
    return NO;
}

- (void)handleDidBecomeActive
{
    [FBSDKAppEvents activateApp];
    
    // Do the following if you use Mobile App Engagement Ads to get the deferred
    // app link after your app is installed.
    [FBSDKAppLinkUtility fetchDeferredAppLink:^(NSURL *url, NSError *error) {
        if (error) {
            NSLog(@"Received error while fetching deferred app link %@", error);
        }
        if (url) {
            [[UIApplication sharedApplication] openURL:url];
        }
    }];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [FBSDKProfile enableUpdatesOnAccessTokenChange:YES];
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                    didFinishLaunchingWithOptions:launchOptions];
}

- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation
{
    return [[FBSDKApplicationDelegate sharedInstance] application:application
                                                          openURL:url
                                                sourceApplication:sourceApplication
                                                       annotation:annotation];
}

- (BOOL)login:(BOOL)doAuthorize withPermissions:(NSArray *)perms andThen:(void (^)(void))handler
{
    _afterLogin = [handler copy];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    BOOL facebook_reset = [defaults boolForKey:@"facebook_reset"];
    if (facebook_reset) {
        [self logout];
        [defaults setBool:NO forKey:@"facebook_reset"]; // Don't do it on the next start
        [defaults synchronize];
    }
    
    if (doAuthorize) {
        [_loginManager logInWithPublishPermissions:perms
                                           handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
                                               // TODO
                                           }];
        _reset = NO;
    }
    return [self isSessionValid]; // This might be too early to do
}


- (void) userDefaultsChanged:(NSNotification *)notification
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults boolForKey:@"facebook_reset"] && !_reset) {
        _reset = YES;
        [self logout];
        // Can't change the key here as it triggers an infinite loop
        // Instead, look at setting it to NO on the first explicit user login
    }
}

- (BOOL)login:(BOOL)doAuthorize andThen:(void (^)(void))handler {
    return [self login:doAuthorize withPermissions:nil andThen:handler];
}

- (void)logout {
    [_loginManager logOut];
}

- (BOOL)isSessionValid {
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
        NSString *val = [kv[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        params[kv[0]] = val;
    }
    return params;
}

- (NSString *)getTargetURL:(NSURL *)url {
    NSString *query = [url fragment];
    NSDictionary *params = [CLSFBUtility parseURLParams:query];
    // Check if target URL exists
    return [params valueForKey:@"target_url"];
}

- (void)doWithReadPermission:(NSString *)permission
                        toDo:(void (^)(BOOL granted))handler
{
#ifdef DEBUG
    NSLog(@"Available permissions: %@", [FBSDKAccessToken currentAccessToken].permissions);
#endif
    if ([[FBSDKAccessToken currentAccessToken] hasGranted:permission]) {
        if (handler)
            handler(YES);
    } else {
#ifdef DEBUG
        NSLog(@"Requesting new read permission: %@", permission);
#endif
        [_loginManager logInWithReadPermissions:@[permission] handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
            if (error) {
                // [self handleRequestPermissionError:error]; // FIXME
            } else if (handler) {
                handler([result.grantedPermissions containsObject:permission]);
            }
        }];
    }
}

- (void)doWithPublishPermission:(NSString *)permission
                           toDo:(void (^)(BOOL granted))handler
{
#ifdef DEBUG
    NSLog(@"Available permissions: %@", [FBSDKAccessToken currentAccessToken].permissions);
#endif
    if ([[FBSDKAccessToken currentAccessToken] hasGranted:permission]) {
        if (handler)
            handler(YES);
    } else {
#ifdef DEBUG
        NSLog(@"Requesting new publish permission: %@", permission);
#endif
        [_loginManager logInWithPublishPermissions:@[permission] handler:^(FBSDKLoginManagerLoginResult *result, NSError *error) {
            if (error) {
                // [self handleRequestPermissionError:error]; // FIXME
            } else if (handler) {
                handler([result.grantedPermissions containsObject:permission]);
            }
        }];
    }
}

#pragma mark - Utility dialog methods

- (void)publishToFeedWithCaption:(NSString *)caption
                     description:(NSString *)desc
                 textDescription:(NSString *)text
                            name:(NSString *)name
                      properties:(NSDictionary *)props
                expandProperties:(BOOL)expand
                          appURL:(NSString *)appURL
                       imagePath:(NSString *)imgPath
                        imageURL:(NSString *)img
                       imageLink:(NSString *)imgURL
                            from:(UIViewController *)vc
{
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        if (!granted)
            return;
        _feedDialog = [[FBFeedPublish alloc] initWithFacebookUtil:self
                                                          caption:caption
                                                      description:desc
                                                  textDescription:text
                                                             name:name
                                                       properties:props
                                                           appURL:appURL
                                                        imagePath:imgPath
                                                         imageURL:img
                                                        imageLink:imgURL];
        _feedDialog.expandProperties = expand;
        [_feedDialog showDialogFrom:vc];
    }];
}


- (void)shareAppWithFriends:(NSString *)message from:(UIViewController *)vc {
    _shareDialog = [[FBShareApp alloc] initWithFacebookUtil:self message:message];
    [_shareDialog presentFromViewController:vc];
}

- (void)publishAction:(NSString *)action withObject:(NSString *)object objectURL:(NSString *)url {
    if (!self.publishTimeline)
        return;
    
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:[NSString stringWithFormat:@"/me/%@:%@",_namespace,action]
                                                                   parameters:@{object : url}
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error publishing action: %@", error);
            }
        }];
    }];
}

- (void)publishWatch:(NSString *)videoURL {
    if (!self.publishTimeline)
        return;
    
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me/video.watches"
                                                                   parameters:@{ @"video" : videoURL }
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error publishing video watch: %@", error);
            }
        }];
    }];
}


- (void)publishLike:(NSString *)url andThen:(void (^)(NSString *likeID))completion {
    if (!self.publishTimeline) {
        if (completion)
            completion(nil);
        return;
    }

    NSDictionary *params = @{ @"object" : url };
    
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me/og.likes"
                                                                   parameters:params
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
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

- (void)publishUnlike:(NSString *)likeID {
    if (!self.publishTimeline)
        return;
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:[@"/" stringByAppendingString:likeID]
                                                                   parameters:nil
                                                                   HTTPMethod:@"DELETE"];
        [req startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error deleting like: %@", error);
            }
        }];
    }];
}

// Submit the URL to a registered achievement page
- (BOOL)publishAchievement:(NSString *)achievementURL
{
    if (!self.publishTimeline)
        return NO;
    
    if ([_achievements containsObject:achievementURL])
        return YES;
    
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me/achievements"
                                                                   parameters:@{@"achievement":achievementURL}
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSDictionary *errDict = [error userInfo][@"error"];
                if ([errDict[@"code"] integerValue] != 3501) { // Duplicate achievement error code from FB
                    NSLog(@"Error publishing achievement: %@", error);
                } else {
                    [_achievements addObject:achievementURL];
                }
            } else {
                [_achievements addObject:achievementURL];
            }
        }];
    }];
    return NO;
}

- (void)removeAchievement:(NSString *)achievementURL {
    if (![_achievements containsObject:achievementURL])
        return;
    
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me/achievements"
                                                                   parameters:@{@"achievement":achievementURL}
                                                                   HTTPMethod:@"DELETE"];
        [req startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSDictionary *errDict = [error userInfo][@"error"];
                if ([errDict[@"code"] integerValue] != 3404) { // No such achievement for user error code from FB
                    NSLog(@"Error deleting achievement: %@", error);
                } else {
                    [_achievements removeObject:achievementURL];
                }
            } else {
                [_achievements removeObject:achievementURL];
            }
        }];
    }];

}

- (void)removeAllAchievements {
    if ([_achievements count] == 0)
        return;
 
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        if (!granted)
            return;
        
        // Batch the requests
        FBSDKGraphRequestConnection *conn = [[FBSDKGraphRequestConnection alloc] init];
        
        for (NSString *achievementURL in _achievements) {
            FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me/achievements"
                                                                       parameters:@{@"achievement":achievementURL}
                                                                       HTTPMethod:@"DELETE"];
            [conn addRequest:req completionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
                if (error) {
                    NSDictionary *errDict = [error userInfo][@"error"];
                    if ([errDict[@"code"] integerValue] != 3404) { // No such achievement for user error code from FB
                        NSLog(@"Error deleting achievement: %@", error);
                    }
                }
            }];
        }
        [conn start];
        [_achievements removeAllObjects];
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
                                                                       parameters:nil];
        [request startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
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
    FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me/achievements"
                                                               parameters:nil
                                                               HTTPMethod:@"GET"];
    [req startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
        if (error) {
            [self handleError:error request:req];
        } else {
            [_achievements removeAllObjects];
            [self processAchievementData:result];
            if (handler) {
                handler(_achievements);
            }
        }
    }];
}

- (void)publishScore:(int64_t)score {
    if (self.publishTimeline)
        return;
    [self doWithPublishPermission:@"publish_actions" toDo:^(BOOL granted) {
        if (!granted)
            return;
        FBSDKGraphRequest *req = [[FBSDKGraphRequest alloc] initWithGraphPath:@"/me/scores"
                                                                   parameters:@{@"score":[NSString stringWithFormat:@"%@",@(score)]}
                                                                   HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBSDKGraphRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error publishing score: %@", error);
            }
        }];
    }];
}

#pragma mark - FB App Events

+ (void)logLevelReached:(NSUInteger)level
{
    [FBSDKAppEvents logEvent:FBSDKAppEventNameAchievedLevel
                  parameters:@{FBSDKAppEventParameterNameLevel : @(level)}];
}

+ (void)logAchievement:(NSString *)description
{
    [FBSDKAppEvents logEvent:FBSDKAppEventNameUnlockedAchievement
                  parameters:@{FBSDKAppEventParameterNameDescription : description}];
}

+ (void)logTutorialCompleted
{
    [FBSDKAppEvents logEvent:FBSDKAppEventNameCompletedTutorial];
}

+ (void) logViewedContentID:(NSString *)contentID type:(NSString *)type
{
    [FBSDKAppEvents logEvent:FBSDKAppEventNameViewedContent
                  parameters:@{FBSDKAppEventParameterNameContentID : contentID,
                               FBSDKAppEventParameterNameContentType : type}];
}

+ (void) logPurchase:(NSString *)item amount:(double)amount currency:(NSString *)currency {
    [FBSDKAppEvents logPurchase:amount
                       currency:currency
                     parameters:@{@"Item":item}];
}

@end
