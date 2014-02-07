//
//  NSImageTCMAdditions.h
//  SubEthaEdit
//
//  Created by Dominik Wagner on Mon Mar 08 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSImage (NSImageTCMAdditions) 

// these are defines for a reason, so you can write
// @"SharingIconWrite" TCM_PDFIMAGE_SEP @"56" TCM_PDFIMAGE_SEP @"#a23456" TCM_PDFIMAGE_SEP TCM_PDFIMAGE_SEP @"#a23456" TCM_PDFIMAGE_SEP TCM_PDFIMAGE_SELECTED TCM_PDFIMAGE_DISABLED
#define TCM_PDFIMAGE_SEP @"_"
#define TCM_PDFIMAGE_NORMAL @"Normal"
#define TCM_PDFIMAGE_SELECTED @"Selected"
#define TCM_PDFIMAGE_HIGHLIGHTED @"Highlighted"
#define TCM_PDFIMAGE_DISABLED @"Disabled"

/** 
	@return an resolution independent image based on the pdf, filled with either the fillColor or the selectionColor (implicidly the menu selection color currently) depending on the name. The name has to be <pdf-filename-without-extension>_<pointwidth>_[<normalcolor>_<selectedcolor>_<highlightcolor>_]<Normal[Disabled]|Selected[Disabled]>
 
 */

+ (NSImage *)pdfBasedImageNamed:(NSString *)aName;
- (NSImage *)resizedImageWithSize:(NSSize)aSize;
- (NSImage *)dimmedImage;

@end
