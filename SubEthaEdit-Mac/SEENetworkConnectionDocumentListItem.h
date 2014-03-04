//
//  SEENetworkConnectionRepresentation.h
//  SubEthaEdit
//
//  Created by Michael Ehrmann on 26.02.14.
//  Copyright (c) 2014 TheCodingMonkeys. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SEEDocumentListItemProtocol.h"

@class SEEConnection, TCMMMUser;

@interface SEENetworkConnectionDocumentListItem : NSObject <SEEDocumentListItem>
@property (nonatomic, readonly, assign) BOOL showsDisconnect;
@property (nonatomic, strong) SEEConnection *connection; // also overrides user
@property (nonatomic, strong) TCMMMUser *user;
@end
