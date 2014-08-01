//
//  FBShareApp.h
//  Hold the data for the dialog to share the app with friends.
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBUtility.h"

// With the FB SDK v3.15 and later, this switches to a simple feed post dialog, as we can no longer get the list
// of friends from the user without restricted extended permissions.

@interface FBShareApp : NSObject

- (id)initWithFacebookUtil:(CLSFBUtility *)fb message:(NSString *)msg;

- (void)presentFromViewController:(UIViewController *)controller;

@end
