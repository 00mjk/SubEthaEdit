/*
 * Name: OGRegularExpressionEnumeratorPrivate.m
 * Project: OgreKit
 *
 * Creation Date: Sep 03 2003
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


@implementation OGRegularExpressionEnumerator (Private)

- (id) initWithSwappedString:(NSString*)swappedTargetString 
	options:(unsigned)searchOptions 
	range:(NSRange)searchRange 
	regularExpression:(OGRegularExpression*)regex
{
#ifdef DEBUG_OGRE
	NSLog(@"-initWithSwappedString: of %@", [self className]);
#endif
	self = [super init];
	if (self) {
		// �����Ώە������ێ�
		// target string��UTF16������ɕϊ�����B
		_swappedTargetString = [swappedTargetString retain];
        _lengthOfSwappedTargetString = [_swappedTargetString length];
        
        _UTF16SwappedTargetString = (unichar*)NSZoneMalloc([self zone], sizeof(unichar) * _lengthOfSwappedTargetString);
        if (_UTF16SwappedTargetString == NULL) {
            // ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
            [self release];
            [NSException raise:OgreEnumeratorException format:@"fail to allocate a memory"];
        }
        [_swappedTargetString getCharacters:_UTF16SwappedTargetString range:NSMakeRange(0, _lengthOfSwappedTargetString)];
            
        /* DEBUG 
        {
            NSLog(@"TargetString: '%@'", _swappedTargetString);
            int     i, count = _lengthOfSwappedTargetString;
            unichar *utf16Chars = _UTF16SwappedTargetString;
            for (i = 0; i < count; i++) {
                NSLog(@"UTF16: %04x", *(utf16Chars + i));
            }
        }*/
        
		// �����͈�
		_searchRange = searchRange;
		
		// ���K�\���I�u�W�F�N�g��ێ�
		_regex = [regex retain];
		
		// �����I�v�V����
		_searchOptions = searchOptions;
		
		/* �����l�ݒ� */
		// �Ō�Ƀ}�b�`����������̏I�[�ʒu
		// �����l 0
		// �l >=  0 �I�[�ʒu
		// �l == -1 �}�b�`�I��
		_terminalOfLastMatch = 0;
		
		// �}�b�`�J�n�ʒu
		_startLocation = 0;
	
		// �O��̃}�b�`���󕶎��񂾂������ǂ���
		_isLastMatchEmpty = NO;
		
		// �}�b�`������
		_numberOfMatches = 0;
	}
	
	return self;
}

- (void)dealloc
{
#ifdef DEBUG_OGRE
	NSLog(@"-dealloc of %@", [self className]);
#endif
	// �J��
	[_regex release];
	NSZoneFree([self zone], _UTF16SwappedTargetString);
	[_swappedTargetString release];
	
	[super dealloc];
}

/* accessors */
// private
- (void)_setTerminalOfLastMatch:(int)location
{
	_terminalOfLastMatch = location;
}

- (void)_setIsLastMatchEmpty:(BOOL)yesOrNo
{
	_isLastMatchEmpty = yesOrNo;
}

- (void)_setStartLocation:(unsigned)location
{
	_startLocation = location;
}

- (void)_setNumberOfMatches:(unsigned)aNumber
{
	_numberOfMatches = aNumber;
}

- (OGRegularExpression*)regularExpression
{
	return _regex;
}

- (void)setRegularExpression:(OGRegularExpression*)regularExpression
{
	[regularExpression retain];
	[_regex release];
	_regex = regularExpression;
}

// public?
- (NSString*)swappedTargetString
{
	return _swappedTargetString;
}

- (unichar*)UTF16SwappedTargetString
{
	return _UTF16SwappedTargetString;
}

- (NSRange)searchRange
{
	return _searchRange;
}


@end
