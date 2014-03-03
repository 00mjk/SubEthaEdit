//
//  SEERecentDocumentListItem.m
//  SubEthaEdit
//
//  Created by Michael Ehrmann on 03.03.14.
//  Copyright (c) 2014 TheCodingMonkeys. All rights reserved.
//

#if !__has_feature(objc_arc)
#error ARC must be enabled!
#endif

#import "SEERecentDocumentListItem.h"

void * const SEERecentDocumentURLObservingContext = (void *)&SEERecentDocumentURLObservingContext;

@implementation SEERecentDocumentListItem

@synthesize name = _name;
@synthesize image = _image;

- (id)init
{
    self = [super init];
    if (self) {
		self.name = NSLocalizedString(@"Unknown Name", @"");
        self.image = [NSImage imageNamed:NSImageNameMultipleDocuments];

		[self installKVO];
    }
    return self;
}

- (void)dealloc
{
	[self removeKVO];
}

- (void)installKVO {
	[self addObserver:self forKeyPath:@"fileURL" options:0 context:SEERecentDocumentURLObservingContext];
}

- (void)removeKVO {
	[self removeObserver:self forKeyPath:@"fileURL" context:SEERecentDocumentURLObservingContext];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == SEERecentDocumentURLObservingContext) {
		self.name = self.fileURL.lastPathComponent;
		[self updateImage];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)updateImage {
	NSString *fileExtension = self.name.pathExtension;
	NSString *fileType = (CFBridgingRelease(UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)fileExtension, nil)));
	NSImage *image = [[NSWorkspace sharedWorkspace] iconForFileType:fileType];
	self.image = image;
}

- (IBAction)itemAction:(id)aSender {
	if (self.fileURL) {
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:self.fileURL display:YES completionHandler:^(NSDocument *document, BOOL documentWasAlreadyOpen, NSError *error) {

		}];
	}
}

@end
