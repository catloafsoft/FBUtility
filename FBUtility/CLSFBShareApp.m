//
//  FBShareApp.m
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011-2019 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBShareApp.h"
#import "CLSFBFeedPublish.h"

@import FBSDKCoreKit;
@import FBSDKShareKit;

@interface CLSFBShareApp () <FBSDKSharingDelegate>

@end

@implementation CLSFBShareApp {
    CLSFBUtility *_facebookUtil;
}

- (instancetype)initWithFacebookUtil:(CLSFBUtility *)fb
{
    self = [super init];
    if (self) {
        _facebookUtil = fb;
    }
    return self;
}

- (instancetype)init {
    NSAssert(0, @"Call initWithFacebookUtil: instead.");
    return [self initWithFacebookUtil:[[CLSFBUtility alloc] init]];
}

- (void)presentFromViewController:(UIViewController *)controller
{
    NSAssert(_facebookUtil.appName != nil, @"The FB application name needs to be set for the dialog.");
    NSAssert(_facebookUtil.appStoreID != nil, @"The App Store ID needs to be set for the dialog.");
    NSAssert(_facebookUtil.appIconURL != nil, @"The app icon URL should really be set for the stories.");
    NSAssert(_facebookUtil.appURL != nil, @"The app URL needs to be set to a page containing Open Graph data.");

    FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
    content.contentURL = _facebookUtil.appStoreURL;
    content.quote = _facebookUtil.appDescription;
    
    FBSDKShareDialog *dialog = [FBSDKShareDialog dialogWithViewController:controller
                                                              withContent:content
                                                                 delegate:self];
    
    if ([dialog canShow]) {
        [dialog show];
    } else if (_facebookUtil.loggedIn) {
        CLSFBFeedPublish *feedPublish = [[CLSFBFeedPublish alloc] initWithFacebookUtil:_facebookUtil
                                                                               caption:[NSString stringWithFormat:NSLocalizedString(@"Check out the %@ app!", @"Facebook feed story caption to share app"),_facebookUtil.appName]
                                                                           description:_facebookUtil.appDescription
                                                                       textDescription:_facebookUtil.appDescription
                                                                                  name:NSLocalizedString(@"I've been using this iOS app, why don't you give it a shot?",
                                                                                                         @"Facebook request notification text")
                                                                            properties:nil
                                                                               hashtag:@"iOS"
                                                                             imagePath:nil
                                                                                 image:nil
                                                                              imageURL:_facebookUtil.appIconURL
                                                                            contentURL:_facebookUtil.appStoreURL];
        [feedPublish showDialogFrom:controller then:nil];
    } else {
        [_facebookUtil login:YES from:controller andThen:^(BOOL success){
            if (success)
                [self presentFromViewController:controller];
        }];
    }
}

#pragma mark - FBSDKSharing delegate

- (void)sharer:(nonnull id<FBSDKSharing>)sharer didCompleteWithResults:(nonnull NSDictionary<NSString *,id> *)results {
#ifdef DEBUG
    NSLog(@"App sharing dialog completed with results: %@", results);
#endif
}

- (void)sharer:(nonnull id<FBSDKSharing>)sharer didFailWithError:(nonnull NSError *)error {
    NSLog(@"Failed app sharing dialog: %@", error);
}

- (void)sharerDidCancel:(nonnull id<FBSDKSharing>)sharer {
#ifdef DEBUG
    NSLog(@"App sharing dialog was canceled");
#endif
}

@end
