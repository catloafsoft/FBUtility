//
//  FBShareApp.m
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011-2015 Catloaf Software, LLC. All rights reserved.
//

#import "FBShareApp.h"
#import "FBFeedPublish.h"

@import FBSDKCoreKit;
@import FBSDKShareKit;

@interface FBShareApp () <FBSDKAppInviteDialogDelegate>

@end

@implementation FBShareApp {
    NSString     *_message;
    CLSFBUtility *_facebookUtil;
}

- (instancetype)initWithFacebookUtil:(CLSFBUtility *)fb message:(NSString *)msg {
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _message = [msg copy];
    }
    return self;
}

- (void)presentFromViewController:(UIViewController *)controller
{
    NSAssert(_facebookUtil.appName != nil, @"The FB application name needs to be set for the dialog.");
    NSAssert(_facebookUtil.appStoreID != nil, @"The App Store ID needs to be set for the dialog.");
    NSAssert(_facebookUtil.appIconURL != nil, @"The app icon URL should really be set for the stories.");

    NSString *appURL = [NSString stringWithFormat:@"https://itunes.apple.com/app/id%@?mt=8&uo=4&at=11l4W7",_facebookUtil.appStoreID];

    FBSDKAppInviteContent *content = [[FBSDKAppInviteContent alloc] init];
    content.previewImageURL = [NSURL URLWithString:_facebookUtil.appIconURL];
    content.appLinkURL = [NSURL URLWithString:appURL]; // TODO: App URL with app link info
    
    FBSDKAppInviteDialog *dialog = [[FBSDKAppInviteDialog alloc] init];
    dialog.content = content;
    dialog.delegate = self;
    
    if ([dialog canShow]) {
        [dialog show];
    } else if (_facebookUtil.loggedIn) {
        FBFeedPublish *feedPublish = [[FBFeedPublish alloc] initWithFacebookUtil:_facebookUtil
                                                                         caption:[NSString stringWithFormat:NSLocalizedString(@"Check out the %@ app!", @"Facebook feed story caption to share app"),_facebookUtil.appName]
                                                                     description:_facebookUtil.appDescription
                                                                 textDescription:_facebookUtil.appDescription
                                                                            name:NSLocalizedString(@"I've been using this iOS app, why don't you give it a shot?",
                                                                                                   @"Facebook request notification text")
                                                                      properties:nil
                                                                          appURL:appURL
                                                                       imagePath:nil
                                                                        imageURL:_facebookUtil.appIconURL
                                                                       imageLink:appURL];
        [feedPublish showDialogFrom:controller];
    } else {
        [_facebookUtil login:YES andThen:^{
            [self presentFromViewController:controller];
        }];
    }
}

#pragma mark - FBSDKAppInviteDialogDelegate

- (void)appInviteDialog:(FBSDKAppInviteDialog *)appInviteDialog didCompleteWithResults:(NSDictionary *)results
{
    
}

- (void)appInviteDialog:(FBSDKAppInviteDialog *)appInviteDialog didFailWithError:(NSError *)error
{
    NSLog(@"Failed app invite dialog: %@", error);
}


@end
