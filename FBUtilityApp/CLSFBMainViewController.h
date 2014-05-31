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

@end
