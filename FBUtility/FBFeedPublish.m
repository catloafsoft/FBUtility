//
//  FBFeedPublish.m
//  Hold data for the FB dialog to publish a feed story
//
//  Created by Stéphane Peter on 10/26/11.
//
//  Copyright (c) 2013 Catloaf Software, LLC. All rights reserved.
//

#import "FBFeedPublish.h"

@implementation FBFeedPublish {
    CLSFBUtility *_facebookUtil;
    NSDictionary *_properties;
    NSString *_caption, *_description, *_textDesc, *_name, *_appURL, *_imgURL, *_imgLink, *_imgPath;
}

@synthesize expandProperties = _expandProperties;

- (id)initWithFacebookUtil:(CLSFBUtility *)fb
                   caption:(NSString *)caption 
               description:(NSString *)desc
           textDescription:(NSString *)txt
                      name:(NSString *)name
                properties:(NSDictionary *)props
                    appURL:(NSString *)appURL
                 imagePath:(NSString *)path
                  imageURL:(NSString *)img
                 imageLink:(NSString *)imgURL
{
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _caption = [caption copy];
        _description = [desc copy];
        _textDesc = [txt copy];
        _name = [name copy];
        _properties = props;
        _appURL = [appURL copy];
        _imgURL = [img copy];
        _imgLink = [imgURL copy];
        _imgPath = [path copy];
    }
    return self;
}

- (void)showDialogFrom:(UIViewController *)vc {
    // First try to set up a native dialog - we can't use the properties so make them part of the description.
    NSMutableString *nativeDesc = [NSMutableString stringWithFormat:@"%@\n",_textDesc];
    if (self.expandProperties) {
        for (NSString *key in _properties) {
            id value = [_properties objectForKey:key];
            if ([value isKindOfClass:[NSDictionary class]]) {
                value = [value objectForKey:@"text"];
            }
            if (value)
                [nativeDesc appendString:[NSString stringWithFormat:@"%@: %@\n",key,value]];
        }
    }
    BOOL nativeSuccess = [FBDialogs presentOSIntegratedShareDialogModallyFrom:vc
                                                                  initialText:nativeDesc
                                                                        image:(_imgPath ? [UIImage imageNamed:_imgPath] : nil)
                                                                          url:[NSURL URLWithString:_appURL]
                                                                      handler:^(FBOSIntegratedShareDialogResult result, NSError *error) {
                                                                          // Only show the error if it is not due to the dialog
                                                                          // not being supported, i.e. code = 7, otherwise ignore
                                                                          // because our fallback will show the share view controller.
                                                                          if (error && [error code] == 7) {
                                                                              return;
                                                                          }
                                                                          
                                                                          if (error) {
                                                                              if (error.fberrorShouldNotifyUser) {
                                                                                  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                                                                                                                  message:error.fberrorUserMessage
                                                                                                                                 delegate:nil
                                                                                                                        cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                                                                                                                        otherButtonTitles:nil];
                                                                                  [alert show];
                                                                              } else if (error.fberrorCategory != FBErrorCategoryUserCancelled) {
                                                                                  NSLog(@"Native Feed Dialog Error: %@", error);
                                                                              }
                                                                          }
                                                                          
                                                                      }];

    if (!nativeSuccess) {
        NSError *error = nil;

        //  Send a post to the feed for the user with the Graph API
        NSArray *actionLinks = @[@{ @"name": @"Get The App!",
                                    @"link": _appURL}];
        NSData *actionData = [NSJSONSerialization dataWithJSONObject:actionLinks
                                                             options:0
                                                               error:&error];
        NSString *actionJSON = [[NSString alloc] initWithData:actionData encoding:NSUTF8StringEncoding];
        NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                       NSLocalizedString(@"Care to comment?", @"Facebook user message prompt"), @"message",
                                       actionJSON, @"actions",
                                       _imgURL, @"picture",
                                       _name, @"name",
                                       _caption, @"caption",
                                       _description, @"description",
                                       _imgLink ? _imgLink : _appURL, @"link",
                                       nil];
        if (_properties) { // Does this even work anymore?
            NSData *json = [NSJSONSerialization dataWithJSONObject:_properties
                                                           options:0
                                                             error:&error];
            if (json) {
                params[@"properties"] = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
            } else{
                NSLog(@"Error enconding JSON properties: %@ (%@)", _properties, error);
            }
        }
        
        //NSLog(@"Story params: %@", [jsonWriter stringWithObject:params]);
        [FBWebDialogs presentFeedDialogModallyWithSession:nil
                                               parameters:params
                                                  handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
                                                      if (result == FBWebDialogResultDialogCompleted) {
                                                          NSRange err = [resultURL.query rangeOfString:@"error_code"];
                                                          if (err.location == NSNotFound &&
                                                              [_facebookUtil.delegate respondsToSelector:@selector(publishedToFeed)])
                                                              [_facebookUtil.delegate publishedToFeed];
                                                      }
                                                      if (error) {
                                                          if (error.fberrorShouldNotifyUser) {
                                                              [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                                                                                              message:error.fberrorUserMessage
                                                                                                             delegate:nil
                                                                                                    cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                                                                                                    otherButtonTitles:nil] show];
                                                          } else if (error.fberrorCategory != FBErrorCategoryUserCancelled) {
                                                              NSLog(@"Feed Dialog Error: %@", error);
                                                          }
                                                      }
                                                  }];
    }
}

@end
