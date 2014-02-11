//
//  DocumentModeManager.m
//  SubEthaEdit
//
//  Created by Dominik Wagner on Mon Mar 22 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "ModeSettings.h"
#import "DocumentModeManager.h"
#import "GeneralPreferences.h"
#import "SyntaxStyle.h"
#import "SyntaxDefinition.h"
#import <OgreKit/OgreKit.h>

#define MODEPATHCOMPONENT @"Application Support/SubEthaEditDebug/Modes/"

@interface DocumentModeManager (DocumentModeManagerPrivateAdditions)
- (void)TCM_findModes;
- (void)TCM_findStyles;
- (NSMutableArray *)reloadPrecedences;
- (void)setupMenu:(NSMenu *)aMenu action:(SEL)aSelector alternateDisplay:(BOOL)aFlag;
- (void)setupPopUp:(DocumentModePopUpButton *)aPopUp selectedModeIdentifier:(NSString *)aModeIdentifier automaticMode:(BOOL)hasAutomaticMode;
- (NSMutableArray *)modePrecedenceArray;
- (void)setModePrecedenceArray:(NSMutableArray *)anArray;
- (NSString *)pathForWritingStyleSheetWithName:(NSString *)aStyleSheetName;
@end

#pragma mark
@implementation DocumentModePopUpButton

/* Replace the cell, sign up for notifications.
*/
- (id)initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        I_automaticMode = NO;
    }
    return self;
}

- (void)awakeFromNib {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentModeListChanged:) name:@"DocumentModeListChanged" object:nil];
    [[DocumentModeManager sharedInstance] setupPopUp:self selectedModeIdentifier:BASEMODEIDENTIFIER automaticMode:I_automaticMode];
}

- (void)setHasAutomaticMode:(BOOL)aFlag {
    I_automaticMode = aFlag;
    [self documentModeListChanged:[NSNotification notificationWithName:@"DocumentModeListChanged" object:self]];
}

- (NSString *)selectedModeIdentifier {
    DocumentModeManager *manager=[DocumentModeManager sharedInstance];
    return [manager documentModeIdentifierForTag:[[self selectedItem] tag]];
}

- (void)setSelectedModeIdentifier:(NSString *)aModeIdentifier {
    int tag=[[DocumentModeManager sharedInstance] tagForDocumentModeIdentifier:aModeIdentifier];
    [self selectItemAtIndex:[[self menu] indexOfItemWithTag:tag]];
}

- (DocumentMode *)selectedMode {
    DocumentModeManager *manager=[DocumentModeManager sharedInstance];
    DocumentMode *mode = [manager documentModeForIdentifier:[manager documentModeIdentifierForTag:[[self selectedItem] tag]]];
    if (!mode) {
        mode = [DocumentModeManager baseMode];
        [self setSelectedMode:mode];
    }
    return mode;
}

- (void)setSelectedMode:(DocumentMode *)aMode {
    int tag=[[DocumentModeManager sharedInstance] tagForDocumentModeIdentifier:[[aMode bundle] bundleIdentifier]];
    [self selectItemAtIndex:[[self menu] indexOfItemWithTag:tag]];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

/* Update contents based on encodings list customization
*/
- (void)documentModeListChanged:(NSNotification *)notification {
    NSString *selectedModeIdentifier=[self selectedModeIdentifier];
    if (![[DocumentModeManager sharedInstance] documentModeAvailableModeIdentifier:selectedModeIdentifier]) {
        selectedModeIdentifier=BASEMODEIDENTIFIER;
    }
    [[DocumentModeManager sharedInstance] setupPopUp:self selectedModeIdentifier:selectedModeIdentifier automaticMode:I_automaticMode];
    [self setSelectedModeIdentifier:selectedModeIdentifier];
}

@end

#pragma mark -
@implementation DocumentModeMenu
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

- (void)documentModeListChanged:(NSNotification *)notification {
    [[DocumentModeManager sharedInstance] setupMenu:self action:I_action alternateDisplay:I_alternateDisplay];
}

- (void)configureWithAction:(SEL)aSelector alternateDisplay:(BOOL)aFlag {
    I_action = aSelector;
    I_alternateDisplay = aFlag;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(documentModeListChanged:) name:@"DocumentModeListChanged" object:nil];
    [[DocumentModeManager sharedInstance] setupMenu:self action:I_action alternateDisplay:aFlag];
}

@end

#pragma mark
static DocumentModeManager *S_sharedInstance=nil;

@implementation DocumentModeManager

+ (DocumentModeManager *)sharedInstance {
    if (!S_sharedInstance) {
        S_sharedInstance = [self new];
    }
    return S_sharedInstance;
}

+ (DocumentMode *)baseMode {
    return [[DocumentModeManager sharedInstance] baseMode];
}

+ (NSString *)defaultStyleSheetName {
	return @"Bright Lisa";
}

+ (NSString *)xmlFileRepresentationOfAllStyles {
    DocumentModeManager *modeManager=[DocumentModeManager sharedInstance];
    NSMutableString *result=[NSMutableString string];
    NSDictionary *availableModes=[modeManager availableModes];
    NSEnumerator *identifiers=[[[availableModes allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)] objectEnumerator];
    NSString *identifier=nil;
    while ((identifier=[identifiers nextObject])) {
        DocumentMode *mode=[modeManager documentModeForIdentifier:identifier];
        [result appendString:[[mode syntaxStyle] xmlRepresentation]];
    }
    return [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<seestyle>\n%@</seestyle>\n",result];
}

#pragma mark
- (id)init {
    if (S_sharedInstance) {
        [self dealloc];
        self = S_sharedInstance;
    } else {
        self = [super init];
        if (self) {
            I_modeBundles=[NSMutableDictionary new];
            
            I_styleSheetPathsByName = [NSMutableDictionary new];
            I_styleSheetsByName     = [NSMutableDictionary new];
            
            I_documentModesByIdentifier =[NSMutableDictionary new];
            I_documentModesByName       = [NSMutableDictionary new];
			I_documentModesByIdentifierLock = [NSRecursiveLock new]; // ifc - experimental locking... awaiting real fix from TCM
            I_modeIdentifiersTagArray   =[NSMutableArray new];
            [I_modeIdentifiersTagArray addObject:@"-"];
            [I_modeIdentifiersTagArray addObject:AUTOMATICMODEIDENTIFIER];
            [I_modeIdentifiersTagArray addObject:BASEMODEIDENTIFIER];
            [self TCM_findStyles];
            [self TCM_findModes];
            [self setModePrecedenceArray:[self reloadPrecedences]];
            [self revalidatePrecedences];
            
            // Preference Handling
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
        }
    }
    return self;
}

- (void)dealloc {
    [I_modeBundles release];
    [I_styleSheetPathsByName release];
    [I_styleSheetsByName release];
    [I_documentModesByName release];
    [I_documentModesByIdentifier release];
	[I_documentModesByIdentifierLock release]; // ifc - experimental locking... awaiting real fix from TCM
    [super dealloc];
}

#pragma mark - Directories

#define MODE_EXTENSION @"mode"
#define BUNDLE_MODE_FOLDER_NAME @"Modes"
#define LIBRARY_MODE_FOLDER_NAME @"Modes"

#define BUNDLE_STYLE_FOLDER_NAME @"Modes/Styles/"
#define LIBRARY_STYLE_FOLDER_NAME @"Styles"
- (NSURL *)applicationSupportDirectory {
    NSFileManager *sharedFM = [NSFileManager defaultManager];
    NSArray *possibleURLs = [sharedFM URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask];
    NSURL *appSupportDir = nil;
	
    if ([possibleURLs count] >= 1) {
        // Use the first directory (if multiple are returned)
        appSupportDir = [possibleURLs objectAtIndex:0];
    }
	return appSupportDir;
}

- (NSURL *)URLWithAddedBundleIdentifierDirectoryForURL:(NSURL *)anURL subDirectoryName:(NSString *)aSubDirectory {
	NSURL *url = nil;
    if (anURL) {
        NSString *appBundleID = [[NSBundle mainBundle] bundleIdentifier];
        url = [anURL URLByAppendingPathComponent:appBundleID];
		if (aSubDirectory) {
			url = [url URLByAppendingPathComponent:aSubDirectory];
		}
    }
	return url;
}

- (void)createUserApplicationSupportDirectory {
	NSURL *applicationSupport = [self applicationSupportDirectory];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSString *fullPathStyles = [[self URLWithAddedBundleIdentifierDirectoryForURL:applicationSupport subDirectoryName:LIBRARY_STYLE_FOLDER_NAME] path];
	if (![fileManager fileExistsAtPath:fullPathStyles isDirectory:NULL]) {
		[fileManager createDirectoryAtPath:fullPathStyles withIntermediateDirectories:YES attributes:nil error:nil];
    }
	
	NSString *fullPathModes = [[self URLWithAddedBundleIdentifierDirectoryForURL:applicationSupport subDirectoryName:LIBRARY_MODE_FOLDER_NAME] path];
	if (![fileManager fileExistsAtPath:fullPathModes isDirectory:NULL]) {
		[fileManager createDirectoryAtPath:fullPathModes withIntermediateDirectories:YES attributes:nil error:nil];
    }
}

#pragma mark - Stuff with Precedences
- (void)revalidatePrecedences {
    // Check for overriden Rules

    NSMutableArray *rulesSoFar = [NSMutableArray array];
    
    NSEnumerator *modes = [[self modePrecedenceArray] objectEnumerator];
    id mode;
    while ((mode = [modes nextObject])) {
        
        NSEnumerator *rules = [[mode objectForKey:@"Rules"] objectEnumerator];
        id rule;
        while ((rule = [rules nextObject])) {
            BOOL isOverridden = NO;
            NSMutableDictionary *ruleCopy = [[rule mutableCopy] autorelease];
            [ruleCopy setObject:[mode objectForKey:@"Name"] forKey:@"FromMode"];

            int typeRule = [[rule objectForKey:@"TypeIdentifier"] intValue];
            NSString *stringRule = [rule objectForKey:@"String"];
            
            // Check if overridden
            NSEnumerator *overridingRules = [rulesSoFar objectEnumerator];
            id override;
            while ((override = [overridingRules nextObject])) {
                int typeOverride = [[override objectForKey:@"TypeIdentifier"] intValue];
                NSString *stringOverride = [override objectForKey:@"String"];
                
                BOOL simpleOverride = ((typeOverride==typeRule) && ([stringRule isEqualToString:stringOverride]));
                BOOL caseOverride = (((typeRule==3)&&(typeOverride==0)) && ([[stringRule uppercaseString] isEqualToString:[stringOverride uppercaseString]]));
                
                if (simpleOverride||caseOverride) {
                    [rule setObject:[NSNumber numberWithBool:YES] forKey:@"Overridden"];
                    [rule setObject:[NSString stringWithFormat:NSLocalizedString(@"Overriden by trigger in %@ mode",@"Mode Precedence Overriden Tooltip"), [override objectForKey:@"FromMode"]] forKey:@"OverriddenTooltip"];
                    isOverridden = YES;
                }   
                
            }
            
            if (!isOverridden) {
                [rule setObject:[NSNumber numberWithBool:NO] forKey:@"Overridden"];
                [rule setObject:@"" forKey:@"OverriddenTooltip"];
            }
            
            if ([[rule objectForKey:@"Enabled"] boolValue]) [rulesSoFar addObject:ruleCopy];
        }
        
    }
}

- (NSMutableArray *)reloadPrecedences {
    
    NSArray *oldPrecedenceArray = nil;
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    oldPrecedenceArray = [defaults objectForKey:@"ModePrecedences"];
    
    NSMutableArray *precendenceArray = [NSMutableArray array];
    
    
    NSMutableArray *modeOrder;
    if (oldPrecedenceArray) {
        //Recover order
        modeOrder = [NSMutableArray array];
        id oldMode;
        for (oldMode in oldPrecedenceArray) {
            if ([oldMode respondsToSelector:@selector(objectForKey:)]) {
                if ([oldMode objectForKey:@"Identifier"]) {
                    [modeOrder addObject:[oldMode objectForKey:@"Identifier"]];
                }
            } 
        }
    } else {
        // Default internal order
        modeOrder = [NSMutableArray arrayWithObjects:@"SEEMode.PHP-HTML", @"SEEMode.ERB", @"SEEMode.Ruby", @"SEEMode.bash", @"SEEMode.Objective-C", @"SEEMode.C++", @"SEEMode.C", @"SEEMode.Diff", @"SEEMode.HTML", @"SEEMode.CSS", @"SEEMode.Javascript", @"SEEMode.SDEF",@"SEEMode.XML", @"SEEMode.Perl", @"SEEMode.Pascal", @"SEEMode.Lua", @"SEEMode.AppleScript", @"SEEMode.ActionScript", @"SEEMode.LaTeX", @"SEEMode.Java", @"SEEMode.Python", @"SEEMode.SQL", @"SEEMode.Conference", @"SEEMode.LassoScript-HTML", @"SEEMode.Coldfusion", nil]; 
    }
    
    NSInteger i;
    for(i=0;i<[modeOrder count];i++) {
        [precendenceArray addObject:[NSMutableDictionary dictionary]];
    }

    NSEnumerator *enumerator = [I_modeBundles objectEnumerator];
    NSBundle *bundle;
    while ((bundle = [enumerator nextObject]) != nil) {
        
        ModeSettings *modeSettings = [[ModeSettings alloc] initWithFile:[bundle pathForResource:@"ModeSettings" ofType:@"xml"]];
		if (!modeSettings) { // Fall back to info.plist
			modeSettings = [[ModeSettings alloc] initWithPlist:[bundle bundlePath]];
		}
		
        NSMutableArray *ruleArray = [NSMutableArray array];
        if (modeSettings) {
			NSMutableDictionary *modeDictionary = [NSMutableDictionary dictionary];
            NSEnumerator *extensions = [[modeSettings recognizedExtensions] objectEnumerator];
            NSEnumerator *casesensitiveExtensions = [[modeSettings recognizedCasesensitveExtensions] objectEnumerator];
            NSEnumerator *filenames = [[modeSettings recognizedFilenames] objectEnumerator];
            NSEnumerator *regexes = [[modeSettings recognizedRegexes] objectEnumerator];

            i = [modeOrder indexOfObject:[bundle bundleIdentifier]];
            if (i!=NSNotFound) {
                [precendenceArray replaceObjectAtIndex:i withObject:modeDictionary];
            } else [precendenceArray addObject:modeDictionary];

            [modeDictionary setObject:[bundle bundleIdentifier] forKey:@"Identifier"];
            [modeDictionary setObject:[bundle objectForInfoDictionaryKey:@"CFBundleName"] forKey:@"Name"];
            [modeDictionary setObject:[bundle objectForInfoDictionaryKey:@"CFBundleVersion"] forKey:@"Version"];
            NSString *bundlePath = [bundle bundlePath];
            NSString *location = NSLocalizedString(@"User Library", @"Location: User Library");
            if ([bundlePath hasPrefix:@"/Library"]) location = NSLocalizedString(@"System Library", @"Location: System Library");
            if ([bundlePath hasPrefix:@"/Network/Library"]) location = NSLocalizedString(@"Network Library", @"Location: Network Library");
            if ([bundlePath hasPrefix:[[NSBundle mainBundle] bundlePath]]) location = NSLocalizedString(@"Application", @"Location: Application");
            [modeDictionary setObject:location forKey:@"Location"];

            [modeDictionary setObject:ruleArray forKey:@"Rules"];

			NSString *extension = nil;
			NSString *casesensitiveExtension = nil;
			NSString *filename = nil;
			NSString *regex = nil;

			while ((extension = [extensions nextObject])) {
				[ruleArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									  extension,@"String",
									  [NSNumber numberWithBool:YES],@"Enabled",
									  [NSNumber numberWithInt:0],@"TypeIdentifier",
									  [NSNumber numberWithBool:NO],@"Overridden",
									  @"",@"OverriddenTooltip",
									  [NSNumber numberWithBool:YES],@"ModeRule",
									  nil]];
			}

			while ((casesensitiveExtension = [casesensitiveExtensions nextObject])) {
				[ruleArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									  casesensitiveExtension,@"String",
									  [NSNumber numberWithBool:YES],@"Enabled",
									  [NSNumber numberWithInt:3],@"TypeIdentifier",
									  [NSNumber numberWithBool:NO],@"Overridden",
									  @"",@"OverriddenTooltip",
									  [NSNumber numberWithBool:YES],@"ModeRule",
									  nil]];
			}

			while ((filename = [filenames nextObject])) {
				[ruleArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
									  filename,@"String",
									  [NSNumber numberWithBool:YES],@"Enabled",
									  [NSNumber numberWithInt:1],@"TypeIdentifier",
									  [NSNumber numberWithBool:NO],@"Overridden",
									  @"",@"OverriddenTooltip",
									  [NSNumber numberWithBool:YES],@"ModeRule",
									  nil]];
			}

			while ((regex = [regexes nextObject])) {
				if ([OGRegularExpression isValidExpressionString:regex]) {
					[ruleArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
										  regex,@"String",
										  [NSNumber numberWithBool:YES],@"Enabled",
										  [NSNumber numberWithInt:2],@"TypeIdentifier",
										  [NSNumber numberWithBool:NO],@"Overridden",
										  @"",@"OverriddenTooltip",
										  [NSNumber numberWithBool:YES],@"ModeRule",
										  nil]];
				}
			}
		}

        [modeSettings release];

        // Enumerate rules from defaults to add user added rules back in
        NSEnumerator *oldModes = [oldPrecedenceArray objectEnumerator];
        id oldMode;
        while ((oldMode = [oldModes nextObject])) {
            if (![oldMode respondsToSelector:@selector(objectForKey:)]) {
                NSLog(@"Wrong Type in ModePrecedence Preferences: %@ %@",[oldMode class], oldMode);
                continue;
            }
            if (![[oldMode objectForKey:@"Identifier"] isEqualToString:[bundle bundleIdentifier]]) continue;
            NSEnumerator *oldRules = [[oldMode objectForKey:@"Rules"] objectEnumerator];
            NSDictionary *oldRule;
            while ((oldRule = [oldRules nextObject])) {
                if (![[oldRule objectForKey:@"ModeRule"] boolValue]) {
                    [ruleArray addObject:[[oldRule mutableCopy] autorelease]];
                }
                
                NSEnumerator *newRulesEnumerator = [ruleArray objectEnumerator];
                id newRule;
                while ((newRule = [newRulesEnumerator nextObject])) {
                    if (([[oldRule objectForKey:@"String"] isEqualToString:[newRule objectForKey:@"String"]])&&([[oldRule objectForKey:@"TypeIdentifier"] intValue] == [[newRule objectForKey:@"TypeIdentifier"] intValue]) &&[oldRule objectForKey:@"Enabled"]) {
                          [newRule setObject:[oldRule objectForKey:@"Enabled"] forKey:@"Enabled"];
                         }
                }
            }                       
        }
    }
    
	for (i=[precendenceArray count]-1;i>=0;i--) {
		if (![[precendenceArray objectAtIndex:i] objectForKey:@"Identifier"]) [precendenceArray removeObjectAtIndex:i];
	}
	
    [defaults setObject:precendenceArray forKey:@"ModePrecedences"];
    return precendenceArray;
}

#pragma mark
- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [[NSUserDefaults standardUserDefaults] setObject:[self modePrecedenceArray] forKey:@"ModePrecedences"];
}

- (void)showIncompatibleModeErrorForBundle:(NSBundle *)aBundle
{
    NSAlert *alert = [[[NSAlert alloc] init] autorelease]; 
    [alert setAlertStyle:NSWarningAlertStyle]; 
    [alert setMessageText:NSLocalizedString(@"Mode not compatible",@"Mode requires newer engine title")]; 
    [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"The mode '%@' was written for a newer version of SubEthaEngine and cannot be used with this application.", @"Mode requires newer engine Informative Text"), [aBundle bundleIdentifier]]]; 
    [alert addButtonWithTitle:@"OK"]; 
    [alert addButtonWithTitle:NSLocalizedString(@"Reveal in Finder",@"Reveal in Finder - menu entry")]; 
    [alert setDelegate:self];
    
    int returnCode = [alert runModal]; 
    
    if (returnCode == NSAlertSecondButtonReturn) {
        // Show mode in Finder
        [[NSWorkspace sharedWorkspace] selectFile:[aBundle bundlePath] inFileViewerRootedAtPath:nil];
    }
}

- (void)TCM_findModes {
	[self createUserApplicationSupportDirectory];
	
    NSURL *url = nil;
    NSMutableArray *allURLs = [NSMutableArray array];
	
    NSArray *allDomainsURLs = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSAllDomainsMask];
    for (url in allDomainsURLs) {
        [allURLs addObject:[self URLWithAddedBundleIdentifierDirectoryForURL:url subDirectoryName:LIBRARY_MODE_FOLDER_NAME]];
    }
    
    [allURLs addObject:[[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:BUNDLE_MODE_FOLDER_NAME]];
    
    NSEnumerator *enumerator = [allURLs reverseObjectEnumerator];
    NSURL *fileURL = nil;
    while ((url = [enumerator nextObject])) {
        NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        while ((fileURL = [dirEnumerator nextObject])) {
            if ([[fileURL pathExtension] isEqualToString:MODE_EXTENSION]) {
                NSBundle *bundle = [NSBundle bundleWithURL:fileURL];
                if (bundle && [bundle bundleIdentifier]) {
                    if (![DocumentMode canParseModeVersionOfBundle:bundle]) {
                        [self performSelector:@selector(showIncompatibleModeErrorForBundle:) withObject:bundle afterDelay:0]; // delay, as we don't want to block the init call, otherwise we keep receiving init messages
                    
					} else {
                        [I_modeBundles setObject:bundle forKey:[bundle bundleIdentifier]];
                        if (![I_modeIdentifiersTagArray containsObject:[bundle bundleIdentifier]]) {
                            [I_modeIdentifiersTagArray addObject:[bundle bundleIdentifier]];
                        }
                    }
                }
            }
        }
    }
}

#pragma mark - Stuff with Styles
- (NSString *)pathForWritingStyleSheetWithName:(NSString *)aStyleSheetName {
	[self createUserApplicationSupportDirectory];
	NSString *fullPath = [[self URLWithAddedBundleIdentifierDirectoryForURL:[self applicationSupportDirectory] subDirectoryName:LIBRARY_STYLE_FOLDER_NAME] path];
    return [[fullPath stringByAppendingPathComponent:aStyleSheetName] stringByAppendingPathExtension:SEEStyleSheetFileExtension];
}

- (void)TCM_findStyles { 
	[self createUserApplicationSupportDirectory];

    NSURL *url = nil;
    NSMutableArray *allURLs = [NSMutableArray array];
	
    NSArray *allDomainsURLs = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSAllDomainsMask];
    for (url in allDomainsURLs) { 
        [allURLs addObject:[self URLWithAddedBundleIdentifierDirectoryForURL:url subDirectoryName:LIBRARY_STYLE_FOLDER_NAME]];
    }
    
    [allURLs addObject:[[[NSBundle mainBundle] resourceURL] URLByAppendingPathComponent:BUNDLE_STYLE_FOLDER_NAME]];
    
    NSEnumerator *enumerator = [allURLs reverseObjectEnumerator]; 
    NSURL *fileURL = nil;
    while ((url = [enumerator nextObject])) {
        NSDirectoryEnumerator *dirEnumerator = [[NSFileManager defaultManager] enumeratorAtURL:url includingPropertiesForKeys:nil options:NSDirectoryEnumerationSkipsHiddenFiles errorHandler:NULL];
        while ((fileURL = [dirEnumerator nextObject])) {
            if ([[fileURL pathExtension] isEqualToString:SEEStyleSheetFileExtension]) {
	            [I_styleSheetPathsByName setObject:[fileURL path] forKey:[[fileURL lastPathComponent] stringByDeletingPathExtension]];
            } 
        } 
    }
//    NSLog(@"%s %@",__FUNCTION__, I_styleSheetPathsByName);
}

- (SEEStyleSheet *)styleSheetForName:(NSString *)aStyleSheetName {
	SEEStyleSheet *result = [I_styleSheetsByName objectForKey:aStyleSheetName];
	if (!result) {
		NSString *path = [I_styleSheetPathsByName objectForKey:aStyleSheetName];
		if (path) {
			result = [[SEEStyleSheet new] autorelease];
			result.styleSheetName = aStyleSheetName;
			[result importStyleSheetAtPath:[NSURL fileURLWithPath:path]];
			[result markCurrentStateAsPersistent];
			[I_styleSheetsByName setObject:result forKey:aStyleSheetName];
		}
	}
	return result;
}

- (NSArray *)allStyleSheetNames {
	return [[I_styleSheetPathsByName allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
}

- (void)saveStyleSheet:(SEEStyleSheet *)aStyleSheet {
	NSString *newPath = [self pathForWritingStyleSheetWithName:[aStyleSheet styleSheetName]];
	[aStyleSheet exportStyleSheetToPath:[NSURL fileURLWithPath:newPath]];
	[I_styleSheetPathsByName setObject:newPath forKey:[aStyleSheet styleSheetName]];
	[aStyleSheet markCurrentStateAsPersistent];
}

- (void)revealStyleSheetInFinder:(SEEStyleSheet *)aStyleSheet {
	[[NSWorkspace sharedWorkspace] selectFile:[I_styleSheetPathsByName objectForKey:[aStyleSheet styleSheetName]] inFileViewerRootedAtPath:nil];
}

#pragma mark - Stuff with modes
- (IBAction)reloadDocumentModes:(id)aSender {

    // write all preferences
    [[I_documentModesByIdentifier allValues] makeObjectsPerformSelector:@selector(writeDefaults)];
    [[NSUserDefaults standardUserDefaults] setObject:[self modePrecedenceArray] forKey:@"ModePrecedences"];

	// must be here otherwise we might deadlock
	[I_documentModesByIdentifierLock lock]; // ifc - experimental
    
    // reload all modes
    [I_modeBundles                removeAllObjects];
    [I_documentModesByIdentifier  removeAllObjects];
	[I_documentModesByName		  removeAllObjects];
    [self TCM_findModes];
	[I_documentModesByIdentifierLock unlock]; // ifc - experimental

    [[NSNotificationCenter defaultCenter] postNotificationName:@"DocumentModeListChanged" object:self];
    
    [self setModePrecedenceArray:[self reloadPrecedences]];
    [self revalidatePrecedences];


}

- (void)resolveAllDependenciesForMode:(DocumentMode *)aMode {
    if (aMode && [aMode syntaxDefinition]) {
        I_dependencyQueue = [NSMutableDictionary new];
        [I_dependencyQueue setObject:@"queued" forKey:[[aMode syntaxDefinition] name]];
        NSEnumerator *enumerator = [[[[aMode syntaxDefinition] importedModes] allKeys] objectEnumerator];
        id modeName;
        while ((modeName = [enumerator nextObject])) {
            if (![I_dependencyQueue objectForKey:modeName]) {
                [self documentModeForIdentifier:modeName];
                [I_dependencyQueue setObject:@"queued" forKey:modeName];
            }
        }
        [I_dependencyQueue release];
    }
}

- (NSString *)description {
    return [NSString stringWithFormat:@"DocumentModeManager, FoundModeBundles:%@",[I_modeBundles description]];
}

- (DocumentMode *)documentModeForName:(NSString *)aName {
    
	DocumentMode *mode = [I_documentModesByName objectForKey:aName];
	
	if ( !mode )
	{
		NSString *identifier = nil;
		if ([aName hasPrefix:@"SEEMode."]) {
			identifier = aName;
		} else {
			identifier = [NSString stringWithFormat:@"SEEMode.%@", aName];
		}
		mode = [self documentModeForIdentifier:identifier];
		
		if (!mode) {
			NSEnumerator *keyEnumerator = [[self availableModes] keyEnumerator];
			NSString *key;
			while ((key = [keyEnumerator nextObject])) {
				if ([identifier caseInsensitiveCompare:key] == NSOrderedSame) {
					mode = [self documentModeForIdentifier:key];
					break;
				}
			}
		}
        
		if ( mode )
			[I_documentModesByName setObject:mode forKey:aName];
	}
    
	return mode;
}

- (DocumentMode *)documentModeForIdentifier:(NSString *)anIdentifier {
    
    // test - perform on main thread if we are not it first, so it gets loaded if necessary
	// important: with llvm gcc this seems to be needed to not crash
    if (![NSThread isMainThread]) {[self performSelectorOnMainThread:@selector(documentModeForIdentifier:) withObject:anIdentifier waitUntilDone:YES];}
    
	[I_documentModesByIdentifierLock lock]; // ifc - experimental

    NSBundle *bundle=[I_modeBundles objectForKey:anIdentifier];
    if (bundle) {
        DocumentMode *mode=[I_documentModesByIdentifier objectForKey:anIdentifier];
        if (!mode) {
            mode = [[[DocumentMode alloc] initWithBundle:bundle] autorelease];
            if (mode) {
                [I_documentModesByIdentifier setObject:mode forKey:anIdentifier];
                
                // Load all depended modes
                NSEnumerator *linkEnumerator = [[[mode syntaxDefinition] importedModes] keyEnumerator];
                id import;
                while ((import = [linkEnumerator nextObject])) {
                    [self documentModeForName:import];
                }
            } else return nil;
            [self resolveAllDependenciesForMode:mode];
        }

		[I_documentModesByIdentifierLock unlock]; // ifc - experimental
        return mode;
    } else {
		[I_documentModesByIdentifierLock unlock]; // ifc - experimental
        return nil;
    }
}

- (NSArray *)allLoadedDocumentModes {
	return [I_documentModesByIdentifier allValues];
}


- (DocumentMode *)baseMode {
    return [self documentModeForIdentifier:BASEMODEIDENTIFIER];
}

- (DocumentMode *)modeForNewDocuments {
    DocumentMode *returnValue=[self documentModeForIdentifier:[[NSUserDefaults standardUserDefaults] objectForKey:ModeForNewDocumentsPreferenceKey]];
    if (!returnValue) {
        returnValue=[self baseMode];
    }
    return returnValue;
}

- (NSMutableArray *)modePrecedenceArray {
    return I_modePrecedenceArray;
}

- (void)setModePrecedenceArray:(NSMutableArray *)anArray {
    [self willChangeValueForKey:@"modePrecedenceArray"];
    [I_modePrecedenceArray autorelease];
    I_modePrecedenceArray=[anArray retain];
    [self didChangeValueForKey:@"modePrecedenceArray"];
}

- (DocumentMode *)documentModeForPath:(NSString *)path withContentData:(NSData *)content {
    // Convert data to ASCII, we don't know encoding yet at this point
    // FIXME Don't forget to handle UTF16/32
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    unsigned maxLength = [[NSUserDefaults standardUserDefaults] integerForKey:@"ByteLengthToUseForModeRecognitionAndEncodingGuessing"];
    NSString *contentString = [[NSString alloc] initWithBytesNoCopy:(void *)[content bytes] length:MIN([content length],maxLength) encoding:NSMacOSRomanStringEncoding freeWhenDone:NO];
    DocumentMode *mode = [self documentModeForPath:path withContentString:contentString];
    [contentString release];
    [pool release]; // this is save because mode is stored in something persistant and we know it
    return mode;
}

- (DocumentMode *)documentModeForPath:(NSString *)path withContentString:(NSString *)contentString {
    NSString *filename = [path lastPathComponent];
    NSString *extension = [path pathExtension];
    NSEnumerator *modeEnumerator = [[self modePrecedenceArray] objectEnumerator];
    NSMutableDictionary *mode;
    while ((mode = [modeEnumerator nextObject])) {

        NSEnumerator *ruleEnumerator = [[mode objectForKey:@"Rules"] objectEnumerator];
        NSMutableDictionary *rule;
        while ((rule = [ruleEnumerator nextObject])) {
            int ruleType = [[rule objectForKey:@"TypeIdentifier"] intValue];
            NSString *ruleString = [rule objectForKey:@"String"];
            
            if (ruleType == 0) { // Case insensitive extension
                if ([[ruleString uppercaseString] isEqualToString:[extension uppercaseString]]) return [self documentModeForIdentifier:[mode objectForKey:@"Identifier"]];
            } 
            if (ruleType == 3) { // Case sensitive extension
                if ([ruleString isEqualToString:extension]) return [self documentModeForIdentifier:[mode objectForKey:@"Identifier"]];
            } 
            if (ruleType == 1) {
                if ([ruleString isEqualToString:filename]) return [self documentModeForIdentifier:[mode objectForKey:@"Identifier"]];
            }  
            if (ruleType == 2 && contentString) {
                if ([OGRegularExpression isValidExpressionString:ruleString]) {
                    BOOL didMatch = NO;
                    OGRegularExpressionMatch *match;
                    OGRegularExpression *regex = [[[OGRegularExpression alloc] initWithString:ruleString options:OgreFindNotEmptyOption|OgreMultilineOption] autorelease];
                    match = [regex matchInString:contentString];
                    didMatch = [match count]>0;
                    if (didMatch) return [self documentModeForIdentifier:[mode objectForKey:@"Identifier"]];
                } else {
                    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
                    [alert setAlertStyle:NSWarningAlertStyle];
                    [alert setMessageText:NSLocalizedString(@"Trigger not a regular expression",@"Trigger not a regular expression Title")];
                    [alert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"The trigger '%@' of the mode '%@' is not a valid regular expression and was ignored.", @"Trigger not a regular expression Informative Text"), ruleString, [mode objectForKey:@"Identifier"]]];
                    [alert addButtonWithTitle:@"OK"];
                    [alert runModal];
                }
            }
        }
        
    }

    return [self baseMode];
}


/*"Returns an NSDictionary with Key=Identifier, Value=ModeName"*/
- (NSDictionary *)availableModes {
    NSMutableDictionary *result=[NSMutableDictionary dictionary];
    NSEnumerator *modeIdentifiers=[I_modeBundles keyEnumerator];
    NSString *identifier = nil;
    while ((identifier=[modeIdentifiers nextObject])) {
        [result setObject:[[I_modeBundles objectForKey:identifier] objectForInfoDictionaryKey:@"CFBundleName"] 
                   forKey:identifier];
    }
    return result;
}

- (NSString *)documentModeIdentifierForTag:(int)aTag {
    if (aTag>0 && aTag<[I_modeIdentifiersTagArray count]) {
        return [I_modeIdentifiersTagArray objectAtIndex:aTag];
    } else {
        return nil;
    }
}

- (BOOL)documentModeAvailableModeIdentifier:(NSString *)anIdentifier {
    return [I_modeBundles objectForKey:anIdentifier]!=nil;
}

- (int)tagForDocumentModeIdentifier:(NSString *)anIdentifier {
    return [I_modeIdentifiersTagArray indexOfObject:anIdentifier];
}


- (void)setupMenu:(NSMenu *)aMenu action:(SEL)aSelector alternateDisplay:(BOOL)aFlag {

    // Remove all menu items
    int count = [aMenu numberOfItems];
    while (count) {
        [aMenu removeItemAtIndex:count - 1];
        count = [aMenu numberOfItems];
    }
    

    static NSImage *s_alternateImage=nil;
    static NSDictionary *s_menuDefaultStyleAttributes, *s_menuSmallStyleAttributes;
    if (aFlag && !s_alternateImage) {
//        s_alternateImage=[[[NSImage imageNamed:@"SubEthaEditMode"] resizedImageWithSize:NSMakeSize(15,15)] retain];
        s_alternateImage=[[[[NSImage imageNamed:@"SubEthaEditMode"] copy] retain] autorelease];
        [s_alternateImage setScalesWhenResized:YES];
        [s_alternateImage setSize:NSMakeSize(16,16)];
        s_menuDefaultStyleAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont menuFontOfSize:0],NSFontAttributeName,[NSColor blackColor], NSForegroundColorAttributeName, nil];
        s_menuSmallStyleAttributes = [[NSDictionary alloc] initWithObjectsAndKeys:[NSFont menuFontOfSize:9.],NSFontAttributeName,[NSColor darkGrayColor], NSForegroundColorAttributeName, nil];
    }

    // Add modes
    DocumentMode *baseMode=[self baseMode];
    
    NSMutableArray *menuEntries=[NSMutableArray array];
    NSEnumerator *modeIdentifiers=[I_modeBundles keyEnumerator];
    NSString *identifier = nil;
    while ((identifier=[modeIdentifiers nextObject])) {
        if (![identifier isEqualToString:BASEMODEIDENTIFIER]) {
            NSBundle *modeBundle=[I_modeBundles objectForKey:identifier];
            NSString *additionalText=nil;
            NSString *bundlePath=[modeBundle bundlePath];
            NSMutableAttributedString *attributedTitle=[[NSMutableAttributedString alloc] initWithString:[bundlePath lastPathComponent] attributes:s_menuDefaultStyleAttributes];
            if ([bundlePath hasPrefix:[[NSBundle mainBundle] bundlePath]]) {
                additionalText=[NSString stringWithFormat:@"SubEthaEdit %@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
            } else if ([bundlePath hasPrefix:@"/Library"]) {
                additionalText=@"/Library";
            } else if ([bundlePath hasPrefix:NSHomeDirectory()?NSHomeDirectory():@"/Users"]) {
                additionalText=@"~/Library";
            } else if ([bundlePath hasPrefix:NSHomeDirectory()?NSHomeDirectory():@"/Network"]) {
                additionalText=@"/Network";
            }

            [attributedTitle appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (%@ v%@, %@)",identifier,[[modeBundle infoDictionary] objectForKey:@"CFBundleShortVersionString"],additionalText] attributes:s_menuSmallStyleAttributes] autorelease]];
            
            [menuEntries 
                addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:identifier,@"Identifier",[modeBundle objectForInfoDictionaryKey:@"CFBundleName"],@"Name",attributedTitle,@"AttributedTitle",nil]];
            [attributedTitle release];
        }
    }

    NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:[[baseMode bundle] objectForInfoDictionaryKey:@"CFBundleName"] action:aSelector keyEquivalent:@""];
    [menuItem setTag:[self tagForDocumentModeIdentifier:BASEMODEIDENTIFIER]];
    [aMenu addItem:menuItem];
    [menuItem release];

    count=[menuEntries count];
    if (count > 0) {
        [aMenu addItem:[NSMenuItem separatorItem]];
        
        // sort
        NSArray *sortedEntries=[menuEntries sortedArrayUsingDescriptors:
                        [NSArray arrayWithObjects:
                            [[[NSSortDescriptor alloc] initWithKey:@"Name" ascending:YES selector:@selector(caseInsensitiveCompare:)] autorelease],
                            [[[NSSortDescriptor alloc] initWithKey:@"Identifier" ascending:YES] autorelease],nil]];
        
        int index=0;
        for (index=0;index<count;index++) {
            NSDictionary *entry=[sortedEntries objectAtIndex:index];
            NSMenuItem *menuItem =[[NSMenuItem alloc] initWithTitle:[entry objectForKey:@"Name"]
                                                             action:aSelector
                                                      keyEquivalent:@""];
            [menuItem setTag:[self tagForDocumentModeIdentifier:[entry objectForKey:@"Identifier"]]];
            if (aFlag) {
                [menuItem setAttributedTitle:[entry objectForKey:@"AttributedTitle"]];
                [menuItem setImage:s_alternateImage];
            }
            [aMenu addItem:menuItem];
            [menuItem release];
            
        }
    }
    if (aFlag) {
        [aMenu addItem:[NSMenuItem separatorItem]];
        menuItem = [[NSMenuItem alloc] 
            initWithTitle:NSLocalizedString(@"Open User Modes Folder", @"Menu item in alternate mode menu for opening the user modes folder.")
                   action:@selector(revealModesFolder:)
            keyEquivalent:@""];
        [menuItem setTag:2];
        [menuItem setTarget:self];
        [aMenu addItem:menuItem];
        [menuItem release];

        menuItem = [[NSMenuItem alloc] 
            initWithTitle:NSLocalizedString(@"Open Library Modes Folder",@"Menu item in alternate mode menu for opening the library modes folder.")
                   action:@selector(revealModesFolder:)
            keyEquivalent:@""];
        [menuItem setTag:1];
        [menuItem setTarget:self];
        [aMenu addItem:menuItem];
        [menuItem release];

        menuItem = [[NSMenuItem alloc] 
            initWithTitle:NSLocalizedString(@"Open SubEthaEdit Modes Folder",@"Menu item in alternate mode menu for opening the SubEthaEdit modes folder.")
                   action:@selector(revealModesFolder:)
            keyEquivalent:@""];
        [menuItem setTag:0];
        [menuItem setTarget:self];
        [aMenu addItem:menuItem];
        [menuItem release];
    }
}

- (IBAction)revealModesFolder:(id)aSender {
    NSString *directoryString = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"Modes/"];
    switch ([aSender tag]) {
        case 2: {
            NSArray *userDomainPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
            NSString *path=[userDomainPaths lastObject];
            directoryString = [path stringByAppendingPathComponent:MODEPATHCOMPONENT]; }
            break;
        case 1: {
            NSArray *systemDomainPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, YES);
            NSString *path=[systemDomainPaths lastObject];
            directoryString = [path stringByAppendingPathComponent:MODEPATHCOMPONENT];
            }
            break;
    }
    if (![[NSWorkspace sharedWorkspace] openFile:directoryString]) NSBeep();;
}

- (void)setupPopUp:(DocumentModePopUpButton *)aPopUp selectedModeIdentifier:(NSString *)aModeIdentifier automaticMode:(BOOL)hasAutomaticMode {
    [aPopUp removeAllItems];
    NSMenu *tempMenu=[[NSMenu new] autorelease];
    [self setupMenu:tempMenu action:@selector(none:) alternateDisplay:NO];
    if (hasAutomaticMode) {
        NSMenuItem *menuItem=[[[tempMenu itemArray] objectAtIndex:0] copy];
        [menuItem setTag:[self tagForDocumentModeIdentifier:AUTOMATICMODEIDENTIFIER]];
        [menuItem setTitle:NSLocalizedString(@"Automatic Mode", @"Foo")];
        [tempMenu insertItem:menuItem atIndex:0];
        [menuItem release];
    }
    NSEnumerator *menuItems=[[tempMenu itemArray] objectEnumerator];
    NSMenuItem *item=nil;
    while ((item=[menuItems nextObject])) {
        if (![item isSeparatorItem]) {
            [aPopUp addItemWithTitle:[item title]];
            [[aPopUp lastItem] setTag:[item tag]];
            [[aPopUp lastItem] setEnabled:YES];
        }     
    }
    if (hasAutomaticMode) {
        [[aPopUp menu] insertItem:[NSMenuItem separatorItem] atIndex:1];
    }
    [aPopUp setSelectedModeIdentifier:aModeIdentifier];
}

@end
