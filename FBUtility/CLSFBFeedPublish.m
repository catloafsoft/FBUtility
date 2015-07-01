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

#import "CLSFBFeedPublish.h"

@interface CLSFBFeedPublish () <FBSDKSharingDelegate>

@end

@implementation CLSFBFeedPublish {
    CLSFBUtility *_facebookUtil;
    NSDictionary *_properties;
    NSString *_caption, *_description, *_textDesc, *_name, *_imgURL, *_imgLink, *_imgPath;
}

@synthesize expandProperties = _expandProperties;

- (instancetype)initWithFacebookUtil:(CLSFBUtility *)fb
                             caption:(NSString *)caption
                         description:(NSString *)desc
                     textDescription:(NSString *)txt
                                name:(NSString *)name
                          properties:(NSDictionary *)props
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
        _imgPath = [path copy];
        _imgURL = [imgURL copy];
        _imgLink = [imgLink copy];
    }
    return self;
}

- (instancetype)init {
    NSAssert(0, @"Call initWithFacebookUtil:... instead.");
    return [self initWithFacebookUtil:nil caption:nil description:nil textDescription:nil name:nil properties:nil imagePath:nil imageURL:nil imageLink:nil];
}

- (BOOL)showDialogFrom:(UIViewController *)vc {
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
    
    // Build Open Graph object with properties
    FBSDKShareDialog *dialog = [[FBSDKShareDialog alloc] init];
    dialog.fromViewController = vc;
    dialog.delegate = self;
    
    if (_imgPath) {
        FBSDKSharePhotoContent *photo = [[FBSDKSharePhotoContent alloc] init];
        photo.photos = @[ [FBSDKSharePhoto photoWithImage:[UIImage imageNamed:_imgPath] userGenerated:YES] ];
        dialog.shareContent = photo;
        if ([dialog validateWithError:nil] && [dialog canShow]) {
            [dialog show];
        } else {
            NSLog(@"Unable to show dialog for sharing image file.");
            return NO;
        }
    } else if (_imgURL) {
        FBSDKSharePhotoContent *photo = [[FBSDKSharePhotoContent alloc] init];
        photo.photos = @[ [FBSDKSharePhoto photoWithImageURL:[NSURL URLWithString:_imgURL] userGenerated:NO] ];
        dialog.shareContent = photo;
        if ([dialog validateWithError:nil] && [dialog canShow]) {
            [dialog show];
        } else { // Build a link share instead
            FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
            content.imageURL = [NSURL URLWithString:_imgURL];
            content.contentTitle = _caption;
            dialog.shareContent = content;
            [dialog show];
        }
    } else {
        FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
        content.contentURL = [NSURL URLWithString:_facebookUtil.appStoreURL];
        content.imageURL = [NSURL URLWithString:_imgURL]; // hum?
        content.contentDescription = nativeDesc; // or _description?
        content.contentTitle = _caption; // or name?
        dialog.shareContent = content;
        [dialog show];
    }
    return YES;
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
