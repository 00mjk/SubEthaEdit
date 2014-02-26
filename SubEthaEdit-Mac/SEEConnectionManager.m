//
//  SEEConnectionManager.m
//  SubEthaEdit
//
//  Original (ConnectionBrowserController.h) by Martin Ott on Wed Mar 03 2004.
//	Updated by Michael Ehrmann on Fri Feb 21 2014.
//  Copyright (c) 2004-2014 TheCodingMonkeys. All rights reserved.
//

#import "TCMMillionMonkeys/TCMMillionMonkeys.h"
#import "SEEConnectionManager.h"
#import "TCMHost.h"
#import "TCMBEEP.h"
#import "TCMFoundation.h"
#import "SEEConnection.h"
#import <TCMPortMapper/TCMPortMapper.h>

@implementation SEEConnectionManager

+ (SEEConnectionManager *)sharedInstance {
	static SEEConnectionManager *sSharedInstance = nil;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		sSharedInstance = [[[self class] alloc] init];
	});
    return sSharedInstance;
}

- (id)init {
	self = [super init];
    if (self) {
		self.entries = [NSMutableArray new];

		NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];

		TCMMMBEEPSessionManager *manager = [TCMMMBEEPSessionManager sharedInstance];
        [defaultCenter addObserver:self selector:@selector(TCM_didAcceptSession:) name:TCMMMBEEPSessionManagerDidAcceptSessionNotification object:manager];
        [defaultCenter addObserver:self selector:@selector(TCM_sessionDidEnd:) name:TCMMMBEEPSessionManagerSessionDidEndNotification object:manager];

		TCMMMPresenceManager *presenceManager = [TCMMMPresenceManager sharedInstance];
		[defaultCenter addObserver:self selector:@selector(userDidChangeVisibility:) name:TCMMMPresenceManagerUserVisibilityDidChangeNotification object:presenceManager];
        [defaultCenter addObserver:self selector:@selector(userDidChangeAnnouncedDocuments:) name:TCMMMPresenceManagerUserSessionsDidChangeNotification object:presenceManager];
		[defaultCenter addObserver:self selector:@selector(announcedSessionsDidChange:) name:TCMMMPresenceManagerAnnouncedSessionsDidChangeNotification object:presenceManager];
		[defaultCenter addObserver:self selector:@selector(announcedSessionsDidChange:) name:TCMMMPresenceManagerServiceAnnouncementDidChangeNotification object:presenceManager];

        [defaultCenter addObserver:self selector:@selector(connectionEntryDidChange:) name:SEEConnectionStatusDidChangeNotification object:nil];
        [defaultCenter addObserver:self selector:@selector(connectionEntryDidChange:) name:TCMBEEPSessionAuthenticationInformationDidChangeNotification object:nil];

		// not sure if needed
		[defaultCenter addObserver:self selector:@selector(userDidChange:) name:TCMMMUserManagerUserDidChangeNotification object:nil];
	}
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

	self.entries = nil;

	[super dealloc];
}

- (NSURL*)applicationConnectionURL {
    TCMPortMapper *pm = [TCMPortMapper sharedInstance];
    NSString *URLString = [NSString stringWithFormat:@"see://%@:%d", [pm localIPAddress],[[TCMMMBEEPSessionManager sharedInstance] listeningPort]];
    TCMPortMapping *mapping = [[pm portMappings] anyObject];
    if ([mapping mappingStatus]==TCMPortMappingStatusMapped) {
        URLString = [NSString stringWithFormat:@"see://%@:%d", [pm externalIPAddress],[mapping externalPort]];
    }
    return [NSURL URLWithString:URLString];
}


#pragma mark -
#pragma mark ### connection actions ###

- (void)connectToAddress:(NSString *)address {
    DEBUGLOG(@"InternetLogDomain", DetailedLogLevel, @"connect to address: %@", address);
    
    NSURL *url = [TCMMMBEEPSessionManager urlForAddress:address];
    
    DEBUGLOG(@"InternetLogDomain", DetailedLogLevel, @"scheme: %@\nhost: %@\nport: %@\npath: %@\nparameterString: %@\nquery: %@", [url scheme], [url host],  [url port], [url path], [url parameterString], [url query]);
    
    if (url != nil && [url host] != nil) {
        [self connectToURL:url];
    } else {
        DEBUGLOG(@"InternetLogDomain", SimpleLogLevel, @"Entered invalid URI");
        NSBeep();
    }
}

- (SEEConnection *)connectionEntryForURL:(NSURL *)anURL {
	[self willChangeValueForKey:@"entries"];
	SEEConnection *entry = nil;
    for (entry in self.entries) {
        if ([entry handleURL:anURL]) {
            return entry;
        }
    }

    entry = [[[SEEConnection alloc] initWithURL:anURL] autorelease];
	[self.entries addObject:entry];
	[self didChangeValueForKey:@"entries"];
    return entry;
}

- (void)connectToURL:(NSURL *)anURL {
    DEBUGLOG(@"InternetLogDomain", DetailedLogLevel, @"Connect to URL: %@", [anURL description]);
    NSParameterAssert(anURL != nil && [anURL host] != nil);
    
    SEEConnection *entry = [self connectionEntryForURL:anURL];
    [entry connect];
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    DEBUGLOG(@"InternetLogDomain", SimpleLogLevel, @"alertDidEnd:");
    
    NSDictionary *alertContext = (NSDictionary *)contextInfo;
    if (returnCode == NSAlertFirstButtonReturn) {
        DEBUGLOG(@"InternetLogDomain", SimpleLogLevel, @"abort connection");
        NSSet *set = [alertContext objectForKey:@"items"];
        SEEConnection *entry=nil;
        for (entry in set) {
            [entry cancel];
        }
    }
    
    [alertContext autorelease];
}

- (NSArray *)clearableEntries {
    return [self.entries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"connectionStatus = %@",ConnectionStatusNoConnection]];
}

#pragma mark -
#pragma mark ### Entry lifetime management ###

- (void)TCM_didAcceptSession:(NSNotification *)notification {
    DEBUGLOG(@"InternetLogDomain", DetailedLogLevel, @"TCM_didAcceptSession: %@", notification);

	[self willChangeValueForKey:@"entries"];
	{
		TCMBEEPSession *session = [[notification userInfo] objectForKey:@"Session"];
		BOOL sessionWasHandled = NO;
		for (SEEConnection *entry in self.entries) {
			if ([entry handleSession:session]) {
				sessionWasHandled = YES;
				break;
			}
		}
		if (!sessionWasHandled) {
			SEEConnection *entry = [[[SEEConnection alloc] initWithBEEPSession:session] autorelease];
			[self.entries addObject:entry];
		}
	}
	[self didChangeValueForKey:@"entries"];
}

- (void)TCM_sessionDidEnd:(NSNotification *)notification {
    DEBUGLOG(@"InternetLogDomain", DetailedLogLevel, @"TCM_sessionDidEnd: %@", notification);

	[self willChangeValueForKey:@"entries"];
	{
		TCMBEEPSession *session = [[notification userInfo] objectForKey:@"Session"];
		SEEConnection *concernedEntry = nil;
		for (SEEConnection *entry in self.entries) {
			if ([entry BEEPSession] == session) {
				concernedEntry = entry;
				break;
			}
		}
		if (concernedEntry) {
			if (![concernedEntry handleSessionDidEnd:session]) {
				[self.entries removeObject:concernedEntry];
			}
		}
	}
	[self didChangeValueForKey:@"entries"];
}


#pragma mark -
#pragma mark ### update notification handling ###

- (void)userDidChange:(NSNotification *)aNotification {
    DEBUGLOG(@"InternetLogDomain", AllLogLevel, @"userDidChange: %@", aNotification);

	[self willChangeValueForKey:@"entries"];
	[self didChangeValueForKey:@"entries"];
}

- (void)announcedSessionsDidChange:(NSNotification *)aNotification {
    DEBUGLOG(@"InternetLogDomain", AllLogLevel, @"announcedSessionsDidChange: %@", aNotification);

	[self willChangeValueForKey:@"entries"];
	[self didChangeValueForKey:@"entries"];
}

#pragma mark -

- (void)userDidChangeVisibility:(NSNotification *)aNotification {
    DEBUGLOG(@"InternetLogDomain", AllLogLevel, @"userDidChangeVisibility: %@", aNotification);

	[self willChangeValueForKey:@"entries"];
	[self didChangeValueForKey:@"entries"];
}

- (void)userDidChangeAnnouncedDocuments:(NSNotification *)aNotification {
    DEBUGLOG(@"InternetLogDomain", AllLogLevel, @"userDidChangeAnnouncedDocuments: %@", aNotification);

	[self willChangeValueForKey:@"entries"];
	{
		NSArray *entries = [[self.entries copy] autorelease];
		[entries makeObjectsPerformSelector:@selector(reloadAnnouncedSessions)];
		[entries makeObjectsPerformSelector:@selector(checkDocumentRequests)];
	}
	[self didChangeValueForKey:@"entries"];

}

#pragma mark -

- (void)connectionEntryDidChange:(NSNotification *)aNotification {
    DEBUGLOG(@"InternetLogDomain", AllLogLevel, @"connectionEntryDidChange: %@", aNotification);

	[self willChangeValueForKey:@"entries"];
	[self didChangeValueForKey:@"entries"];
}

#pragma mark -

+ (NSString *)quoteEscapedStringWithString:(NSString *)aString {
    NSMutableString *string = [[aString mutableCopy] autorelease];
    [string replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange(0,[aString length])];
    return (NSString *)string;
}

+ (void)sendInvitationToServiceWithID:(NSString *)aServiceID buddy:(NSString *)aBuddy url:(NSURL *)anURL {
    // format is service id, id in that service, onlinestatus (0=offline),groupname
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Please join me in SubEthaEdit:\n%@\n\n(You can download SubEthaEdit from http://www.codingmonkeys.de/subethaedit )",@"iChat invitation String with Placeholder for actual URL"),[anURL absoluteString]];
    NSString *applescriptString = [NSString stringWithFormat:@"tell application \"iChat\" to send \"%@\" to buddy id \"%@:%@\"",[self quoteEscapedStringWithString:message],aServiceID,aBuddy];
    NSAppleScript *script = [[[NSAppleScript alloc] initWithSource:applescriptString] autorelease];
    // need to delay the sending so we don't try to send while in the dragging event
    [script performSelector:@selector(executeAndReturnError:) withObject:nil afterDelay:0.1];
}

+ (BOOL)invitePeopleFromPasteboard:(NSPasteboard *)aPasteboard intoDocumentGroupURL:(NSURL *)aURL {
    BOOL success = NO;
    if ([[aPasteboard types] containsObject:@"PresentityNames"] ||
		[[aPasteboard types] containsObject:@"IMHandleNames"]) {
        NSArray *presentityNames=[[aPasteboard types] containsObject:@"PresentityNames"] ? [aPasteboard propertyListForType:@"PresentityNames"] : [aPasteboard propertyListForType:@"IMHandleNames"]; 
        NSUInteger i=0;
        for (i=0;i<[presentityNames count];i+=4) {
            [self sendInvitationToServiceWithID:[presentityNames objectAtIndex:i] buddy:[presentityNames objectAtIndex:i+1] url:aURL];
        }
        success = YES;
    }

    return success;
}

@end

