//
//  NSImageTCMAdditions.m
//  SubEthaEdit
//
//  Created by Dominik Wagner on Mon Mar 08 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "NSImageTCMAdditions.h"
#import <Quartz/Quartz.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSColorTCMAdditions.h"
#import <objc/objc-runtime.h>


// this file needs arc - either project wide,
// or add -fobjc-arc on a per file basis in the compile build phase
#if !__has_feature(objc_arc)
#error ARC must be enabled!
#endif

@implementation NSImage (NSImageTCMAdditions)

const void *TCMImageAdditionsPDFAssociationKey = &TCMImageAdditionsPDFAssociationKey;

+ (NSImage *)highResolutionImageWithSize:(NSSize)inSize usingDrawingBlock:(void (^)(void))drawingBlock
{
	NSImage * resultImage = [[NSImage alloc] initWithSize:inSize];
	if (resultImage)
	{
		// Save external graphic context
		NSGraphicsContext *currentContext = [NSGraphicsContext currentContext];

		// create @1x bitmap representation (72ppi)
		{
			NSBitmapImageRep *lowResBitmapImageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																							 pixelsWide:inSize.width
																							 pixelsHigh:inSize.height
																						  bitsPerSample:8
																						samplesPerPixel:4
																							   hasAlpha:YES
																							   isPlanar:NO
																						 colorSpaceName:NSCalibratedRGBColorSpace
																						   bitmapFormat:NSAlphaFirstBitmapFormat
																							bytesPerRow:0
																						   bitsPerPixel:0];

			lowResBitmapImageRep = [lowResBitmapImageRep bitmapImageRepByRetaggingWithColorSpace:[NSColorSpace sRGBColorSpace]];

			NSGraphicsContext *lowResBitmapContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:lowResBitmapImageRep];
			[NSGraphicsContext setCurrentContext:lowResBitmapContext];

			drawingBlock(); // your drawing code in points

			[resultImage addRepresentation:lowResBitmapImageRep];
		}

		// create @2x retina bitmap (144ppi)
		{
			NSBitmapImageRep *highResBitmapImageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
																							  pixelsWide:inSize.width * 2.0
																							  pixelsHigh:inSize.height * 2.0
																						   bitsPerSample:8
																						 samplesPerPixel:4
																								hasAlpha:YES
																								isPlanar:NO
																						  colorSpaceName:NSCalibratedRGBColorSpace
																							bitmapFormat:NSAlphaFirstBitmapFormat
																							 bytesPerRow:0
																							bitsPerPixel:0];

			highResBitmapImageRep = [highResBitmapImageRep bitmapImageRepByRetaggingWithColorSpace:[NSColorSpace sRGBColorSpace]];
			[highResBitmapImageRep setSize:inSize]; // this sets the image to be 144ppi

			NSGraphicsContext *highResBitmapContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:highResBitmapImageRep];
			[NSGraphicsContext setCurrentContext:highResBitmapContext];

			drawingBlock(); // your drawing code in points

			[resultImage addRepresentation:highResBitmapImageRep];
		}

		// restore external graphic context
		[NSGraphicsContext setCurrentContext:currentContext];
	}
	return resultImage;
}


+ (NSImage *)pdfBasedImageNamed:(NSString *)aName {
	NSImage *result = [NSImage imageNamed:aName];
	if (!result) {
		NSArray *parts = [aName componentsSeparatedByString:@"_"];
		
		NSInteger pointWidth = [[parts objectAtIndex:1] integerValue];
		
		NSColor *selectedColor = [NSColor selectedMenuItemColor];
		NSColor *normalColor   = [NSColor darkGrayColor];
		NSColor *highlightColor = [[NSColor selectedMenuItemColor] blendedColorWithFraction:0.25 ofColor:[NSColor blackColor]];
		
		if (parts.count > 3) {
			normalColor = [NSColor colorForHTMLString:parts[2]];
		}
		if (parts.count > 4) {
			selectedColor = [NSColor colorForHTMLString:parts[3]];
		}
		if (parts.count > 5) {
			highlightColor = [NSColor colorForHTMLString:parts[4]];
		}

		
		NSColor *fillColor = normalColor;
		NSString *pdfName = parts.firstObject;
		NSString *state = parts.lastObject;
		if ([state hasPrefix:TCM_PDFIMAGE_SELECTED]) {
			fillColor = selectedColor;
		} else if ([state hasPrefix:TCM_PDFIMAGE_HIGHLIGHTED]) {
			fillColor = highlightColor;
		}
		BOOL disabled = [state hasSuffix:TCM_PDFIMAGE_DISABLED];
		if (disabled) {
			fillColor = [fillColor blendedColorWithFraction:0.25 ofColor:[NSColor colorWithCalibratedWhite:0.856 alpha:1.000]];
		}
		NSURL *url = [[NSBundle mainBundle] URLForResource:pdfName withExtension:@"pdf"];
		CGDataProviderRef dataProvider = CGDataProviderCreateWithURL((__bridge CFURLRef)url);
		CGPDFDocumentRef pdfDocument = CGPDFDocumentCreateWithProvider(dataProvider);
		CFRelease(dataProvider);
		
		CGPDFPageRef page1 = CGPDFDocumentGetPage(pdfDocument, 1);
		NSRect boxRect = CGPDFPageGetBoxRect(page1,kCGPDFCropBox);
		
		CGRect fullRect = CGRectZero;
		fullRect.size = CGSizeMake(pointWidth, pointWidth);
		fullRect.size.height = round(boxRect.size.height * fullRect.size.width / boxRect.size.width);
		NSSize scaleFactors = NSMakeSize(fullRect.size.width / boxRect.size.width,
										 fullRect.size.height / boxRect.size.height);
		result = [NSImage imageWithSize:fullRect.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {

			[[NSColor clearColor] set];
			NSRectFill(dstRect);
			
			CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort];
			
			CGSize layerScale = CGSizeMake(CGBitmapContextGetWidth(context) / fullRect.size.width,
										   CGBitmapContextGetHeight(context) / fullRect.size.height);
			
			CGRect layerRect = CGRectMake(0, 0, fullRect.size.width * layerScale.width, fullRect.size.height * layerScale.height);
			CGLayerRef layer = CGLayerCreateWithContext(context, layerRect.size, nil);
			CGContextRef layerContext = CGLayerGetContext(layer);
			CGContextSaveGState(layerContext);
			CGContextScaleCTM(layerContext, scaleFactors.width * layerScale.width,
							  scaleFactors.height * layerScale.height);
			CGContextTranslateCTM(layerContext, -boxRect.origin.x, -boxRect.origin.y);
			CGContextDrawPDFPage(layerContext, page1);
			CGContextRestoreGState(layerContext);
			
			CGContextSetBlendMode(layerContext, kCGBlendModeSourceIn);
			CGContextSetFillColorWithColor(layerContext, [fillColor CGColor]);
			CGContextFillRect(layerContext, layerRect);

			CGContextSetShadowWithColor(context, CGSizeMake(0, -1.0), 0.5, [[NSColor colorWithCalibratedWhite:1.0 alpha:1.0/3.0] CGColor]);
//			CGContextSetShadow(context, CGSizeMake(0, -1.0), 1.0);
			CGContextScaleCTM(context, 1/layerScale.width, 1/layerScale.height);
			if (disabled) {
				CGContextSetAlpha(context, 0.9);
			}
			CGContextDrawLayerAtPoint(context, CGPointZero, layer);
			CGLayerRelease(layer);
/*			CGContextSetBlendMode(context, kCGBlendModeNormal);
			[[NSColor clearColor] set];
			NSRectFill(dstRect);
			CGContextClipToMask(context, fullRect, maskImage);
			[aFillColor set];
			NSRectFill(dstRect);
*/
			return YES;
		}];

		// need to hold onto the pdf document while image is living
		objc_setAssociatedObject(result, TCMImageAdditionsPDFAssociationKey, CFBridgingRelease(pdfDocument), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		result.name = aName;
	}
	return result;
}


- (NSImage *)resizedImageWithSize:(NSSize)aSize {
    NSSize originalSize=[self size];
    NSSize newSize=aSize;
    if (originalSize.width>originalSize.height) {
        newSize.height=(int)(originalSize.height/originalSize.width*newSize.width);
        if (newSize.height<=0) newSize.height=1;
    } else {
        newSize.width=(int)(originalSize.width/originalSize.height*newSize.height);            
        if (newSize.width <=0) newSize.width=1;
    }

	NSImage *resultImage = [NSImage imageWithSize:newSize flipped:self.isFlipped drawingHandler:^BOOL(NSRect dstRect) {
		[[NSColor clearColor] set];
		NSRectFill(dstRect);
		NSGraphicsContext *context = [NSGraphicsContext currentContext];
		[context setImageInterpolation:NSImageInterpolationHigh];
		[self drawInRect:NSMakeRect(0.,0.,newSize.width, newSize.height)
					 fromRect:NSZeroRect
					operation:NSCompositeSourceOver
					 fraction:1.0];
		return YES;
	}];
    return resultImage;
}


- (NSImage *)imageTintedWithColor:(NSColor *)tint invert:(BOOL)aFlag
{
    if (tint != nil) {
    	NSImage *tintedImage = [NSImage imageWithSize:self.size flipped:self.isFlipped drawingHandler:^BOOL(NSRect dstRect) {
			CIFilter *colorGenerator = [CIFilter filterWithName:@"CIConstantColorGenerator"];
			CIColor *color = [[CIColor alloc] initWithColor:tint];
			[colorGenerator setDefaults];
			[colorGenerator setValue:color forKey:@"inputColor"];

			CIFilter *monochromeFilter = [CIFilter filterWithName:@"CIColorMonochrome"];
			CIImage *baseImage = [CIImage imageWithData:[self TIFFRepresentation]];
			[monochromeFilter setDefaults];
			[monochromeFilter setValue:baseImage forKey:@"inputImage"];
			[monochromeFilter setValue:[CIColor colorWithRed:0.75 green:0.75 blue:0.75] forKey:@"inputColor"];
			[monochromeFilter setValue:[NSNumber numberWithFloat:1.0] forKey:@"inputIntensity"];
			CIImage *monochromeImage = [monochromeFilter valueForKey:@"outputImage"];
			if (aFlag) {
				CIFilter *invertFilter = [CIFilter filterWithName:@"CIColorInvert"];
				[invertFilter setDefaults];
				[invertFilter setValue:[monochromeFilter valueForKey:@"outputImage"] forKey:@"inputImage"];
				monochromeImage = [invertFilter valueForKey:@"outputImage"];
			}

			CIFilter *compositingFilter = [CIFilter filterWithName:@"CIMultiplyCompositing"];
			[compositingFilter setDefaults];
			[compositingFilter setValue:[colorGenerator valueForKey:@"outputImage"] forKey:@"inputImage"];
			[compositingFilter setValue:monochromeImage forKey:@"inputBackgroundImage"];

			CIImage *outputImage = [compositingFilter valueForKey:@"outputImage"];

			[outputImage drawInRect:dstRect fromRect:(NSRect)outputImage.extent operation:NSCompositeCopy fraction:1.0];

			return YES;
		}];

    	return tintedImage;
    } else {
    	return [self copy];
    }
}


- (NSImage *)dimmedImage {

	NSImage *resultImage = [NSImage imageWithSize:self.size flipped:self.isFlipped drawingHandler:^BOOL(NSRect dstRect) {
		NSGraphicsContext *context = [NSGraphicsContext currentContext];
		[context setImageInterpolation:NSImageInterpolationHigh];
		[[NSColor clearColor] set];
		[[NSBezierPath bezierPathWithRect:dstRect] fill];
		[self drawInRect:dstRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:0.5 respectFlipped:YES hints:nil];
		return YES;
	}];
	return resultImage;
}


@end
