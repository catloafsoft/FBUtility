//
//  CLSFBFlipsideViewController.h
//  FBUtilityApp
//
//  Created by Stéphane Peter on 5/30/14.
//  Copyright (c) 2014 Catloaf Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CLSFBFlipsideViewController;

@protocol CLSFBFlipsideViewControllerDelegate
- (void)flipsideViewControllerDidFinish:(CLSFBFlipsideViewController *)controller;
@end

@interface CLSFBFlipsideViewController : UIViewController

@property (weak, nonatomic) id <CLSFBFlipsideViewControllerDelegate> delegate;

- (IBAction)done:(id)sender;

@end
