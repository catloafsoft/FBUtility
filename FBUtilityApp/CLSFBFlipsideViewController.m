//
//  CLSFBFlipsideViewController.m
//  FBUtilityApp
//
//  Created by Stéphane Peter on 5/30/14.
//  Copyright (c) 2014 Catloaf Software, LLC. All rights reserved.
//

#import "CLSFBUtility.h"
#import "CLSFBAppDelegate.h"
#import "CLSFBFlipsideViewController.h"

@interface CLSFBFlipsideViewController ()
@property (weak,nonatomic) CLSFBUtility *fbutil;
@end

@implementation CLSFBFlipsideViewController

- (void)awakeFromNib
{
    self.preferredContentSize = CGSizeMake(320.0, 480.0);
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    CLSFBAppDelegate *delegate = (CLSFBAppDelegate *)[UIApplication sharedApplication].delegate;
    self.fbutil = delegate.fbutil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions

- (IBAction)done:(id)sender
{
    [self.delegate flipsideViewControllerDidFinish:self];
}

- (IBAction)getAchievements:(id)sender
{
    [self.fbutil fetchAchievementsAndThen:^(NSSet *achievements) {
        NSLog(@"Fetched %@ achievements: %@", @(achievements.count), achievements);
    }];
}

- (IBAction)postAchievement:(id)sender
{
    [self.fbutil publishAchievement:@"http://www.catloafsoft.com/og/fbutil/achievement.html"];
}

- (IBAction)removeAchievement:(id)sender
{
    [self.fbutil removeAchievement:@"http://www.catloafsoft.com/og/fbutil/achievement.html"];
}

- (IBAction)removeAllAchievements:(id)sender
{
    [self.fbutil removeAllAchievements];
}

- (IBAction)postScore:(id)sender
{
    // Post the score currently in the field
    NSUInteger score = (self.scoreField.text).integerValue;
    [self.fbutil publishScore:score];
}

@end
