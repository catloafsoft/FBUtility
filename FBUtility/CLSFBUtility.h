//
//  CLSFBUtility.h
//  Utility class to handle common Facebook functionality
//
//  Created by Stéphane Peter on 10/17/11.
//  Copyright (c) 2011-2015 Catloaf Software, LLC. All rights reserved.
//

@class CLSFBUtility;

@protocol CLSFBUtilityDelegate <NSObject>
@optional
// Notified upon login/logout 
- (void)facebookLoggedIn:(nullable NSString *)fullName;
- (void)facebookLoggedOut;

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
@property (nonatomic,readonly) NSString *appStoreURL; // Computed from ID
@property (nonatomic,nullable,readonly) NSDate *birthDay;
@property (nonatomic,weak,readonly) id<CLSFBUtilityDelegate> delegate;

// The following properties should be set ASAP so that all dialogs are functional.
@property (nonatomic,nullable,copy) NSString *appName, *appIconURL, *appDescription;
// An URL for a site contening Open Graph information for the app (typically the home page for the app)
@property (nonatomic,nullable,copy) NSURL *appURL;

+ (BOOL)openPage:(unsigned long long)uid;

// Returns the version string for the FB SDK being used
+ (NSString *)sdkVersion;

// Try to detect if the user is in a blocked locale (i.e. China)
+ (BOOL)inBlockedCountry;

- (instancetype)initWithAppID:(nullable NSString *)appID
                 schemeSuffix:(nullable NSString *)suffix
                  clientToken:(nullable NSString *)token
                 appNamespace:(nullable NSString *)ns
                   appStoreID:(nullable NSString *)appStoreID
                     delegate:(nullable id<CLSFBUtilityDelegate>)delegate NS_DESIGNATED_INITIALIZER;

// Returns the target_url passed from FB if available, or nil
- (NSString *)getTargetURL:(NSURL *)url;

// Login methods, the handler is only executed upon successful completion
- (BOOL)login:(BOOL)doAuthorize from:(nullable UIViewController *)vc andThen:(void (^ _Nullable)(void))handler;
- (BOOL)login:(BOOL)doAuthorize withPublishPermissions:(nullable NSArray *)perms from:(nullable UIViewController *)vc andThen:(void (^ _Nullable)(void))handler;
- (void)logout;

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
                        from:(nullable UIViewController *)vc
                        toDo:(void (^)(BOOL granted))handler;
- (void)doWithPublishPermission:(NSString *)permission
                           from:(nullable UIViewController *)vc
                           toDo:(void (^)(BOOL granted))handler;


// Open Graph actions
- (void)publishAction:(NSString *)action withObject:(NSString *)object objectURL:(NSString *)url;
- (void)publishLike:(NSString *)url andThen:(void (^ _Nullable)(NSString *likeID))completion;
- (void)publishUnlike:(NSString *)likeID andThen:(void (^ _Nullable)(BOOL success))completion;
- (void)publishWatch:(NSString *)videoURL;

// Game-specific actions to be published
- (void)fetchAchievementsAndThen:(void (^ _Nullable)(NSSet *achievements))handler;

/// Returns YES if the achievement was already submitted
- (BOOL)publishAchievement:(NSString *)achievement;
- (void)removeAchievement:(NSString *)achievement;
/// Make sure to fetch achievements before trying to remove them all
- (void)removeAllAchievements;
- (void)publishScore:(int64_t)score;

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
                     description:(nullable NSString *)desc // May include HTML
                 textDescription:(nullable NSString *)text
                            name:(NSString *)name
                      properties:(nullable NSDictionary *)props
                expandProperties:(BOOL)expand
                       imagePath:(nullable NSString *)imgPath
                        imageURL:(nullable NSString *)img
                       imageLink:(nullable NSString *)imgURL
                            from:(UIViewController *)vc;

/// Share the app with the Facebook friends of the logged in user (app request)
- (void)shareAppWithFriendsFrom:(UIViewController *)vc;

@end
NS_ASSUME_NONNULL_END

