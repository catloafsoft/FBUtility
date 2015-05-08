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

NS_ASSUME_NONNULL_BEGIN
@interface FBShareApp : NSObject

- (instancetype)initWithFacebookUtil:(CLSFBUtility *)fb message:(NSString *)msg NS_DESIGNATED_INITIALIZER;

- (void)presentFromViewController:(UIViewController *)controller;

/// The URL to an image to preview the app (Facebook recommended size of 1200x628, aspect ratio 1.9:1)
@property (nonatomic,copy,nullable) NSURL *previewImageURL;

@end
NS_ASSUME_NONNULL_END
