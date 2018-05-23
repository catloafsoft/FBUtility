//
//  FBFeedPublish.h
//  Hold data for the FB dialog to publish a feed story
//
//  Created by Stéphane Peter on 10/26/11.
//  Copyright (c) 2011-2015 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBUtility.h"

@interface CLSFBFeedPublish : NSObject

/// Whether to included a text version of the properties array with native dialogs; NO by default
@property (nonatomic) BOOL expandProperties;

- (instancetype)initWithFacebookUtil:(CLSFBUtility *)fb
                             caption:(NSString *)caption // Subtitle
                         description:(NSString *)desc // May include HTML
                     textDescription:(NSString *)txt
                                name:(NSString *)name // Title
                          properties:(NSDictionary *)props
                           imagePath:(NSString *)path
                            imageURL:(NSString *)imgURL
                           imageLink:(NSString *)imgLink NS_DESIGNATED_INITIALIZER;

/// Return YES for success
- (BOOL)showDialogFrom:(UIViewController *)vc;

@end
