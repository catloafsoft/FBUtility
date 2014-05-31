//
//  CLSFBAppDelegate.h
//  FBUtilityApp
//
//  Created by Stéphane Peter on 5/30/14.
//  Copyright (c) 2014 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBUtility.h"

@interface CLSFBAppDelegate : UIResponder <UIApplicationDelegate, CLSFBUtilityDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CLSFBUtility *fbutil;

@end
