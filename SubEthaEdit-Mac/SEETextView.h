//
//  SEETextView.h
//  SubEthaEdit
//
//  Created by Dominik Wagner on Tue Apr 06 2004.
//  Copyright (c) 2004-2006 TheCodingMonkeys. All rights reserved.
//

#import <AppKit/AppKit.h>

@class PlainTextEditor; 

@interface SEETextView : NSTextView {
    BOOL I_isDragTarget;
    struct {
        BOOL shouldCheckCompleteStart;
        BOOL autoCompleteInProgress;
        BOOL isPasting;
        BOOL isDraggingText;
        BOOL isDoingUglyHack;
    } I_flags;
    float I_pageGuidePosition;
}

@property (nonatomic, weak) PlainTextEditor *editor;

- (id)delegate;

+ (void)setDefaultMenu:(NSMenu *)aMenu;
- (void)setPageGuidePosition:(float)aPosition;
- (BOOL)isPasting;

- (IBAction)foldTextSelection:(id)aSender;

/*! @returns an Array for the search scope ranges if any are set. if none are set returns the full range for the fulltextstorage */
@property (nonatomic, readonly) NSArray *searchScopeRanges;


#pragma mark Folding Related Methods
- (void)scrollFullRangeToVisible:(NSRange)aRange;
- (IBAction)foldCurrentBlock:(id)aSender;
- (IBAction)foldTextSelection:(id)aSender;
- (IBAction)unfoldCurrentBlock:(id)aSender;
- (IBAction)foldAllCommentBlocks:(id)aSender;
- (IBAction)foldAllTopLevelBlocks:(id)aSender;
- (IBAction)foldAllBlocksAtTagLevel:(id)aSender;

- (void)adjustContainerInsetToScrollView;

@end

@interface NSObject (TextViewDelegateMethods) 
- (void)textView:(NSTextView *)aTextView mouseDidGoDown:(NSEvent *)aEvent;
- (NSDictionary *)blockeditAttributesForTextView:(NSTextView *)aTextView;
- (void)textViewDidChangeSpellCheckingSetting:(SEETextView *)aTextView;
- (void)textView:(SEETextView *)aTextView didFinishAutocompleteByInsertingCompletion:(NSString *)aWord forPartialWordRange:(NSRange)aCharRange movement:(int)aMovement;
- (void)textViewWillStartAutocomplete:(SEETextView *)aTextView;
- (void)textViewContextMenuNeedsUpdate:(NSMenu *)aContextMenu;
@end
