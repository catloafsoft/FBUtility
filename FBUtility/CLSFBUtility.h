//
//  CLSFBUtility.h
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011-2019 Catloaf Software, LLC. All rights reserved.
//

@class CLSFBUtility;

@protocol CLSFBUtilityDelegate <NSObject>
@optional
// Notified upon login/logout - may span many app sessions
- (void)facebookLoggedIn:(NSString * _Nullable)fullName;
- (void)facebookLoggedOut;

// Called at the beginning of each session when the user is logged in
- (void)facebookIsLoggedIn:(NSString * _Nullable)fullName;

// Called upon successful completion of the dialogs
- (void)publishedToFeed:(nonnull NSString *)postId;
- (void)sharedWithFriends;

// Implement these methods to show a HUD to the user while data is being fetched
- (void)startedFetchingFromFacebook:(nonnull CLSFBUtility *)fb;
- (void)endedFetchingFromFacebook:(nonnull CLSFBUtility *)fb;

@end

///// Notifications that get posted for FB status changes (alternative to delegate methods)
#define kFBUtilLoggedInNotification     @"com.catloafsoft:FBUtilityLoggedInNotification"
#define kFBUtilLoggedOutNotification    @"com.catloafsoft:FBUtilityLoggedOutNotification"

NS_ASSUME_NONNULL_BEGIN
@interface CLSFBUtility : NSObject

@property (nonatomic,readonly) BOOL loggedIn, publishTimeline;
@property (nonatomic,readonly) NSString *fullName, *userID, *gender, *location, *appStoreID;
@property (nonatomic,readonly) NSURL *appStoreURL; // Computed from ID
@property (nonatomic,nullable,readonly) NSDate *birthDay;
@property (nonatomic,weak,readonly) id<CLSFBUtilityDelegate> delegate;

// The following properties should be set ASAP so that all dialogs are functional.
@property (nonatomic,nullable,copy) NSString *appName, *appDescription;
@property (nonatomic,nullable,copy) NSURL  *appIconURL;

// An URL for a site contening Open Graph information for the app (typically the home page for the app)
@property (nonatomic,nullable,copy) NSURL *appURL;

+ (BOOL)openPage:(unsigned long long)uid;
// Determines if the official Facebook app is available
+ (BOOL)appInstalled;

// Returns the version string for the FB SDK being used
+ (NSString *)sdkVersion;

// Try to detect if the user is in a blocked locale (i.e. China)
+ (BOOL)inBlockedCountry;

- (instancetype)initWithAppID:(NSString * _Nullable)appID
                 schemeSuffix:(NSString * _Nullable)suffix
                  clientToken:(NSString * _Nullable)token
                 appNamespace:(NSString * _Nullable)ns
                   appStoreID:(NSString * _Nullable)appStoreID
                 fetchProfile:(BOOL)fetchProfile // Requires app review
                     delegate:(_Nullable id<CLSFBUtilityDelegate>)delegate NS_DESIGNATED_INITIALIZER;

// Returns the target_url passed from FB if available, or nil
- (NSURL *)getTargetURL:(NSURL *)url;

// Login methods, the handler is only executed upon successful completion
- (BOOL)login:(BOOL)doAuthorize from:(UIViewController * _Nullable)vc andThen:(void (^ _Nullable)(BOOL success))handler;
- (BOOL)login:(BOOL)doAuthorize withPublishPermissions:(NSArray * _Nullable)perms from:(UIViewController * _Nullable)vc andThen:(void (^ _Nullable)(BOOL success))handler;
- (void)logout;

// Methods to call from the app delegate
- (void)handleDidBecomeActive;
// These methods are new in SDK 4.x and should be called from now on
+ (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation;
+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey, id> *)options;
// Note: we no longer support the older handleOpenURL:

// Utility function to break down the URL parameters
+ (NSDictionary*)parseURLParams:(NSString *)query;

// Execute a block of code, making sure a particular permission has been enabled
- (void)doWithPermission:(NSString * _Nullable)permission
                    from:(UIViewController * _Nullable)vc
                    toDo:(void (^)(BOOL granted))handler;
- (void)doWithReadPermission:(NSString * _Nullable)permission
                        from:(UIViewController * _Nullable)vc
                        toDo:(void (^)(BOOL granted))handler  __attribute((deprecated("Use doWithPermission:from:toDo: instead.")));
- (void)doWithPublishPermission:(NSString * _Nullable)permission
                           from:(UIViewController * _Nullable)vc
                           toDo:(void (^)(BOOL granted))handler __attribute((deprecated("Use doWithPermission:from:toDo: instead.")));

- (void)publishLike:(NSString *)url from:(UIViewController * _Nullable)vc andThen:(void (^ _Nullable)(NSString * _Nullable likeID))completion
__attribute((deprecated("OpenGraph actions are no longer supported.")));
;
- (void)publishUnlike:(NSString *)likeID from:(UIViewController * _Nullable)vc andThen:(void (^ _Nullable)(BOOL success))completion
__attribute((deprecated("OpenGraph actions are no longer supported.")));
;
- (void)publishWatch:(NSString *)videoURL from:(UIViewController * _Nullable)vc;

// Game-specific actions to be published - Deprecated since April 2018
- (void)fetchAchievementsAndThen:(void (^ _Nullable)(NSSet *achievements))handler __attribute((deprecated("Achievements API has been deprecated.")));
;

/// Returns YES if the achievement was already submitted
- (BOOL)publishAchievement:(NSString *)achievement from:(UIViewController * _Nullable)vc __attribute((deprecated("Achievements API has been deprecated.")));
- (void)removeAchievement:(NSString *)achievement from:(UIViewController * _Nullable)vc __attribute((deprecated("Achievements API has been deprecated.")));

/// Make sure to fetch achievements before trying to remove them all
- (void)removeAllAchievementsFrom:(UIViewController * _Nullable)vc __attribute((deprecated("Achievements API has been deprecated.")));
- (void)publishScore:(int64_t)score from:(UIViewController * _Nullable)vc __attribute((deprecated("Game Score API has been deprecated.")));

// Log FB App Events (always logged)
+ (void)logAchievement:(NSString *)description;
+ (void)logLevelReached:(NSUInteger)level;
+ (void)logTutorialCompleted;
+ (void)logViewedContentID:(NSString *)contentID type:(NSString *)type;

// Log in-app purchases
+ (void)logPurchase:(NSString *)item amount:(double)amount currency:(NSString *)currency;

// Get a square FBSDKProfilePictureView for the logged-in user
- (UIView *)profilePictureViewOfSize:(CGFloat)side;

// Common dialogs - handle authentification automatically when needed

/// Publish a story on the users's feed
- (void)publishToFeedWithCaption:(NSString *)caption 
                     description:(NSString * _Nullable)desc // May include HTML
                 textDescription:(NSString * _Nullable)text
                            name:(NSString *)name
                      properties:(NSDictionary * _Nullable)props
                         hashtag:(NSString * _Nullable)hashtag
                expandProperties:(BOOL)expand
                       imagePath:(NSString * _Nullable)imgPath
                           image:(UIImage * _Nullable)image
                        imageURL:(NSURL * _Nullable)img
                      contentURL:(NSURL * _Nullable)contentURL
                            from:(UIViewController *)vc
                            then:(void (^ _Nullable)(NSDictionary *result))success;

/// Share the app with the Facebook friends of the logged in user (app request)
- (void)shareAppWithFriendsFrom:(UIViewController *)vc;

@end
NS_ASSUME_NONNULL_END

