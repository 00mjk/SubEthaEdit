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
	locationCache:(unsigned)locationCache 
	utf8LocationCache:(unsigned)utf8LocationCache 
	utf8TerminalOfLastMatch:(unsigned)utf8TerminalOfLastMatch 
	parentMatch:(OGRegularExpressionMatch*)parentMatch 
{
#ifdef DEBUG_OGRE
	NSLog(@"-initWithRegion: of OGRegularExpressionMatch");
#endif
	self = [super init];
	if (self) {
		// parent (A OGRegularExpression instance has a region containing _region)
		_parentMatch = [parentMatch retain];
		
		// match result region
		_region = region;	// retain
	
		// ������
		_enumerator = [enumerator retain];
		
		// ���ɕ������Ă���NSString�̒�����UTF8String�̒����̑Ή�
		_locationCache = locationCache;
		_utf8LocationCache = utf8LocationCache;		// >= _region->beg[0]���K�v����
		// �Ō�Ƀ}�b�`����������̏I�[�ʒu
		_utf8TerminalOfLastMatch = utf8TerminalOfLastMatch;
		// �}�b�`��������
		_index = anIndex;
		
		// �p�ɂɗ��p������̂̓L���b�V������B�ێ��͂��Ȃ��B
		// �����Ώە�����
		_swappedTargetString     = [_enumerator swappedTargetString];
		_utf8SwappedTargetString = [_enumerator utf8SwappedTargetString];
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
	NSLog(@"-dealloc of OGRegularExpressionMatch");
#endif
	// ���
	[_enumerator release];

	// ���[�W�����̊J��
	if (_parentMatch != nil) {
		[_parentMatch release];
	} else if (_region != NULL) {
		onig_region_free(_region, 1 /* free self */);
	}
	
	[super dealloc];
}


@end
