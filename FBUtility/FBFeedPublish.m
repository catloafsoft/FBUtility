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
                 imagePath:(NSString *)path // Path to a local image file (or nil)
                  imageURL:(NSString *)imgURL // URL to an image file online (or nil)
                 imageLink:(NSString *)imgLink // The link the image will point to
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
        _imgPath = [path copy];
        _imgURL = [imgURL copy];
        _imgLink = [imgLink copy];
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
    
    FBLinkShareParams *params = [[FBLinkShareParams alloc] init];
    params.link = [NSURL URLWithString:_appURL];
    if ([FBDialogs canPresentShareDialogWithParams:params]) {
        [FBDialogs presentShareDialogWithLink:params.link
                                         name:_name
                                      caption:_caption
                                  description:_description
                                      picture:[NSURL URLWithString:_imgURL]
                                  clientState:nil
                                      handler:^(FBAppCall *call, NSDictionary *results, NSError *error) {
                                          if (error) {
                                              if ([FBErrorUtility shouldNotifyUserForError:error]) {
                                                  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                                                                                  message:[FBErrorUtility userMessageForError:error]
                                                                                                 delegate:nil
                                                                                        cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                                                                                        otherButtonTitles:nil];
                                                  [alert show];
                                              }
                                              NSLog(@"FBDialogs share dialog error: %@", error);
                                          }
                                      }];
        return;
    }
    
    // Fall back to native dialogs, or web dialogs
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
                                                                              if ([FBErrorUtility shouldNotifyUserForError:error]) {
                                                                                  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                                                                                                                  message:[FBErrorUtility userMessageForError:error]
                                                                                                                                 delegate:nil
                                                                                                                        cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                                                                                                                        otherButtonTitles:nil];
                                                                                  [alert show];
                                                                              } else if ([FBErrorUtility errorCategoryForError:error] != FBErrorCategoryUserCancelled) {
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
                                       _name, @"name",
                                       _caption, @"caption",
                                       _description, @"description",
                                       _imgLink ? _imgLink : _appURL, @"link",
                                       nil];
        if (_imgURL) {
            params[@"picture"] = _imgURL;
        }
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
                                                      if (error) {
                                                          if ([FBErrorUtility shouldNotifyUserForError:error]) {
                                                              [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Facebook Error",@"Alert title")
                                                                                                              message:[FBErrorUtility userMessageForError:error]
                                                                                                             delegate:nil
                                                                                                    cancelButtonTitle:NSLocalizedString(@"OK",@"Alert button")
                                                                                                    otherButtonTitles:nil] show];
                                                          } else if ([FBErrorUtility errorCategoryForError:error] != FBErrorCategoryUserCancelled) {
                                                              NSLog(@"Feed Dialog Error: %@", error);
                                                          }
                                                      } else {
                                                          if (result == FBWebDialogResultDialogCompleted) {
                                                              NSDictionary *urlParams = [CLSFBUtility parseURLParams:[resultURL query]];
                                                              if ([urlParams valueForKey:@"post_id"]) {
                                                                  if ([_facebookUtil.delegate respondsToSelector:@selector(publishedToFeed:)])
                                                                      [_facebookUtil.delegate publishedToFeed:urlParams[@"post_id"]];
                                                              }
                                                          }
                                                      }
                                                  }];
    }
}

@end
