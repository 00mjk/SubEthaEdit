//
//  SEEStyleSheetSettings.m
//  SubEthaEdit
//
//  Created by dom on 24.03.11.
//  Copyright 2011 TheCodingMonkeys. All rights reserved.
//

// helper class to manage style sheet preferences for a mode
// internal defaults structure
// "StyleSheets" => {"single" => SingleStyleSheetName, "multiple" => {<context> => <stylesheetname>}, "usesMultipleStyle" => BOOL}

NSString * const SEEStyleSheetSettingsSingleStyleSheetKey        = @"single";
NSString * const SEEStyleSheetSettingsMultipleStyleSheetsKey     = @"multiple";
NSString * const SEEStyleSheetSettingsUsesMultipleStyleSheetsKey = @"usesMultiple";


#import "SEEStyleSheetSettings.h"
#import "DocumentModeManager.h"

@implementation SEEStyleSheetSettings

@synthesize usesMultipleStyleSheets = I_usesMultipleStyleSheets;
@synthesize documentMode = I_documentMode;
@synthesize singleStyleSheetName = I_singleStyleSheetName;

- (void)takeSettingsFromModeDefaults {
	NSDictionary *sheetPrefsDict = [self.documentMode defaultForKey:DocumentModeStyleSheetsPreferenceKey];
	self.usesMultipleStyleSheets = [[sheetPrefsDict objectForKey:SEEStyleSheetSettingsUsesMultipleStyleSheetsKey] boolValue];
	NSString *value = [sheetPrefsDict objectForKey:SEEStyleSheetSettingsSingleStyleSheetKey];
	if (value) self.singleStyleSheetName = value;
	NSDictionary *sheetMapping = [sheetPrefsDict objectForKey:SEEStyleSheetSettingsMultipleStyleSheetsKey];
	if (sheetMapping && [sheetMapping isKindOfClass:[NSDictionary class]]) {
		[I_styleSheetNamesByLanguageContext removeAllObjects];
		[I_styleSheetNamesByLanguageContext addEntriesFromDictionary:sheetMapping];
	}
}

- (void)pushSettingsToModeDefaults {
	NSMutableDictionary *result = [NSMutableDictionary new];
	if (self.singleStyleSheetName) [result setObject:self.singleStyleSheetName forKey:SEEStyleSheetSettingsSingleStyleSheetKey];
	[result setObject:[[I_styleSheetNamesByLanguageContext copy] autorelease] forKey:SEEStyleSheetSettingsMultipleStyleSheetsKey];
	[result setObject:[NSNumber numberWithBool:self.usesMultipleStyleSheets] forKey:SEEStyleSheetSettingsUsesMultipleStyleSheetsKey];
	[[self.documentMode defaults] setObject:result forKey:DocumentModeStyleSheetsPreferenceKey];
}

- (id)initWithDocumentMode:(DocumentMode *)aMode {
	if ((self=[super init])) {
		I_styleSheetNamesByLanguageContext = [NSMutableDictionary new];
		self.documentMode = aMode;
		self.singleStyleSheetName = [DocumentModeManager defaultStyleSheetName]; // default
		[self takeSettingsFromModeDefaults];
	}
	return self;
}

- (void)dealloc {
	[I_singleStyleSheetName release];
	[I_styleSheetNamesByLanguageContext release];
	[super dealloc];
}

- (SEEStyleSheet *)styleSheetForLanguageContext:(NSString *)aLanguageContext {
	DocumentModeManager *modeManager = [DocumentModeManager sharedInstance];
	SEEStyleSheet *result = nil;
	if (I_usesMultipleStyleSheets) {
		NSString *sheetName = [I_styleSheetNamesByLanguageContext objectForKey:aLanguageContext];
		if (sheetName) {
			result = [modeManager styleSheetForName:sheetName];
		}
	}
	
	if (!I_usesMultipleStyleSheets || !result) {
		result = [modeManager styleSheetForName:self.singleStyleSheetName];
	}
	return result;
}

- (void)setStyleSheetName:(NSString *)aStyleSheetName forLanguageContext:(NSString *)aLanguageContext {
	[I_styleSheetNamesByLanguageContext setObject:aStyleSheetName forKey:aLanguageContext];
}

- (NSString *)styleSheetNameForLanguageContext:(NSString *)aLanguageContext {
	NSString *styleSheetName = [I_styleSheetNamesByLanguageContext objectForKey:aLanguageContext];
	if (!styleSheetName) styleSheetName = self.singleStyleSheetName;
	return styleSheetName;
}

@end
