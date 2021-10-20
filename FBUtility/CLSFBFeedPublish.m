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
    NSString *_caption, *_description, *_textDesc, *_name, *_imgPath, *_hashtag;
    NSURL *_imgURL, *_contentURL;
    UIImage *_image;
    void (^_completion)(NSDictionary *results);
}

@synthesize expandProperties = _expandProperties;

- (instancetype)initWithFacebookUtil:(CLSFBUtility *)fb
                             caption:(NSString *)caption
                         description:(NSString *)desc
                     textDescription:(NSString *)txt
                                name:(NSString *)name
                          properties:(NSDictionary *)props
                             hashtag:(NSString *)hashtag
                           imagePath:(NSString *)path // Path to a local image file (or nil)
                               image:(UIImage *)image // An image object, assumed user-generated (or nil)
                            imageURL:(NSURL *)imgURL // URL to an image file online (or nil)
                          contentURL:(NSURL *)contentURL // The content we link to - defaults to the App Store URL if nil
{
    self = [super init];
    if (self) {
        _facebookUtil = fb;
        _caption = [caption copy];
        _description = [desc copy];
        _textDesc = [txt copy];
        _name = [name copy];
        _hashtag = [hashtag copy];
        _properties = props;
        _image = [image copy];
        _imgPath = [path copy];
        _imgURL = [imgURL copy];
        _contentURL = contentURL ? [contentURL copy] : _facebookUtil.appStoreURL;
    }
    return self;
}

- (instancetype)init {
    NSAssert(0, @"Call initWithFacebookUtil:... instead.");
    return [self initWithFacebookUtil:nil caption:nil description:nil textDescription:nil name:nil
                           properties:nil hashtag:nil imagePath:nil image:nil imageURL:nil contentURL:nil];
}

- (BOOL)showDialogFrom:(UIViewController *)vc then:(void (^)(NSDictionary *))completion
{
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
    FBSDKShareDialog *dialog = [[FBSDKShareDialog alloc] initWithViewController:vc
                                                                        content:nil delegate:self];
    if (_image) {
        FBSDKSharePhotoContent *photo = [[FBSDKSharePhotoContent alloc] init];
        photo.photos = @[ [FBSDKSharePhoto photoWithImage:_image userGenerated:YES] ];
        photo.contentURL = _contentURL;
        dialog.shareContent = photo;
        if (![dialog validateWithError:nil] || ![dialog canShow]) {
            NSLog(@"Unable to show dialog for sharing image object.");
            return NO;
        }
    } else if (_imgPath) {
        FBSDKSharePhotoContent *photo = [[FBSDKSharePhotoContent alloc] init];
        photo.photos = @[ [FBSDKSharePhoto photoWithImage:[UIImage imageNamed:_imgPath] userGenerated:YES] ];
        photo.contentURL = _contentURL;
        dialog.shareContent = photo;
        if (![dialog validateWithError:nil] || ![dialog canShow]) {
            NSLog(@"Unable to show dialog for sharing image file.");
            return NO;
        }
    } else if (_imgURL) {
        FBSDKSharePhotoContent *photo = [[FBSDKSharePhotoContent alloc] init];
        photo.photos = @[ [FBSDKSharePhoto photoWithImageURL:_imgURL userGenerated:NO] ];
        photo.contentURL = _contentURL;
        dialog.shareContent = photo;
        if (![dialog validateWithError:nil] || ![dialog canShow]) {
            FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
            content.contentURL = _contentURL;
            dialog.shareContent = content;
        }
    } else {
        FBSDKShareLinkContent *content = [[FBSDKShareLinkContent alloc] init];
        content.contentURL = _contentURL;
        dialog.shareContent = content;
    }
    if (completion)
        _completion = completion;
    if (_hashtag)
        dialog.shareContent.hashtag = [FBSDKHashtag hashtagWithString:[@"#" stringByAppendingString:_hashtag]];
    [dialog show];
    return YES;
}

#pragma mark - FBSDKSharing protocol

- (void)sharer:(id<FBSDKSharing>)sharer didCompleteWithResults:(NSDictionary *)results
{
#ifdef DEBUG
    NSLog(@"Share dialog succeeded with results: %@", results);
#endif
    if (_completion) {
        _completion(results);
        _completion = nil;
    }
}

- (void)sharer:(id<FBSDKSharing>)sharer didFailWithError:(NSError *)error
{
    NSLog(@"Sharing dialog failed: %@", error);
    _completion = nil;
}

- (void)sharerDidCancel:(id<FBSDKSharing>)sharer
{
    _completion = nil;
}


@end
