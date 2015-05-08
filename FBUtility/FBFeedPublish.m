//
//  FBFeedPublish.m
//  Hold data for the FB share dialog to publish a feed story
//
//  Created by Stéphane Peter on 10/26/11.
//
//  Copyright (c) 2011-2015 Catloaf Software, LLC. All rights reserved.
//

@import FBSDKCoreKit;
@import FBSDKShareKit;

#import "FBFeedPublish.h"

@interface FBFeedPublish () <FBSDKSharingDelegate>

@end

@implementation FBFeedPublish {
    CLSFBUtility *_facebookUtil;
    NSDictionary *_properties;
    NSString *_caption, *_description, *_textDesc, *_name, *_appURL, *_imgURL, *_imgLink, *_imgPath;
}

@synthesize expandProperties = _expandProperties;

- (instancetype)initWithFacebookUtil:(CLSFBUtility *)fb
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
            id value = _properties[key];
            if ([value isKindOfClass:[NSDictionary class]]) {
                value = value[@"text"];
            }
            if (value)
                [nativeDesc appendString:[NSString stringWithFormat:@"%@: %@\n",key,value]];
        }
    }
    
    // FIXME: share photo if path given
    // Build Open Graph object with properties
    if (_imgPath) {
        FBSDKSharePhotoContent *photo = [[FBSDKSharePhotoContent alloc] init];
        photo.photos = @[ [FBSDKSharePhoto photoWithImage:[UIImage imageNamed:_imgPath] userGenerated:YES] ];
        [FBSDKShareDialog showFromViewController:vc
                                     withContent:photo
                                        delegate:self];
    } else if (_imgURL) {
        FBSDKSharePhotoContent *photo = [[FBSDKSharePhotoContent alloc] init];
        photo.photos = @[ [FBSDKSharePhoto photoWithImageURL:[NSURL URLWithString:_imgURL] userGenerated:NO] ];
        [FBSDKShareDialog showFromViewController:vc
                                     withContent:photo
                                        delegate:self];
    } else {
        FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
        content.contentURL = [NSURL URLWithString:_appURL];
        content.imageURL = [NSURL URLWithString:_imgURL]; // hum?
        content.contentDescription = nativeDesc; // or _description?
        content.contentTitle = _caption; // or name?

        [FBSDKShareDialog showFromViewController:vc
                                     withContent:content
                                        delegate:self];
    }
    
}

#pragma mark - FBSDKSharing protocol

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results
{
#ifdef DEBUG
    NSLog(@"Share dialog succeeded with results: %@", results);
#endif
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error
{
    NSLog(@"Sharing dialog failed: %@", error);
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer
{
    
}


@end
