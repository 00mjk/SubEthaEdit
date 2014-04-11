//
//  SEECollaborationPreferenceModule.m
//  SubEthaEdit
//
//  Created by Lisa Brodner on 10/04/14.
//  Copyright (c) 2014 TheCodingMonkeys. All rights reserved.
//

// this file needs arc - either project wide,
// or add -fobjc-arc on a per file basis in the compile build phase
#if !__has_feature(objc_arc)
#error ARC must be enabled!
#endif

#import "SEECollaborationPreferenceModule.h"

#import "PreferenceKeys.h"

#import <AddressBook/AddressBook.h>
#import "TCMMMUserManager.h"
#import "TCMMMBEEPSessionManager.h"
#import "TCMMMUser.h"
#import "TCMMMUserSEEAdditions.h"

#import <TCMPortMapper/TCMPortMapper.h>
#import "TCMMMBEEPSessionManager.h"

@implementation SEECollaborationPreferenceModule

#pragma mark - Preference Module - Basics
- (NSImage *)icon {
    return [NSImage imageNamed:@"PrefIconCollaboration"];
}

- (NSString *)iconLabel {
    return NSLocalizedStringWithDefaultValue(@"CollaborationPrefsIconLabel", nil, [NSBundle mainBundle], @"Collaboration", @"Label displayed below collaboration icon and used as window title.");
}

- (NSString *)identifier {
    return @"de.codingmonkeys.subethaedit.preferences.collaboration";
}

- (NSString *)mainNibName {
    return @"SEECollaborationPrefs";
}

- (void)mainViewDidLoad {
    // Initialize user interface elements to reflect current preference settings

	[self TCM_setupComboBoxes];
    [self TCM_setupColorPopUp];
	
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    
    TCMMMUser *me=[TCMMMUserManager me];
    NSImage *myImage = [me image];
    [myImage setFlipped:NO];
    [self.O_pictureImageView setImage:myImage];
    [self.O_nameTextField setStringValue:[me name]];
    [self.O_emailComboBox setStringValue:[[me properties] objectForKey:@"Email"]];

    [self.O_automaticallyMapPortButton setState:[defaults boolForKey:ShouldAutomaticallyMapPort]?NSOnState:NSOffState];
    [self.O_localPortTextField setStringValue:[NSString stringWithFormat:@"%d",[[TCMMMBEEPSessionManager sharedInstance] listeningPort]]];
	
    TCMPortMapper *pm = [TCMPortMapper sharedInstance];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portMapperDidStartWork:) name:TCMPortMapperDidStartWorkNotification object:pm];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(portMapperDidFinishWork:) name:TCMPortMapperDidFinishWorkNotification object:pm];
    if ([pm isAtWork]) {
        [self portMapperDidStartWork:nil];
    } else {
        [self portMapperDidFinishWork:nil];
    }
}

#pragma mark - Port Mapper

- (void)portMapperDidStartWork:(NSNotification *)aNotification {
    [self.O_mappingStatusProgressIndicator startAnimation:self];
    [self.O_mappingStatusImageView setHidden:YES];
    [self.O_mappingStatusTextField setStringValue:NSLocalizedString(@"Checking port status...",@"Status of port mapping while trying")];
}

- (void)portMapperDidFinishWork:(NSNotification *)aNotification {
    [self.O_mappingStatusProgressIndicator stopAnimation:self];
    // since we only have one mapping this is fine
    TCMPortMapping *mapping = [[[TCMPortMapper sharedInstance] portMappings] anyObject];
    if ([mapping mappingStatus]==TCMPortMappingStatusMapped) {
        [self.O_mappingStatusImageView setImage:[NSImage imageNamed:NSImageNameStatusAvailable]];
        [self.O_mappingStatusTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Port mapped (%d)",@"Status of Port mapping when successful"), [mapping externalPort]]];
    } else {
        [self.O_mappingStatusImageView setImage:[NSImage imageNamed:NSImageNameStatusUnavailable]];
        [self.O_mappingStatusTextField setStringValue:NSLocalizedString(@"Port not mapped",@"Status of Port mapping when unsuccessful or intentionally unmapped")];
    }
    [self.O_mappingStatusImageView setHidden:NO];
}

#pragma mark - Me Card
- (void)TCM_setupComboBoxes {
    ABPerson *meCard = [[ABAddressBook sharedAddressBook] me];
	
	// populate email combobox
    ABMultiValue *emailAccounts = [meCard valueForProperty:kABEmailProperty];
	if ([emailAccounts propertyType] == kABMultiStringProperty)
	{
		for (NSString *emailAccountsIdentifier in emailAccounts)
		{
			NSString *email = [emailAccounts valueForIdentifier:emailAccountsIdentifier];
			[self.O_emailComboBox addItemWithObjectValue:email];
		}
	}
}

- (void)TCM_setupColorPopUp {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
    NSArray *colorNames=[NSArray arrayWithObjects:@"ColorRed",@"ColorOrange",@"ColorYellow",@"ColorGreen",@"ColorTeal",@"ColorBlue",@"ColorPurple",@"ColorPink",nil];
    int colorHues[]={0,3300/360,6600/360,10900/360,18000/360,22800/360,26400/360,31700/360};
    
    [self.O_colorsPopUpButton removeAllItems];
    
    int i;
    for (i=0;i<(int)[colorNames count];i++) {
        // (void)NSLocalizedString(@"ColorRed", @"Red");
        // (void)NSLocalizedString(@"ColorOrange", @"Orange");
        // (void)NSLocalizedString(@"ColorYellow", @"Yellow");
        // (void)NSLocalizedString(@"ColorGreen", @"Green");
        // (void)NSLocalizedString(@"ColorTeal", @"Teal");
        // (void)NSLocalizedString(@"ColorBlue", @"Blue");
        // (void)NSLocalizedString(@"ColorPurple", @"Purple");
        // (void)NSLocalizedString(@"ColorPink", @"Pink");
        // (void)NSLocalizedString(@"ColorCustom", @"Custom Color Name");
        [self.O_colorsPopUpButton addItemWithTitle:NSLocalizedString([colorNames objectAtIndex:i],@"<do not localize>")];
        NSMenuItem *item=[self.O_colorsPopUpButton lastItem];
        [item setImage:[self TCM_menuImageWithColor:[NSColor colorWithCalibratedHue:colorHues[i]/100.
																		 saturation:1. brightness:1. alpha:1.]]];
        [item setTag:colorHues[i]];
    }
    [[self.O_colorsPopUpButton menu] addItem:[NSMenuItem separatorItem]];
    [self.O_colorsPopUpButton addItemWithTitle:NSLocalizedString(@"ColorCustom",@"Custom Color Name")];
	
    NSValueTransformer *hueTrans=[NSValueTransformer valueTransformerForName:@"HueToColor"];
    [[self.O_colorsPopUpButton lastItem]
	 setImage: [self TCM_menuImageWithColor:[hueTrans transformedValue:[defaults objectForKey:CustomMyColorHuePreferenceKey]]]];
    [[self.O_colorsPopUpButton lastItem] setTag:-1];
    [self.O_colorsPopUpButton selectItemAtIndex:[defaults integerForKey:SelectedMyColorPreferenceKey]];
}

- (void)TCM_updateWells {
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    [defaults setObject:[defaults objectForKey:ChangesSaturationPreferenceKey] forKey:ChangesSaturationPreferenceKey];
    [defaults setObject:[defaults objectForKey:SelectionSaturationPreferenceKey] forKey:SelectionSaturationPreferenceKey];
    [self TCM_sendGeneralViewPreferencesDidChangeNotificiation];
}

#pragma mark - Colors

#define COLORMENUIMAGEWIDTH 20.
#define COLORMENUIMAGEHEIGHT 10.

- (NSImage *)TCM_menuImageWithColor:(NSColor *)aColor {
    NSRect rect = NSMakeRect(0.0, 0.0, COLORMENUIMAGEWIDTH, COLORMENUIMAGEHEIGHT);
	NSImage *image = [NSImage imageWithSize:rect.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		[aColor drawSwatchInRect:dstRect];
		[[NSColor blackColor] set];
		[NSBezierPath strokeRect:dstRect];
		return YES;
	}];
    return image;
}

#pragma mark - IBActions - Me Card - Image
- (IBAction)useAddressBookImage:(id)aSender {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:MyImagePreferenceKey];
    ABPerson *meCard=[[ABAddressBook sharedAddressBook] me];
    NSImage *myImage=nil;
    if (meCard) {
        @try {
            NSData  *imageData;
            if ((imageData=[meCard imageData])) {
                myImage=[[NSImage alloc] initWithData:imageData];
                [myImage setCacheMode:NSImageCacheNever];
            }
        } @catch (id exception) {
			
        }
    }
    
    if (!myImage) {
        myImage=[NSImage imageNamed:@"DefaultPerson"];
    }
    NSData *pngData=[[myImage resizedImageWithSize:NSMakeSize(64.,64.)] TIFFRepresentation];
    pngData=[[NSBitmapImageRep imageRepWithData:pngData] representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
	
    TCMMMUser *me = [TCMMMUserManager me];
    [[me properties] setObject:pngData forKey:@"ImageAsPNG"];
    [me recacheImages];
	myImage = [me image];
    [myImage setFlipped:NO];
    [self.O_pictureImageView setImage:myImage];
    [TCMMMUserManager didChangeMe];
}

- (IBAction)chooseImage:(id)aSender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
	
	[panel beginSheetModalForWindow:[self.O_pictureImageView window] completionHandler:^(NSInteger result) {
		if (result == NSFileHandlingPanelOKButton) {
			NSImage *image = [[NSImage alloc] initWithContentsOfURL:[panel URL]];
			if (image) {
				[self.O_pictureImageView setImage:image];
				[self takeImageFromImageView:self.O_pictureImageView];
			} else {
				NSBeep();
			}
		}
	}];
}

- (IBAction)takeImageFromImageView:(id)aSender {
    NSData *pngData=[[[self.O_pictureImageView realImage] resizedImageWithSize:NSMakeSize(64.,64.)] TIFFRepresentation];
    pngData=[[NSBitmapImageRep imageRepWithData:pngData] representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
	
    TCMMMUser *me = [TCMMMUserManager me];
    [[me properties] setObject:pngData forKey:@"ImageAsPNG"];
    [me recacheImages];
    [[NSUserDefaults standardUserDefaults] setObject:pngData forKey:MyImagePreferenceKey];
	NSImage *myImage = [me image];
    [myImage setFlipped:NO];
    [self.O_pictureImageView setImage:myImage];
    [TCMMMUserManager didChangeMe];
}

- (IBAction)clearImage:(id)aSender {
    NSData *pngData=[[NSImage imageNamed:@"DefaultPerson"] TIFFRepresentation];
    pngData=[[NSBitmapImageRep imageRepWithData:pngData] representationUsingType:NSPNGFileType properties:[NSDictionary dictionary]];
    TCMMMUser *me = [TCMMMUserManager me];
    [[me properties] setObject:pngData forKey:@"ImageAsPNG"];
    [me recacheImages];
    [[NSUserDefaults standardUserDefaults] setObject:pngData forKey:MyImagePreferenceKey];
    [self.O_pictureImageView setImage:[me image]];
    [TCMMMUserManager didChangeMe];
}


#pragma mark - IBActions - Me Card

- (IBAction)changeName:(id)aSender {
    TCMMMUser *me=[TCMMMUserManager me];
    NSString *newValue=[self.O_nameTextField stringValue];
    if (![[me name] isEqualTo:newValue]) {
		
        CFStringRef appID = (__bridge CFStringRef)[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"];
        // Set up the preference.
        CFPreferencesSetValue((__bridge CFStringRef)MyNamePreferenceKey, (__bridge CFStringRef)newValue, appID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
        // Write out the preference data.
        CFPreferencesSynchronize(appID, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost);
		
        [me setName:newValue];
        [TCMMMUserManager didChangeMe];
    }
}

- (IBAction)changeEmail:(id)aSender {
    TCMMMUser *me=[TCMMMUserManager me];
    NSString *newValue=[self.O_emailComboBox stringValue];
    if (![[[me properties] objectForKey:@"Email"] isEqualTo:newValue]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:newValue forKey:MyEmailPreferenceKey];
        ABPerson *meCard=[[ABAddressBook sharedAddressBook] me];
        ABMultiValue *emails=[meCard valueForProperty:kABEmailProperty];
        int index=0;
        int count=[emails count];
        for (index=0;index<count;index++) {
            if ([newValue isEqualToString:[emails valueAtIndex:index]]) {
                NSString *identifier=[emails identifierAtIndex:index];
                [defaults setObject:identifier forKey:MyEmailIdentifierPreferenceKey];
                break;
            }
        }
        if (count==index) {
            [defaults removeObjectForKey:MyEmailIdentifierPreferenceKey];
        }
        [[me properties] setObject:newValue forKey:@"Email"];
        [TCMMMUserManager didChangeMe];
    }
}

#pragma mark - IBActions - Colors
- (IBAction)updateChangesColor:(id)sender {
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];

    NSNumber *userHue = [defaults objectForKey:MyColorHuePreferenceKey];
    [[TCMMMUserManager me] setUserHue:userHue];
    [TCMMMUserManager didChangeMe];
	
    [self TCM_updateWells];
	[self postGeneralViewPreferencesDidChangeNotificiation:self];
}


 - (IBAction)changeMyColor:(id)aSender {
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    int tag=[[self.O_colorsPopUpButton selectedItem] tag];
    NSValueTransformer *hueTrans=[NSValueTransformer valueTransformerForName:@"HueToColor"];
    
    [defaults setObject:[NSNumber numberWithInt:[self.O_colorsPopUpButton indexOfSelectedItem]]
                 forKey:SelectedMyColorPreferenceKey];
	
    if (tag==-1) {
        [NSColorPanel setPickerMode:NSHSBModeColorPanel];
        NSColorPanel *panel=[NSColorPanel sharedColorPanel];
        [panel setAction:@selector(changeMyCustomColor:)];
        [panel setTarget:self];
        [panel setShowsAlpha:NO];
        [panel orderFront:self];
        [panel setColor:[hueTrans transformedValue:[defaults objectForKey:CustomMyColorHuePreferenceKey]]];
        tag=(int)([[defaults objectForKey:CustomMyColorHuePreferenceKey] floatValue]);
    } else {
        [[NSColorPanel sharedColorPanel] orderOut:self];
    }
	
    NSNumber *value=[NSNumber numberWithFloat:(float)tag];
    [defaults setObject:value
                 forKey:MyColorHuePreferenceKey];
	
    [[TCMMMUserManager me] setUserHue:value];
    [TCMMMUserManager didChangeMe];
	
    [self TCM_updateWells];
}

// called via selector
- (IBAction)changeMyCustomColor:(id)aSender {
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    NSValueTransformer *hueTrans=[NSValueTransformer valueTransformerForName:@"HueToColor"];
    NSNumber *hue = (NSNumber *)[hueTrans reverseTransformedValue:[aSender color]];
    [[self.O_colorsPopUpButton lastItem]
	 setImage: [self TCM_menuImageWithColor:[hueTrans transformedValue:hue]]];
	
    [defaults setObject:hue
                 forKey:MyColorHuePreferenceKey];
    [defaults setObject:hue
                 forKey:CustomMyColorHuePreferenceKey];
    [[TCMMMUserManager me] setUserHue:hue];
    [TCMMMUserManager didChangeMe];
	
    [self TCM_updateWells];
}

#pragma mark - View Update Notification
- (void)TCM_sendGeneralViewPreferencesDidChangeNotificiation {
    [[NSNotificationQueue defaultQueue]
	 enqueueNotification:[NSNotification notificationWithName:GeneralViewPreferencesDidChangeNotificiation object:self]
	 postingStyle:NSPostWhenIdle
	 coalesceMask:NSNotificationCoalescingOnName | NSNotificationCoalescingOnSender
	 forModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
}

- (IBAction)postGeneralViewPreferencesDidChangeNotificiation:(id)aSender {
    [self TCM_sendGeneralViewPreferencesDidChangeNotificiation];
}

#pragma mark - IBActions - Port Mapping
- (IBAction)changeAutomaticallyMapPorts:(id)aSender {
    BOOL shouldStart = ([self.O_automaticallyMapPortButton state]==NSOnState);
    [[NSUserDefaults standardUserDefaults] setBool:shouldStart forKey:ShouldAutomaticallyMapPort];
    if (shouldStart) {
        [[TCMPortMapper sharedInstance] start];
    } else {
        [[TCMPortMapper sharedInstance] stop];
    }
}


#pragma mark - Localization
- (NSString *)localizedNetworkBoxLabelText {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_NETWORK_LABEL", nil, [NSBundle mainBundle],
														 @"Network",
														 @"Collaboration Preferences - Label for the network box");
	return string;
}

- (NSString *)localizedLocalPortLabelText {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_LOCAL_PORT_LABEL", nil, [NSBundle mainBundle],
														 @"Local Port:",
														 @"Collaboration Preferences - Label for the local port");
	return string;
}

- (NSString *)localizedAutomaticallyMapPortsLabelText {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_AUTOMATICALLY_MAP_PORT_LABEL", nil, [NSBundle mainBundle],
														 @"Automatically map port",
														 @"Collaboration Preferences - Label for the automatically map port toggle");
	return string;
}

- (NSString *)localizedAutomaticallyMapPortsExplanationText {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_AUTOMATICALLY_MAP_PORT_DESCRIPTION", nil, [NSBundle mainBundle],
														 @"NAT traversal uses either NAT-PMP or UPnP",
														 @"Collaboration Preferences - Label with additional description for the automatically map port toggle");
	return string;
}

- (NSString *)localizedAutomaticallyMapPortsToolTipText {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_AUTOMATICALLY_MAP_PORT_TOOL_TIP", nil, [NSBundle mainBundle],
														 @"SubEthaEdit will try to automatically map the local port to an external port if it is behind a NAT. For this to work you have to enable UPnP or NAT-PMP on your router.",
														 @"Collaboration Preferences - tool tip for the automatically map port toggle");
	return string;
}


// me card related
- (NSString *)localizedUserNameLabel {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_USER_NAME_LABEL", nil, [NSBundle mainBundle],
														 @"Name:",
														 @"Collaboration Preferences - Label for the user name text field");
	return string;
}

- (NSString *)localizedUserEmailLabel {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_USER_EMAIL_LABEL", nil, [NSBundle mainBundle],
														 @"Email:",
														 @"Collaboration Preferences - Label for the user email text field");
	return string;
}


- (NSString *)localizedImageMenuAddressBook {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_USER_IMAGE_AB", nil, [NSBundle mainBundle],
														 @"Use Address Book",
														 @"Collaboration Preferences - Image Menu - Use Image from Address Book option");
	return string;
}

- (NSString *)localizedImageMenuChoose {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_USER_IMAGE_CHOOSE", nil, [NSBundle mainBundle],
														 @"Choose Image...",
														 @"Collaboration Preferences - Image Menu - Choose Image option");
	return string;
}

- (NSString *)localizedImageMenuClear {
	NSString *string = NSLocalizedStringWithDefaultValue(@"COLLAB_USER_IMAGE_CLEAR", nil, [NSBundle mainBundle],
														 @"Clear Image",
														 @"Collaboration Preferences - Image Menu - Clear Image option");
	return string;
}

@end
