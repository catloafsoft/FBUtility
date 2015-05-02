//
//  FBShareApp.m
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011-2013 Catloaf Software, LLC. All rights reserved.
//

#import "FBShareApp.h"
#import "FBFeedPublish.h"

@import FBSDKCoreKit;
@import FBSDKShareKit;

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

- (void)presentFromViewController:(UIViewController *)controller {
    if (_facebookUtil.loggedIn) {
        NSAssert(_facebookUtil.appName != nil, @"The FB application name needs to be set for the dialog.");
        NSAssert(_facebookUtil.appStoreID != nil, @"The App Store ID needs to be set for the dialog.");
        NSAssert(_facebookUtil.appIconURL != nil, @"The app icon URL should really be set for the stories.");

        NSString *appURL = [NSString stringWithFormat:@"https://itunes.apple.com/app/id%@?mt=8&uo=4&at=11l4W7",_facebookUtil.appStoreID];
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

#ifndef FB_USE_FEED_PUBLISH_FOR_SHARE
- (BOOL)friendPickerViewController:(FBFriendPickerViewController *)friendPicker
                 shouldIncludeUser:(id<FBGraphUserExtraFields>)user
{
    // Ignore users who are already using the app
    if ([[user objectForKey:@"installed"] boolValue] == YES)
        return NO;
    
    NSArray *deviceData = user.devices;
    // Loop through list of devices
    for (NSDictionary *deviceObject in deviceData) {
        // Check if there is a device match
        if ([@"iOS" isEqualToString:[deviceObject objectForKey:@"os"]]) {
            // Friend is an iOS user, include them in the display
            return YES;
        }
    }
    // Friend is not an iOS user, do not include them
    return NO;
}

- (void)friendPickerViewController:(FBFriendPickerViewController *)friendPicker
                       handleError:(NSError *)error
{
    NSLog(@"FriendPickerViewController error: %@", error);
}

- (void)facebookViewControllerCancelWasPressed:(id)sender
{
#ifdef DEBUG
    NSLog(@"Friend selection cancelled.");
#endif
    if ([_presenter respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        [_presenter dismissViewControllerAnimated:YES completion:^{
            _presenter = nil;
        }];
    } else {
        [_presenter dismissModalViewControllerAnimated:YES];
        _presenter = nil;
    }
}

- (void)facebookViewControllerDoneWasPressed:(id)sender
{
    FBFriendPickerViewController *fpc = (FBFriendPickerViewController *)sender;
    _fbFriends = [[NSMutableArray alloc] initWithCapacity:[fpc.selection count]];
    for (id<FBGraphUserExtraFields> user in fpc.selection) {
#ifdef DEBUG
        NSLog(@"Friend selected: %@", user.name);
#endif
        [_fbFriends addObject:user.objectID];
    }
    if ([_presenter respondsToSelector:@selector(dismissViewControllerAnimated:completion:)]) {
        [_presenter dismissViewControllerAnimated:YES completion:^{
            [self showActualDialog];
            _presenter = nil;
        }];
    } else {
        [_presenter dismissModalViewControllerAnimated:YES];
        [self showActualDialog];
        _presenter = nil;
    }
}

- (void)showActualDialog {
    if ([_fbFriends count] == 0) {
        return;
    }
    NSAssert(_facebookUtil.appName != nil, @"The FB application name needs to be set for the dialog.");
    
    NSString *friendString = [_fbFriends componentsJoinedByString:@","];
#ifdef DEBUG
    NSLog(@"Users to send to: %@", friendString);
#endif
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   NSLocalizedString(@"Check this app out!",@"Facebook request notification text"), @"notification_text",
                                   nil];
    if (friendString) {
        [params setObject:friendString forKey:@"to"];
    }
    
    [FBWebDialogs presentRequestsDialogModallyWithSession:nil
                                                  message:_message
                                                    title:[NSString stringWithFormat:NSLocalizedString(@"Share %@ with friends", @"Facebook dialog title to share app"),_facebookUtil.appName]
                                               parameters:params
                                                  handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
                                                      if (result == FBWebDialogResultDialogCompleted) {
                                                          if ([_facebookUtil.delegate respondsToSelector:@selector(sharedWithFriends)])
                                                              [_facebookUtil.delegate sharedWithFriends];
                                                      }
                                                      
                                                      if (error) {
                                                          if ([FBErrorUtility shouldNotifyUserForError:error]) {
                                                              [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                                                                                              message:[FBErrorUtility userMessageForError:error]
                                                                                                             delegate:nil
                                                                                                    cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                                                                                                    otherButtonTitles:nil] show];
                                                          } else if ([FBErrorUtility errorCategoryForError:error] != FBErrorCategoryUserCancelled) {
                                                              NSLog(@"App Request Dialog Error: %@", error);
                                                          }
                                                      }
                                                  }];
}

- (void)dealloc
{
    _friendPickerController.delegate = nil;
}
#endif

@end
