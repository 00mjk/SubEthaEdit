/*
 * Name: OGRegularExpressionMatchPrivate.m
 * Project: OgreKit
 *
 * Creation Date: Sep 01 2003
 * Author: Isao Sonobe <sonobe@gauge.scphys.kyoto-u.ac.jp>
 * Copyright: Copyright (c) 2003 Isao Sonobe, All rights reserved.
 * License: OgreKit License
 *
 * Encoding: UTF8
 * Tabsize: 4
 */

#import <OgreKit/OGRegularExpression.h>
#import <OgreKit/OGRegularExpressionPrivate.h>
#import <OgreKit/OGRegularExpressionMatch.h>
#import <OgreKit/OGRegularExpressionMatchPrivate.h>
#import <OgreKit/OGRegularExpressionEnumerator.h>
#import <OgreKit/OGRegularExpressionEnumeratorPrivate.h>


@implementation OGRegularExpressionMatch (Private)

/* ����J���\�b�h */
- (id)initWithRegion:(OnigRegion*)region 
	index:(unsigned)anIndex
	enumerator:(OGRegularExpressionEnumerator*)enumerator
	terminalOfLastMatch:(unsigned)terminalOfLastMatch 
{
#ifdef DEBUG_OGRE
	NSLog(@"-initWithRegion: of %@", [self className]);
#endif
	self = [super init];
	if (self) {
		// match result region
		_region = region;	// retain
	
		// ������
		_enumerator = [enumerator retain];
		
		// �Ō�Ƀ}�b�`����������̏I�[�ʒu
		_terminalOfLastMatch = terminalOfLastMatch;
		// �}�b�`��������
		_index = anIndex;
		
		// �p�ɂɗ��p������̂̓L���b�V������B�ێ��͂��Ȃ��B
		// �����Ώە�����
		_swappedTargetString     = [_enumerator swappedTargetString];
		// �����͈�
		NSRange	searchRange = [_enumerator searchRange];
		_searchRange.location = searchRange.location;
		_searchRange.length   = searchRange.length;
		// ���\������ێ�
		_escapeCharacter = [[_enumerator regularExpression] escapeCharacter];
	}
	
	return self;
}

- (void)dealloc
{
#ifdef DEBUG_OGRE
	NSLog(@"-dealloc of %@", [self className]);
#endif
	// ���
	[_enumerator release];

	// ���[�W�����̊J��
	if (_region != NULL) {
		onig_region_free(_region, 1 /* free self */);
	}
	
	[super dealloc];
}

- (NSString*)_swappedTargetString
{
    return _swappedTargetString;
}

- (NSString*)_escapeCharacter
{
    return _escapeCharacter;
}

- (NSRange)_searchRange
{
    return _searchRange;
}

- (OnigRegion*)_region
{
    return _region;
}


@end
