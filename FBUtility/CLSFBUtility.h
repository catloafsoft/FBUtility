//
//  CLSFBUtility.h
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011-2014 Catloaf Software, LLC. All rights reserved.
//

@class CLSFBUtility;

@protocol CLSFBUtilityDelegate <NSObject>
@optional
// Notified upon login/logout 
- (void)facebookLoggedIn:(NSString *)fullName;
- (void)facebookLoggedOut;

// Called upon completion of first authentication through dialog or app
- (void)facebookAuthenticated;

// Called upon successful completion of the dialogs
- (void)publishedToFeed:(NSString *)postId;
- (void)sharedWithFriends;

// Implement these methods to show a HUD to the user while data is being fetched
- (void)startedFetchingFromFacebook:(CLSFBUtility *)fb;
- (void)endedFetchingFromFacebook:(CLSFBUtility *)fb;

@end

///// Notifications that get posted for FB status changes (alternative to delegate methods)
#define kFBUtilLoggedInNotification     @"com.catloafsoft:FBUtilityLoggedInNotification"
#define kFBUtilLoggedOutNotification    @"com.catloafsoft:FBUtilityLoggedOutNotification"

@interface CLSFBUtility : NSObject

@property (nonatomic,readonly) BOOL loggedIn, publishTimeline;
@property (nonatomic,readonly) NSString *fullName, *userID, *gender, *location, *appStoreID;
@property (nonatomic,readonly) NSDate *birthDay;
@property (nonatomic,weak,readonly) id<CLSFBUtilityDelegate> delegate;

// The following properties should be set ASAP so that all dialogs are functional.
@property (nonatomic,copy) NSString *appName, *appIconURL, *appDescription;
// An URL for a site contening Open Graph information for the app (typically the home page for the app)
@property (nonatomic,copy) NSURL *appURL;

+ (BOOL)openPage:(unsigned long long)uid;

// Returns the version string for the FB SDK being used
+ (NSString *)sdkVersion;

// Try to detect if the user is in a blocked locale (i.e. China)
+ (BOOL)inBlockedCountry;

- (instancetype)initWithAppID:(NSString *)appID 
       schemeSuffix:(NSString *)suffix
        clientToken:(NSString *)token
       appNamespace:(NSString *)ns
         appStoreID:(NSString *)appStoreID
          fetchUser:(BOOL)fetch
           delegate:(id<CLSFBUtilityDelegate>)delegate NS_DESIGNATED_INITIALIZER;

// Returns the target_url passed from FB if available, or nil
- (NSString *)getTargetURL:(NSURL *)url;

- (BOOL)login:(BOOL)doAuthorize andThen:(void (^)(void))handler;
- (BOOL)login:(BOOL)doAuthorize withPermissions:(NSArray *)perms andThen:(void (^)(void))handler;
- (void)logout;

@property (NS_NONATOMIC_IOSONLY, getter=isSessionValid, readonly) BOOL sessionValid;

// Methods to call from the app delegate
- (void)handleDidBecomeActive;
// These methods are new in SDK 4.x and should be called from now on
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation;
// Note: we no longer support the older handleOpenURL:

// Utility function to break down the URL parameters
+ (NSDictionary*)parseURLParams:(NSString *)query;

// Execute a block of code, making sure a particular permission has been enabled
- (void)doWithReadPermission:(NSString *)permission
                        toDo:(void (^)(BOOL granted))handler;
- (void)doWithPublishPermission:(NSString *)permission
                           toDo:(void (^)(BOOL granted))handler;


// Open Graph actions
- (void)publishAction:(NSString *)action withObject:(NSString *)object objectURL:(NSString *)url;
- (void)publishLike:(NSString *)url andThen:(void (^)(NSString *likeID))completion;
- (void)publishUnlike:(NSString *)likeID andThen:(void (^)(BOOL success))completion;
- (void)publishWatch:(NSString *)videoURL;

// Game-specific actions to be published
- (void)fetchAchievementsAndThen:(void (^)(NSSet *achievements))handler;
// Returns YES if the achievement was already submitted
- (BOOL)publishAchievement:(NSString *)achievement;
- (void)removeAchievement:(NSString *)achievement;
- (void)removeAllAchievements;
- (void)publishScore:(int64_t)score;

// Log FB App Events (always logged)
+ (void)logAchievement:(NSString *)description;
+ (void)logLevelReached:(NSUInteger)level;
+ (void)logTutorialCompleted;
+ (void)logViewedContentID:(NSString *)contentID type:(NSString *)type;

// Log in-app purchases
+ (void) logPurchase:(NSString *)item amount:(double)amount currency:(NSString *)currency;

// Get a square FBProfilePictureView for the logged-in user
- (UIView *)profilePictureViewOfSize:(CGFloat)side;

// Common dialogs - handle authentification automatically when needed

// Publish a story on the users's feed
- (void)publishToFeedWithCaption:(NSString *)caption 
                     description:(NSString *)desc // May include HTML
                 textDescription:(NSString *)text
                            name:(NSString *)name
                      properties:(NSDictionary *)props
                expandProperties:(BOOL)expand
                          appURL:(NSString *)appURL
                       imagePath:(NSString *)imgPath
                        imageURL:(NSString *)img
                       imageLink:(NSString *)imgURL
                            from:(UIViewController *)vc;

// Share the app with the Facebook friends of the logged in user (app request)
- (void)shareAppWithFriends:(NSString *)message from:(UIViewController *)vc;

@end
