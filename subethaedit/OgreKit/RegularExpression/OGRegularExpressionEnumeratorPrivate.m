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
	NSLog(@"-initWithSwappedString: of OGRegularExpressionEnumerator");
#endif
	self = [super init];
	if (self) {
		// �����Ώە������ێ�
		// target string��UTF8������ɕϊ�����B
		_swappedTargetString = [swappedTargetString retain];
		
		// duplicate [_swappedTargetString UTF8String]
		unsigned char   *tmpUTF8String = (unsigned char*)[_swappedTargetString UTF8String];
		_utf8lengthOfSwappedTargetString = strlen(tmpUTF8String);
		_utf8SwappedTargetString = (unsigned char*)NSZoneMalloc([self zone], sizeof(unsigned char) * (_utf8lengthOfSwappedTargetString + 1));
		if (_utf8SwappedTargetString == NULL) {
			// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
			[NSException raise:OgreEnumeratorException format:@"fail to duplicate a utf8SwappedTargetString"];
		}
		memcpy(_utf8SwappedTargetString, tmpUTF8String, _utf8lengthOfSwappedTargetString + 1);
		
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
		_utf8TerminalOfLastMatch = 0;
		
		// �}�b�`�J�n�ʒu
		_startLocation = 0;
		_utf8StartLocation = 0;
	
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
	NSLog(@"-dealloc of OGRegularExpressionEnumerator");
#endif
	// �J��
	[_regex release];
	[_swappedTargetString release];
	
	[super dealloc];
}

/* accessors */
// private
- (void)_setUtf8TerminalOfLastMatch:(int)location
{
	_utf8TerminalOfLastMatch = location;
}

- (void)_setIsLastMatchEmpty:(BOOL)yesOrNo
{
	_isLastMatchEmpty = yesOrNo;
}

- (void)_setStartLocation:(unsigned)location
{
	_startLocation = location;
}

- (void)_setUtf8StartLocation:(unsigned)location
{
	_utf8StartLocation = location;
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

- (unsigned char*)utf8SwappedTargetString
{
	return _utf8SwappedTargetString;
}

- (NSRange)searchRange
{
	return _searchRange;
}


// �j��I����
- (NSString*)input
{
	NSString	*aCharacter;
	unsigned	utf8charlen;
	
	if ((_utf8TerminalOfLastMatch == -1) || (_startLocation > _searchRange.length) || (!_isLastMatchEmpty && _startLocation == _searchRange.length)) {
		// �G���[�B��O�𔭐�������B
		[NSException raise:OgreEnumeratorException format:@"out of range"];
	}
	
	if (!_isLastMatchEmpty) {
		// 1�����i�߂�B
		utf8charlen = Ogre_utf8charlen(_utf8SwappedTargetString + _utf8StartLocation);
		_utf8StartLocation += utf8charlen;
		_startLocation += ((utf8charlen >= 4)? 2 : 1);   // NSString��1�����i�߂� (4-octet�̏ꍇ�͂Ȃ���2����(2�����ڂ͋󕶎�)�i�߂Ȃ���΂Ȃ�Ȃ�)
	}
	utf8charlen = Ogre_utf8prevcharlen(_utf8SwappedTargetString + _utf8StartLocation);
	aCharacter = [[_regex class] swapBackslashInString:[_swappedTargetString substringWithRange:NSMakeRange(_searchRange.location + _startLocation - ((utf8charlen >= 4)? 2 : 1), ((utf8charlen >= 4)? 2 : 1))] forCharacter:[_regex escapeCharacter]];
	_isLastMatchEmpty = NO;
	_utf8TerminalOfLastMatch = _utf8StartLocation;
	
	return aCharacter;
}

- (void)less:(unsigned)aLength
{
	unsigned	i;
	unsigned	utf8charlen;

	if ((_utf8TerminalOfLastMatch == -1) || (_startLocation < aLength) || (_isLastMatchEmpty && _startLocation <= aLength)) {
		// �G���[�B��O�𔭐�������B
		[NSException raise:OgreEnumeratorException format:@"out of range"];
	}
	
	if (_isLastMatchEmpty) {
		// 1�����߂��B
		utf8charlen = Ogre_utf8prevcharlen(_utf8SwappedTargetString + _utf8TerminalOfLastMatch);
		_startLocation -= ((utf8charlen >= 4)? 2 : 1);  // NSString��1�����߂� (4-octet�̏ꍇ�͂Ȃ���2����(2�����ڂ͋󕶎�)�߂��Ȃ���΂Ȃ�Ȃ�)
	}
	
	// aLength�����߂��B
	for (i = 0; i < aLength; i++) {
		utf8charlen = Ogre_utf8prevcharlen(_utf8SwappedTargetString + _utf8TerminalOfLastMatch);
		_utf8TerminalOfLastMatch -= utf8charlen;
		_startLocation -= ((utf8charlen >= 4)? 2 : 1);  // NSString��1�����߂� (4-octet�̏ꍇ�͂Ȃ���2����(2�����ڂ͋󕶎�)�߂��Ȃ���΂Ȃ�Ȃ�)
	}
	_isLastMatchEmpty = NO;
	_utf8StartLocation = _utf8TerminalOfLastMatch;
}

@end
