//
//  DebugUserController.h
//  SubEthaEdit
//
//  Created by Dominik Wagner on Sun Apr 25 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import <AppKit/AppKit.h>


@interface DebugUserController : NSWindowController {
    IBOutlet NSObjectController *O_userManagerController;
    IBOutlet NSArrayController  *O_allUsersController;
}

@end
