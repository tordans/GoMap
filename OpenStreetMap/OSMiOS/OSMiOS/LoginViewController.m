//
//  LoginViewController.m
//  OSMiOS
//
//  Created by Bryce Cogswell on 12/19/12.
//  Copyright (c) 2012 Bryce Cogswell. All rights reserved.
//

#import "AppDelegate.h"
#import "EditorMapLayer.h"
#import "LoginViewController.h"
#import "MapView.h"
#import "OsmMapData.h"
#import "UITableViewCell+FixConstraints.h"

@implementation LoginViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (IBAction)textFieldReturn:(id)sender
{
	[sender resignFirstResponder];
}

- (IBAction)textFieldDidChange:(id)sender
{
	_verifyButton.enabled = _username.text.length && _password.text.length;
}

- (IBAction)registerAccount:(id)sender
{
	[[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"https://www.openstreetmap.org/user/new"]];
}


- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
	[self.navigationController popToRootViewControllerAnimated:YES];
}


- (IBAction)verifyAccount:(id)sender
{
	AppDelegate * appDelegate = (id)[[UIApplication sharedApplication] delegate];
	appDelegate.userName		= _username.text;
	appDelegate.userPassword	= _password.text;

	_activityIndicator.color = UIColor.darkGrayColor;
	[_activityIndicator startAnimating];

	[appDelegate.mapView.editorLayer.mapData verifyUserCredentialsWithCompletion:^(NSString * errorMessage){
		[_activityIndicator stopAnimating];
		if ( errorMessage ) {
			UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"Bad login" message:errorMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alertView show];
		} else {
			[_username resignFirstResponder];
			[_password resignFirstResponder];
			UIAlertView * alertView = [[UIAlertView alloc] initWithTitle:@"Login successful" message:nil delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			alertView.delegate = self;
			[alertView show];
		}
	}];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	AppDelegate * appDelegate = (id)[[UIApplication sharedApplication] delegate];
	_username.text	= appDelegate.userName;
	_password.text	= appDelegate.userPassword;

	_verifyButton.enabled = _username.text.length && _password.text.length;
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];

	if ( [self isMovingFromParentViewController] ) {
		AppDelegate * appDelegate = (id)[[UIApplication sharedApplication] delegate];
		appDelegate.userName		= _username.text;
		appDelegate.userPassword	= _password.text;

		[[NSUserDefaults standardUserDefaults] setObject:appDelegate.userName		forKey:@"username"];
		[[NSUserDefaults standardUserDefaults] setObject:appDelegate.userPassword	forKey:@"password"];
	}
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	[cell fixConstraints];
}

#pragma mark - Table view delegate

@end