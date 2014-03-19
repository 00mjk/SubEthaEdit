//
//  WebPreviewViewController.h
//  was : WebPreviewWindowController.h
//  SubEthaEdit
//
//  Created by Dominik Wagner on Mon Jul 07 2003.
//  Copyright (c) 2003 TheCodingMonkeys. All rights reserved.
//  refactored to be a ViewController by liz

#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

@class PlainTextDocument;

typedef NS_ENUM(int8_t, SEEWebPreviewRefreshType) {
	kWebPreviewRefreshAutomatic = 1,
	kWebPreviewRefreshOnSave    = 2,
	kWebPreviewRefreshManually  = 3,
	kWebPreviewRefreshDelayed   = 4
};

@interface WebPreviewViewController : NSViewController

- (id)initWithPlainTextDocument:(PlainTextDocument *)aDocument;

- (void)setPlainTextDocument:(PlainTextDocument *)aDocument;
- (PlainTextDocument *)plainTextDocument;

- (SEEWebPreviewRefreshType)refreshType;
- (void)setRefreshType:(SEEWebPreviewRefreshType)aRefreshType;

- (void)updateBaseURL;

- (NSURL *)baseURL;
- (void)setBaseURL:(NSURL *)aBaseURL;

-(IBAction)refreshAndEmptyCache:(id)aSender;
-(IBAction)refresh:(id)aSender;
-(IBAction)changeRefreshType:(id)aSender;

@end
