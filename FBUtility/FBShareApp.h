//
//  FBShareApp.h
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBUtility.h"

// Now using the built-in App Invite Dialog from the Sharing SDK
// failing that, fall back to posting on the user's feed

@interface FBShareApp : NSObject

- (instancetype)initWithFacebookUtil:(CLSFBUtility *)fb message:(NSString *)msg NS_DESIGNATED_INITIALIZER;

- (void)presentFromViewController:(UIViewController *)controller;

@end
