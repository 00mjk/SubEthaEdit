//
//  SEEStyleSheetSettings.h
//  SubEthaEdit
//
//  Created by dom on 24.03.11.
//  Copyright 2011 TheCodingMonkeys. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "DocumentMode.h"
#import "SEEStyleSheet.h"

@class SEEStyleSheet;
@class DocumentMode;

@interface SEEStyleSheetSettings : NSObject {
	BOOL          I_usesMultipleStyleSheets;
	NSMutableDictionary *I_styleSheetNamesByLanguageContext;
	NSString     *I_singleStyleSheetName;
	DocumentMode *I_documentMode;
}

@property          BOOL          usesMultipleStyleSheets;
@property (assign) DocumentMode *documentMode;
@property (copy)   NSString     *singleStyleSheetName;

- (id)initWithDocumentMode:(DocumentMode *)aMode;

- (SEEStyleSheet *)styleSheetForLanguageContext:(NSString *)aLanguageContext;
- (void)setStyleSheetName:(NSString *)aStyleSheetName forLanguageContext:(NSString *)aLanguageContext;
- (NSString *)styleSheetNameForLanguageContext:(NSString *)aLanguageContext;
@end
