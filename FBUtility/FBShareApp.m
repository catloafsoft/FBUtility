//
//  FBShareApp.m
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011-2013 Catloaf Software, LLC. All rights reserved.
//

#import "FBShareApp.h"
#import "FBGraphUserExtraFields.h"

@implementation FBShareApp {
    NSString *_message;
    NSMutableArray *_fbFriends;
    CLSFBUtility *_facebookUtil;
    FBFriendPickerViewController *_friendPickerController;
    UIViewController *_presenter;
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
            [_presenter presentViewController:_friendPickerController animated:YES completion:nil];
        }
        
    } else {
        [_facebookUtil login:YES andThen:^{
            [self presentFromViewController:controller];
        }];
    }
}

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
        [_fbFriends addObject:[user objectForKey:@"id"]]; // Work around weird iOS validation
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
                                                          if (error.fberrorShouldNotifyUser) {
                                                              [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                                                                                              message:error.fberrorUserMessage
                                                                                                             delegate:nil
                                                                                                    cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                                                                                                    otherButtonTitles:nil] show];
                                                          } else if (error.fberrorCategory != FBErrorCategoryUserCancelled) {
                                                              NSLog(@"App Request Dialog Error: %@", error);
                                                          }
                                                      }
                                                  }];
}

- (void)dealloc
{
    _friendPickerController.delegate = nil;
}

@end
