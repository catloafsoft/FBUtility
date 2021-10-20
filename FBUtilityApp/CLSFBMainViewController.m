//
//  CLSFBMainViewController.m
//  FBUtilityApp
//
//  Created by Stéphane Peter on 5/30/14.
//  Copyright (c) 2014 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBMainViewController.h"
#import "CLSFBAppDelegate.h"
#import "CLSFBUtility.h"

@interface CLSFBMainViewController ()
@property (weak,nonatomic) CLSFBUtility *fbutil;
@property (copy,nonatomic) NSString *likeId;
@end

@implementation CLSFBMainViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(facebookLoggedOut:)
                                                 name:kFBUtilLoggedOutNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(facebookLoggedIn:)
                                                 name:kFBUtilLoggedInNotification
                                               object:nil];

    // Do any additional setup after loading the view, typically from a nib.
    CLSFBAppDelegate *delegate = (CLSFBAppDelegate *)[UIApplication sharedApplication].delegate;
    self.fbutil = delegate.fbutil;
    self.sdkVersionLabel.text = [NSString stringWithFormat:@"iOS SDK v%@", CLSFBUtility.sdkVersion];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (self.fbutil.loggedIn) {
        [self facebookLoggedIn:nil];
    } else {
        [self facebookLoggedOut:nil];
    }
    [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Flipside View Controller

- (void)flipsideViewControllerDidFinish:(CLSFBFlipsideViewController *)controller
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        [self dismissViewControllerAnimated:YES completion:nil];
    } else {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
    self.flipsidePopoverController = nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"showAlternate"]) {
        CLSFBFlipsideViewController *dest = segue.destinationViewController;
        dest.delegate = self;
        
        if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            UIPopoverController *popoverController = ((UIStoryboardPopoverSegue *)segue).popoverController;
            self.flipsidePopoverController = popoverController;
            popoverController.delegate = self;
        }
    }
}

- (IBAction)togglePopover:(id)sender
{
    if (self.flipsidePopoverController) {
        [self.flipsidePopoverController dismissPopoverAnimated:YES];
        self.flipsidePopoverController = nil;
    } else {
        [self performSegueWithIdentifier:@"showAlternate" sender:sender];
    }
}

- (void) facebookLoggedOut:(NSNotification *)notif
{
    self.userLabel.text = @"Not Logged In";
    self.logoutButton.titleLabel.text = @"Log In";
    self.profileView.hidden = YES;
}

- (void) facebookLoggedIn:(NSNotification *)notif
{
    if (self.fbutil.fullName)
        self.userLabel.text = [NSString stringWithFormat:@"Logged in as %@", self.fbutil.fullName];
    else
        self.userLabel.text = @"User Logged In";
    self.logoutButton.titleLabel.text = @"Log Out";
    [self.profileView addSubview:[self.fbutil profilePictureViewOfSize:self.profileView.bounds.size.width]];
    self.profileView.hidden = NO;
}

#pragma mark - Button handlers

- (IBAction)publishStory:(id)sender
{
    [self.fbutil publishToFeedWithCaption:@"Caption"
                              description:@"<b>Description with HTML</b>"
                          textDescription:@"Text Description"
                                     name:@"Name"
                               properties:@{@"Property 1" : @"Yeah", @"Property 2" : @"No"}
                                  hashtag:@"HashTagThis"
                         expandProperties:YES
                                imagePath:nil
                                    image:nil
                                 imageURL:[NSURL URLWithString:@"http://img.cdn.catloafsoft.com/catloaf-logo.png"]
                               contentURL:[NSURL URLWithString:@"https://www.catloafsoft.com/"]
                                     from:self
                                     then:^(NSDictionary *result) {
                                         NSLog(@"Story published with result: %@", result);
                                     }];
}

- (IBAction)sharePhoto:(id)sender
{
    [self.fbutil publishToFeedWithCaption:@"Photo Caption"
                              description:@"<b>Description with HTML</b>"
                          textDescription:@"Text Description"
                                     name:@"Name"
                               properties:@{@"Property 1" : @"Yeah", @"Property 2" : @"No"}
                                  hashtag:@"HashTagThat"
                         expandProperties:YES
                                imagePath:@"Foof-Halo"
                                    image:nil
                                 imageURL:nil
                               contentURL:[NSURL URLWithString:@"https://www.catloafsoft.com/"]
                                     from:self
                                     then:^(NSDictionary *result) {
                                         NSLog(@"Story published with result: %@", result);
                                     }];
}

- (IBAction)shareApp:(id)sender
{
    [self.fbutil shareAppWithFriendsFrom:self];
}

- (IBAction)logout:(id)sender
{
    if (self.fbutil.loggedIn) {
        [self.fbutil logout];
    } else {
        [self.fbutil login:YES from:nil andThen:nil];
    }
}

@end
