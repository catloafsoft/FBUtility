//
//  FBShareApp.m
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011-2013 Catloaf Software, LLC. All rights reserved.
//

#import "FBShareApp.h"
#import "FBGraphUserExtraFields.h"
#import "FBFeedPublish.h"

// This macro was introduced in SDK 3.14 with a value of "v2.0"
#ifdef FB_IOS_SDK_TARGET_PLATFORM_VERSION
# define FB_USE_FEED_PUBLISH_FOR_SHARE 1
#endif

@interface FBShareApp () <FBFriendPickerDelegate>

@end

@implementation FBShareApp {
    NSString *_message;
    CLSFBUtility *_facebookUtil;

#ifndef FB_USE_FEED_PUBLISH_FOR_SHARE
    // Only used for API < 2.0
    NSMutableArray *_fbFriends;
    FBFriendPickerViewController *_friendPickerController;
    UIViewController *_presenter;
#endif
}


- (id)initWithFacebookUtil:(CLSFBUtility *)fb message:(NSString *)msg {
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _message = [msg copy];
    }
    return self;
}

- (void)presentFromViewController:(UIViewController *)controller {
    if (FBSession.activeSession.isOpen) {
#ifdef FB_USE_FEED_PUBLISH_FOR_SHARE
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
#else
        _friendPickerController = [[FBFriendPickerViewController alloc] init];
        _friendPickerController.modalPresentationStyle = UIModalPresentationFormSheet;

        // Configure the picker ...
        _friendPickerController.title = NSLocalizedString(@"Select Friends",@"Facebook friend picker title");
        // Set this view controller as the friend picker delegate
        _friendPickerController.delegate = self;
        // Ask for friend device data
        _friendPickerController.fieldsForRequest = [NSSet setWithObjects:@"devices", @"installed", nil];
        
        // Fetch the data
        [_friendPickerController loadData];
        [_friendPickerController clearSelection];
        
        // Present view controller modally.
        _presenter = controller;
        if ([_presenter respondsToSelector:@selector(presentViewController:animated:completion:)]) {
            // iOS 5+
            if (_presenter.presentedViewController != nil) {
                _presenter = _presenter.presentedViewController;
            }
            [_presenter presentViewController:_friendPickerController
                                     animated:YES
                                   completion:nil];
        } else {
            [_presenter presentModalViewController:_friendPickerController
                                          animated:YES];
        }
#endif
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
