//
//  CLSFBMainViewController.h
//  FBUtilityApp
//
//  Created by Stéphane Peter on 5/30/14.
//  Copyright (c) 2014 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBFlipsideViewController.h"

@interface CLSFBMainViewController : UIViewController <CLSFBFlipsideViewControllerDelegate, UIPopoverControllerDelegate>

@property (strong, nonatomic) UIPopoverController *flipsidePopoverController;
@property (strong, nonatomic) IBOutlet UILabel *sdkVersionLabel, *userLabel;
@property (strong, nonatomic) IBOutlet UIButton *logoutButton;

// Buttons callbacks

- (IBAction)publishStory:(id)sender;
- (IBAction)shareApp:(id)sender;

- (IBAction)like:(id)sender;
- (IBAction)unlike:(id)sender;

- (IBAction)logout:(id)sender;

@end
