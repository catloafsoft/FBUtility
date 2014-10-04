//
//  CLSFBUtility.m
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011-2014 Catloaf Software, LLC. All rights reserved.
//

#import <FacebookSDK/FacebookSDK.h>
#import <FacebookSDK/FBGraphPlace.h>
#import "CLSFBUtility.h"
#import "FBShareApp.h"
#import "FBFeedPublish.h"

NSString *const FBSessionStateChangedNotification = @"com.catloafsoft:FBSessionStateChangedNotification";


@interface CLSFBUtility ()
- (void)processAchievementData:(id)result;
@end

@implementation CLSFBUtility
{
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

- (void)sessionStateChanged:(FBSession *)session
                      state:(FBSessionState) state
                      error:(NSError *)error
{
    switch (state) {
        case FBSessionStateOpen:
            if (!error) {
                // We have a valid session
                
                _loggedIn = YES;
                
                if (_fetchUserInfo) {
                    [[FBRequest requestForMe] startWithCompletionHandler:
                     ^(FBRequestConnection *connection,
                       NSDictionary<FBGraphUser> *user,
                       NSError *error) {
                         if (!error) {
                             _fullname = [user.name copy];
                             _userID = [user.objectID copy];
                             _gender = [user[@"gender"] copy];
                             _location = [user.location.name copy];
                             if (user[@"birthday"]) {
                                 NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                                 [formatter setDateFormat:@"MM/dd/yyyy"];
                                 _birthDay = [formatter dateFromString:user[@"birthday"]];
                             } else {
                                 _birthDay = nil;
                             }
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
                         }
                     }];
                } else {
                    if ([_delegate respondsToSelector:@selector(facebookLoggedIn:)])
                        [_delegate facebookLoggedIn:nil];
                    if (_fromDialog && [_delegate respondsToSelector:@selector(facebookAuthenticated)]) {
                        [_delegate facebookAuthenticated];
                    }
                    [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedInNotification
                                                                        object:self];
                    if (_afterLogin) {
                        _afterLogin();
                    }
                }
            }
            break;
        case FBSessionStateClosed:
        case FBSessionStateClosedLoginFailed:
            [FBSession.activeSession closeAndClearTokenInformation];
            _fullname = nil;
            _userID = nil;
            _loggedIn = NO;
            if (state != FBSessionStateClosedLoginFailed) { // No need to notify if we simply failed to log in
                if ([_delegate respondsToSelector:@selector(facebookLoggedOut)]) {
                    [_delegate facebookLoggedOut];
                }
                [[NSNotificationCenter defaultCenter] postNotificationName:kFBUtilLoggedOutNotification
                                                                    object:self];
            } else {
#ifdef DEBUG
                NSLog(@"FB Session Login failed: %@", error);
#endif
            }
            break;
        default:
            break;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:FBSessionStateChangedNotification
                                                        object:session];
    
    if (error) {
        [self handleAuthError:error];
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
        [FBSettings setClientToken:token];
        [FBSettings setDefaultAppID:appID];
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

- (void)handleAuthError:(NSError *)error {
    NSString *alertMessage = nil;
    
    if ([FBErrorUtility shouldNotifyUserForError:error]) {
        // If the SDK has a message for the user, surface it.
        alertMessage = [FBErrorUtility userMessageForError:error];
    } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryAuthenticationReopenSession) {
        // It is important to handle session closures since they can happen
        // outside of the app. You can inspect the error for more context
        // but this sample generically notifies the user.
        alertMessage = NSLocalizedString(@"Your Facebook session is no longer valid. Please log in again.", @"Facebook error message");
    } else if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled) {
        // The user has cancelled a login. You can inspect the error
        // for more context. For this sample, we will simply ignore it.
#ifdef DEBUG
        NSLog(@"FB user cancelled login: %@", error);
#endif
    } else {
        // For simplicity, this sample treats other errors blindly.
        //alertMessage = @"Error. Please try again later.";
        NSLog(@"Unexpected FB error: %@", error);
    }
    
    if (alertMessage) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                    message:alertMessage
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                          otherButtonTitles:nil] show];
    }
}

- (void)handleRequestPermissionError:(NSError *)error
{
    if ([FBErrorUtility shouldNotifyUserForError:error]) {
        // If the SDK has a message for the user, surface it.
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                    message:[FBErrorUtility userMessageForError:error]
                                   delegate:nil
                          cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                          otherButtonTitles:nil] show];
    } else {
        if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryUserCancelled){
            // The user has cancelled the request. You can inspect the value and
            // inner error for more context. Here we simply ignore it.
#ifdef DEBUG
            NSLog(@"FB: User cancelled post permissions.");
#endif
        } else {
#ifdef DEBUG
            NSLog(@"Unexpected error requesting permissions:%@", error);
#endif
            [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                        message:NSLocalizedString(@"Unable to request publish permissions",@"Facebook alert message")
                                       delegate:nil
                              cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                              otherButtonTitles:nil] show];
        }
    }
}

// Helper method to handle errors during API calls
- (void)handleAPICallError:(NSError *)error forPermission:(NSString *)perms retryWith:(void (^)(void))recallAPI
{
    if (recallAPI) {
        // Recovery tactic: Call API again.
        if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryRetry) {
            recallAPI();
            return;
        }
        
        if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryThrottling) {
            // Schedule a little bit later
            double delayInSeconds = 3.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), recallAPI);
            return;
        }
    }
    
    // Users can revoke post permissions on your app externally so it
    // can be worthwhile to request for permissions again at the point
    // that they are needed. This sample assumes a simple policy
    // of re-requesting permissions.
    if ([FBErrorUtility errorCategoryForError:error] == FBErrorCategoryPermissions && perms) {
#ifdef DEBUG
        NSLog(@"Re-requesting permissions: %@", perms);
#endif
        // Recovery tactic: Ask for required permissions again.
        [self doWithPermission:perms toDo:recallAPI];
        return;
    }
    
    NSString *alertMessage;
    if ([FBErrorUtility shouldNotifyUserForError:error]) {
        // If the SDK has a message for the user, surface it.
        alertMessage = [FBErrorUtility userMessageForError:error];
    } else {
        NSLog(@"Unexpected error posting to open graph: %@", error);
        //alertMessage = @"Unable to post to open graph. Please try again later.";
    }
    
    if (alertMessage) {
        [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                    message:alertMessage
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
    return FB_IOS_SDK_VERSION_STRING;
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
    [FBAppEvents activateApp];
    [FBAppCall handleDidBecomeActive];
}

- (BOOL)login:(BOOL)doAuthorize withPermissions:(NSArray *)perms andThen:(void (^)(void))handler
{
    _afterLogin = [handler copy];
    FBSession *session = [[FBSession alloc] initWithAppID:_appID
                                              permissions:perms
                                          defaultAudience:FBSessionDefaultAudienceEveryone
                                          urlSchemeSuffix:_appSuffix
                                       tokenCacheStrategy:nil];
    [FBSession setActiveSession:session];

    // Check whether we have a token for an old app ID - force reset if the ID changed!
    if (session.state == FBSessionStateCreatedTokenLoaded && ![session.appID isEqualToString:_appID]) {
        [session closeAndClearTokenInformation];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    BOOL facebook_reset = [defaults boolForKey:@"facebook_reset"];
    if (facebook_reset) {
        [session closeAndClearTokenInformation];
        [defaults setBool:NO forKey:@"facebook_reset"]; // Don't do it on the next start
        [defaults synchronize];
    } else if (doAuthorize || (session.state == FBSessionStateCreatedTokenLoaded)) {
        
        if (doAuthorize) { // Explicit login, clear the reset flag in case it was still set
            [defaults setBool:NO forKey:@"facebook_reset"];
            [defaults synchronize];
            _reset = NO;
        }
        [session openWithBehavior:FBSessionLoginBehaviorUseSystemAccountIfPresent
                completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
            [self sessionStateChanged:session
                                state:status
                                error:error];
        }];        
    }
    return session.isOpen;
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
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (BOOL)isSessionValid {
    return FBSession.activeSession.isOpen;
}

- (BOOL)isNativeSession {
    return FBSession.activeSession.accessTokenData.loginType == FBSessionLoginTypeSystemAccount;
}

- (UIView *)profilePictureViewOfSize:(CGFloat)side {
    FBProfilePictureView *profileView = [[FBProfilePictureView alloc] initWithProfileID:self.userID
                                                                        pictureCropping:FBProfilePictureCroppingSquare];
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

- (BOOL)handleOpenURL:(NSURL *)url {
    return [FBSession.activeSession handleOpenURL:url];
}

- (void)doWithPermission:(NSString *)permission
                    toDo:(void (^)(void))handler
{
    if (FBSession.activeSession.isOpen) {
#ifdef DEBUG
        NSLog(@"Available permissions: %@", FBSession.activeSession.permissions);
#endif
        if ([FBSession.activeSession.permissions containsObject:permission]) {
            if (handler)
                handler();
        } else {
#ifdef DEBUG
            NSLog(@"Requesting new permission: %@", permission);
#endif
            @try {
                [FBSession.activeSession requestNewPublishPermissions:@[permission]
                                                      defaultAudience:FBSessionDefaultAudienceEveryone
                                                    completionHandler:^(FBSession *session, NSError *error) {
                                                        if (error) {
                                                            [self handleRequestPermissionError:error];
                                                        } else if (handler) {
                                                            handler();
                                                        }
                                                    }];
            }
            @catch (NSException *exception) { // Avoid crashes here when already in the process of authorizing
                NSLog(@"Exception received while requesting new permissions: %@", exception);
            }
        }
    } else if (FBSession.activeSession.state != FBSessionStateCreatedOpening) {
        [self login:YES withPermissions:@[permission] andThen:^{
            [self doWithPermission:permission toDo:handler];
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
    [self doWithPermission:@"publish_actions" toDo:^{
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
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:[NSString stringWithFormat:@"me/%@:%@",_namespace,action]
                                              parameters:@{object:url}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                [self handleAPICallError:error
                           forPermission:@"publish_actions"
                               retryWith:^{
                    [req startWithCompletionHandler:nil];
                }];
                NSLog(@"Error publishing action: %@", error);
            }
        }];
    }];
}

- (void)publishWatch:(NSString *)videoURL {
    if (!self.publishTimeline)
        return;
    
    NSMutableDictionary<FBGraphObject> *action = [FBGraphObject graphObject];
    action[@"video"] = videoURL;
    
    [self doWithPermission:@"publish_actions" toDo:^{
        [FBRequestConnection startForPostWithGraphPath:@"me/video.watches"
                                           graphObject:action
                                     completionHandler:^(FBRequestConnection *connection,
                                                         id result,
                                                         NSError *error) {
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
    NSMutableDictionary<FBGraphObject> *action = [FBGraphObject graphObject];
    action[@"object"] = url;
    
    [self doWithPermission:@"publish_actions" toDo:^{
        [FBRequestConnection startForPostWithGraphPath:@"me/og.likes"
                                           graphObject:action
                                     completionHandler:^(FBRequestConnection *connection,
                                                         id result,
                                                         NSError *error) {
                                         if (error) {
                                             NSDictionary *errDict = [error userInfo][@"error"];
                                             if ([errDict[@"code"] integerValue] != 3501) { // Duplicate error code from FB
                                                 [self handleAPICallError:error
                                                            forPermission:@"publish_actions"
                                                                retryWith:^{
                                                                    [FBRequestConnection startForPostWithGraphPath:@"me/og.likes"
                                                                                                       graphObject:action
                                                                                                 completionHandler:^(FBRequestConnection *connection,
                                                                                                                     id result,
                                                                                                                     NSError *error) {
                                                                                                     if (error) {
                                                                                                         NSLog(@"Error publishing like: %@", error);
                                                                                                     }
                                                                                                     if (completion) {
                                                                                                         completion(result[@"id"]);
                                                                                                     }
                                                                                                 }];
                                                                }];
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
    [self doWithPermission:@"publish_actions" toDo:^{
        [FBRequestConnection startWithGraphPath:likeID
                                     parameters:nil
                                     HTTPMethod:@"DELETE"
                              completionHandler:^(FBRequestConnection *connection,
                                                  id result,
                                                  NSError *error) {
                                  if (error) {
                                      [self handleAPICallError:error
                                                 forPermission:@"publish_actions"
                                                     retryWith:^{
                                                         [FBRequestConnection startWithGraphPath:likeID
                                                                                      parameters:nil
                                                                                      HTTPMethod:@"DELETE"
                                                                               completionHandler:nil];
                                                     }];
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
    
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                              parameters:@{@"achievement":achievementURL}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSDictionary *errDict = [error userInfo][@"error"];
                if ([errDict[@"code"] integerValue] != 3501) { // Duplicate achievement error code from FB
                    [self handleAPICallError:error
                               forPermission:@"publish_actions"
                                   retryWith:^{
                                       [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                           if (error == nil) {
                                               [_achievements addObject:achievementURL];
                                           } else {
                                               NSLog(@"Error publishing achievement: %@", error);                                               
                                           }
                                       }];
                                   }];
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
    
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                              parameters:@{@"achievement":achievementURL}
                                              HTTPMethod:@"DELETE"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSDictionary *errDict = [error userInfo][@"error"];
                if ([errDict[@"code"] integerValue] != 3404) { // No such achievement for user error code from FB
                    [self handleAPICallError:error
                               forPermission:@"publish_actions"
                                   retryWith:^{
                                       [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                           if (error == nil) {
                                               [_achievements removeObject:achievementURL];
                                           } else {
                                               NSLog(@"Error deleting achievement: %@", error);
                                           }
                                       }];
                                   }];
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
 
    [self doWithPermission:@"publish_actions" toDo:^{
        for (NSString *achievementURL in _achievements) {
            FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                                  parameters:@{@"achievement":achievementURL}
                                                  HTTPMethod:@"DELETE"];
            [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                if (error) {
                    NSDictionary *errDict = [error userInfo][@"error"];
                    if ([errDict[@"code"] integerValue] != 3404) { // No such achievement for user error code from FB
                        [self handleAPICallError:error
                                   forPermission:@"publish_actions"
                                       retryWith:^{
                                           [req startWithCompletionHandler:nil];
                                       }];

                        NSLog(@"Error deleting achievement: %@", error);
                    }
                 }
            }];
        }
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
        FBRequest *request = [[FBRequest alloc] initWithSession:nil
                                                      graphPath:nil];
        FBRequestConnection *connection = [[FBRequestConnection alloc] init];
        [connection addRequest:request completionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                NSLog(@"Error processing paging: %@", error);
            } else {
                [self processAchievementData:result];
            }
        }];
        NSURL *url = [NSURL URLWithString:paging[@"next"]];
        connection.urlRequest = [NSMutableURLRequest requestWithURL:url];
        [connection start];
    }
}

// Retrieve the list of achievements earned from Facebook
- (void)fetchAchievementsAndThen:(void (^)(NSSet *achievements))handler
{
    // We probably don't need to request extended permissions just to get the list of earned achievements
    FBRequest *req = [FBRequest requestWithGraphPath:@"me/achievements"
                                          parameters:nil
                                          HTTPMethod:@"GET"];
    [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
        if (error) {
            [self handleAPICallError:error
                       forPermission:nil
                           retryWith:^{
                               [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
                                   if (error == nil) {
                                       [_achievements removeAllObjects];
                                       [self processAchievementData:result];
                                       if (handler) {
                                           handler(_achievements);
                                       }
                                   } else {
                                       NSLog(@"Failed to retrieve FB achievements: %@", error);
                                   }
                               }];
                           }];
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
    [self doWithPermission:@"publish_actions" toDo:^{
        FBRequest *req = [FBRequest requestWithGraphPath:@"me/scores"
                                              parameters:@{@"score":[NSString stringWithFormat:@"%lld",score]}
                                              HTTPMethod:@"POST"];
        [req startWithCompletionHandler:^(FBRequestConnection *connection, id result, NSError *error) {
            if (error) {
                [self handleAPICallError:error
                           forPermission:@"publish_actions"
                               retryWith:^{
                                   [req startWithCompletionHandler:nil];
                               }];
                NSLog(@"Error publishing score: %@", error);
            }
        }];
    }];
}

#pragma mark - FB App Events

+ (void)logLevelReached:(NSUInteger)level
{
    [FBAppEvents logEvent:FBAppEventNameAchievedLevel
               parameters:@{FBAppEventParameterNameLevel : @(level)}];
}

+ (void)logAchievement:(NSString *)description
{
    [FBAppEvents logEvent:FBAppEventNameUnlockedAchievement
               parameters:@{FBAppEventParameterNameDescription : description}];
}

+ (void)logTutorialCompleted
{
    [FBAppEvents logEvent:FBAppEventNameCompletedTutorial];
}

+ (void) logViewedContentID:(NSString *)contentID type:(NSString *)type
{
    [FBAppEvents logEvent:FBAppEventNameViewedContent
               parameters:@{FBAppEventParameterNameContentID : contentID,
                            FBAppEventParameterNameContentType : type}];
}

+ (void) logPurchase:(NSString *)item amount:(double)amount currency:(NSString *)currency {
    [FBAppEvents logPurchase:amount
                    currency:currency
                  parameters:@{@"Item":item}];
}

@end
