/*
 * Name: OGRegularExpressionEnumerator.m
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
#import <OgreKit/OGRegularExpressionMatch.h>
#import <OgreKit/OGRegularExpressionEnumerator.h>
#import <OgreKit/OGRegularExpressionPrivate.h>
#import <OgreKit/OGRegularExpressionMatchPrivate.h>
#import <OgreKit/OGRegularExpressionEnumeratorPrivate.h>


// ���g��encoding/decoding���邽�߂�key
static NSString	* const OgreRegexKey               = @"OgreEnumeratorRegularExpression";
static NSString	* const OgreSwappedTargetStringKey = @"OgreEnumeratorSwappedTargetString";
static NSString	* const OgreStartOffsetKey         = @"OgreEnumeratorStartOffset";
static NSString	* const OgreStartLocationKey       = @"OgreEnumeratorStartLocation";
static NSString	* const OgreTerminalOfLastMatchKey = @"OgreEnumeratorTerminalOfLastMatch";
static NSString	* const OgreIsLastMatchEmptyKey    = @"OgreEnumeratorIsLastMatchEmpty";
static NSString	* const OgreOptionsKey             = @"OgreEnumeratorOptions";
static NSString	* const OgreNumberOfMatchesKey     = @"OgreEnumeratorNumberOfMatches";

NSString	* const OgreEnumeratorException = @"OGRegularExpressionEnumeratorException";

@implementation OGRegularExpressionEnumerator

// ��������
- (id)nextObject
{
	int					r;
	unsigned char		*start, *range, *end;
	OnigRegion			*region;
	id					match = nil;
	unsigned			utf8charlen = 0;
	
	/* �S�ʓI�ɏ��������\�� */
	if ( _utf8TerminalOfLastMatch == -1 ) {
		// �}�b�`�I��
		return nil;
	}
	
	start = _utf8SwappedTargetString + _utf8StartLocation;	// search start address of target string
	end = _utf8SwappedTargetString + _utf8lengthOfSwappedTargetString;	// terminate address of target string
	range = end;	// search terminate address of target string
	if (start > range) {
		// ����ȏ㌟���͈͂̂Ȃ��ꍇ
		_utf8TerminalOfLastMatch = -1;
		return nil;
	}
	
	// compile�I�v�V����(OgreFindNotEmptyOption��ʂɈ���)
	BOOL	findNotEmpty;
	if (([_regex options] & OgreFindNotEmptyOption) == 0) {
		findNotEmpty = NO;
	} else {
		findNotEmpty = YES;
	}
	
	// search�I�v�V����(OgreFindEmptyOption��ʂɈ���)
	BOOL		findEmpty;
	unsigned	searchOptions;
	if ((_searchOptions & OgreFindEmptyOption) == 0) {
		findEmpty = NO;
		searchOptions = _searchOptions;
	} else {
		findEmpty = YES;
		searchOptions = _searchOptions & ~OgreFindEmptyOption;  // turn off OgreFindEmptyOption
	}
	
	// region�̍쐬
	region = onig_region_new();
	if ( region == NULL ) {
		// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
		[NSException raise:OgreEnumeratorException format:@"fail to create a region"];
	}
	
	/* ���� */
	regex_t*	regexBuffer = [_regex patternBuffer];
	
	int	counterOfAutorelease = 0;
	NSAutoreleasePool	*pool = [[NSAutoreleasePool alloc] init];
	
	if (!findNotEmpty) {
		/* �󕶎���ւ̃}�b�`�������ꍇ */
		r = onig_search(regexBuffer, _utf8SwappedTargetString, end, start, range, region, searchOptions);
		
		// OgreFindEmptyOption���w�肳��Ă��Ȃ��ꍇ�ŁA
		// �O��󕶎���ȊO�Ƀ}�b�`���āA����󕶎���Ƀ}�b�`�����ꍇ�A1�������炵�Ă���1�x�}�b�`�����݂�B
		if (!findEmpty && (!_isLastMatchEmpty) && (r >= 0) && (region->beg[0] == region->end[0]) && (_startLocation > 0)) {
			if (start < range) {
				utf8charlen = Ogre_utf8charlen(_utf8SwappedTargetString + _utf8StartLocation);
				_utf8StartLocation += utf8charlen;	// UTF8String��1�����i�߂�
				start = _utf8SwappedTargetString + _utf8StartLocation;
				_startLocation += ((utf8charlen >= 4)? 2 : 1);	// NSString��1�����i�߂� (4-octet�ȏ�̏ꍇ�͂Ȃ���2����(2�����ڂ͋󕶎�)�i�߂Ȃ���΂Ȃ�Ȃ�)
				r = onig_search(regexBuffer, _utf8SwappedTargetString, end, start, range, region, searchOptions);
			} else {
				r = ONIG_MISMATCH;
			}
		}
		
	} else {
		/* �󕶎���ւ̃}�b�`�������Ȃ��ꍇ */
		while (TRUE) {
			r = onig_search(regexBuffer, _utf8SwappedTargetString, end, start, range, region, searchOptions);
			if ((r >= 0) && (region->beg[0] == region->end[0]) && (start < range)) {
				// �󕶎���Ƀ}�b�`�����ꍇ
				utf8charlen = Ogre_utf8charlen(_utf8SwappedTargetString + _utf8StartLocation);
				_utf8StartLocation += utf8charlen;	// UTF8String��1�����i�߂�
				start = _utf8SwappedTargetString + _utf8StartLocation;
				_startLocation += ((utf8charlen >= 4)? 2 : 1);	// NSString��1�����i�߂� (4-octet�̏ꍇ�͂Ȃ���2����(2�����ڂ͋󕶎�)�i�߂Ȃ���΂Ȃ�Ȃ�)
			} else {
				// ����ȏ�i�߂Ȃ��ꍇ�E�󕶎���ȊO�Ƀ}�b�`�����ꍇ�E�}�b�`�Ɏ��s�����ꍇ
				break;
			}
		
			counterOfAutorelease++;
			if (counterOfAutorelease % 100 == 0) {
				[pool release];
				pool = [[NSAutoreleasePool alloc] init];
			}
		}
		if ((r >= 0) && (region->beg[0] == region->end[0]) && (start >= range)) {
			// �Ō�ɋ󕶎���Ƀ}�b�`�����ꍇ�B�~�X�}�b�`�����Ƃ���B
			r = ONIG_MISMATCH;
		}
	}
	
	[pool release];
	
	if (r >= 0) {
		// �}�b�`�����ꍇ
		// match�I�u�W�F�N�g�̍쐬
		match = [[[OGRegularExpressionMatch allocWithZone:[self zone]] 
				initWithRegion: region 
				index: _numberOfMatches
				enumerator: self
				locationCache: _startLocation
				utf8LocationCache: _utf8StartLocation
				utf8TerminalOfLastMatch: _utf8TerminalOfLastMatch
				parentMatch:nil 
			] autorelease];
		
		_numberOfMatches++;	// �}�b�`���𑝉�
		
		/* �}�b�`����������̏I�[�ʒu */
		if ( (r == _utf8lengthOfSwappedTargetString) && (r == region->end[0]) ) {
			_utf8TerminalOfLastMatch = -1;	// �Ō�ɋ󕶎���Ƀ}�b�`�����ꍇ�́A����ȏ�}�b�`���Ȃ��B
			_isLastMatchEmpty = YES;	// ����Ȃ����낤���ǈꉞ�B

			return match;
		} else {
			_utf8TerminalOfLastMatch = region->end[0];	// �Ō�Ƀ}�b�`����������̏I�[�ʒu
		}

		/* NSString �� UTF8String �ł̎���̃}�b�`�J�n�ʒu�����߂� */
		_startLocation += Ogre_utf8strlen(_utf8SwappedTargetString + _utf8StartLocation, _utf8SwappedTargetString + _utf8TerminalOfLastMatch);
		
		/* UTF8String�ł̊J�n�ʒu */
		if (r == region->end[0]) {
			// �󕶎���Ƀ}�b�`�����ꍇ�A����̃}�b�`�J�n�ʒu��1������ɐi�߂�B
			_isLastMatchEmpty = YES;
			utf8charlen = Ogre_utf8charlen(_utf8SwappedTargetString + _utf8TerminalOfLastMatch);
			_utf8StartLocation = _utf8TerminalOfLastMatch + utf8charlen;
			_startLocation += ((utf8charlen >= 4)? 2 : 1);  // NSString��1�����i�߂� (4-octet�̏ꍇ�͂Ȃ���2����(2�����ڂ͋󕶎�)�i�߂Ȃ���΂Ȃ�Ȃ�)
		} else {
			// ��łȂ������ꍇ�͐i�߂Ȃ��B
			_isLastMatchEmpty = NO;
			_utf8StartLocation = _utf8TerminalOfLastMatch;
		}
		
		return match;
	}
	
	onig_region_free(region, 1 /* free self */);	// �}�b�`���Ȃ������������region���J���B
	
	if (r == ONIG_MISMATCH) {
		// �}�b�`���Ȃ������ꍇ
		_utf8TerminalOfLastMatch = -1;
	} else {
		// �G���[�B��O�𔭐�������B
		char s[ONIG_MAX_ERROR_MESSAGE_LEN];
		onig_error_code_to_str(s, r);
		[NSException raise:OgreEnumeratorException format:@"%s", s];
	}
	return nil;	// �}�b�`���Ȃ������ꍇ
}

- (NSArray*)allObjects
{	
#ifdef DEBUG_OGRE
	NSLog(@"-allObjects of OGRegularExpressionEnumerator");
#endif

	NSMutableArray	*matchArray = [NSMutableArray arrayWithCapacity:10];

	int			orgUtf8TerminalOfLastMatch = _utf8TerminalOfLastMatch;
	BOOL		orgIsLastMatchEmpty = _isLastMatchEmpty;
	unsigned	orgStartLocation = _startLocation;
	unsigned	orgUtf8StartLocation = _utf8StartLocation;
	unsigned	orgNumberOfMatches = _numberOfMatches;
	
	_utf8TerminalOfLastMatch = 0;
	_isLastMatchEmpty = NO;
	_startLocation = 0;
	_utf8StartLocation = 0;
	_numberOfMatches = 0;
			
	NSAutoreleasePool   *pool = [[NSAutoreleasePool alloc] init];
	OGRegularExpressionMatch	*match;
	int matches = 0;
	while ( (match = [self nextObject]) != nil ) {
		[matchArray addObject:match];
		matches++;
		if ((matches % 100) == 0) {
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
		}
	}
	[pool release];
	
	_utf8TerminalOfLastMatch = orgUtf8TerminalOfLastMatch;
	_isLastMatchEmpty = orgIsLastMatchEmpty;
	_startLocation = orgStartLocation;
	_utf8StartLocation = orgUtf8StartLocation;
	_numberOfMatches = orgNumberOfMatches;

	if (matches == 0) {
		// not found
		return nil;
	} else {
		// found something
		return matchArray;
	}
}

// NSCoding protocols
- (void)encodeWithCoder:(NSCoder*)encoder
{
#ifdef DEBUG_OGRE
	NSLog(@"-encodeWithCoder: of OGRegularExpressionEnumerator");
#endif
	//[super encodeWithCoder:encoder]; NSObject does ont respond to method encodeWithCoder:
	
	//OGRegularExpression	*_regex;							// ���K�\���I�u�W�F�N�g
	//NSString				*_swappedTargetString;				// �����Ώە�����B\������ւ���Ă���(��������)�̂Œ���
	//(unsigned char		*_utf8SwappedTargetString;)			// UTF8�ł̌����Ώە�����
	//(			_utf8lengthOfSwappedTargetString;)	// strlen([_swappedTargetString UTF8String])
	//NSRange				_searchRange;						// �����͈�
	//			_searchOptions;						// �����I�v�V����
	//int					_utf8TerminalOfLastMatch;			// �O��Ƀ}�b�`����������̏I�[�ʒu (_region->end[0])
	//			_startLocation;						// �}�b�`�J�n�ʒu
	//(			_utf8StartLocation;)				// UTF8�ł̃}�b�`�J�n�ʒu
	//BOOL					_isLastMatchEmpty;					// �O��̃}�b�`���󕶎��񂾂������ǂ���

    if ([encoder allowsKeyedCoding]) {
		[encoder encodeObject: _regex forKey: OgreRegexKey];
		[encoder encodeObject: _swappedTargetString forKey: OgreSwappedTargetStringKey];	// [self targetString]�ł͂Ȃ��B
		[encoder encodeObject: [NSNumber numberWithUnsignedInt:_searchRange.location] forKey: OgreStartOffsetKey];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt:_searchOptions] forKey: OgreOptionsKey];
		[encoder encodeObject: [NSNumber numberWithInt:_utf8TerminalOfLastMatch] forKey: OgreTerminalOfLastMatchKey];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt:_startLocation] forKey: OgreStartLocationKey];
		[encoder encodeObject: [NSNumber numberWithBool:_isLastMatchEmpty] forKey: OgreIsLastMatchEmptyKey];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt:_numberOfMatches] forKey: OgreNumberOfMatchesKey];
	} else {
		[encoder encodeObject: _regex];
		[encoder encodeObject: _swappedTargetString];	// [self targetString]�ł͂Ȃ��B
		[encoder encodeObject: [NSNumber numberWithUnsignedInt:_searchRange.location]];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt:_searchOptions]];
		[encoder encodeObject: [NSNumber numberWithInt:_utf8TerminalOfLastMatch]];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt:_startLocation]];
		[encoder encodeObject: [NSNumber numberWithBool:_isLastMatchEmpty]];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt:_numberOfMatches]];
	}
}

- (id)initWithCoder:(NSCoder*)decoder
{
#ifdef DEBUG_OGRE
	NSLog(@"-initWithCoder: of OGRegularExpressionEnumerator");
#endif
	self = [super init];	// NSObject does ont respond to method initWithCoder:
	if (self == nil) return nil;
	
	id		anObject;	
	BOOL	allowsKeyedCoding = [decoder allowsKeyedCoding];


	//OGRegularExpression	*_regex;							// ���K�\���I�u�W�F�N�g
    if (allowsKeyedCoding) {
		_regex = [[decoder decodeObjectForKey: OgreRegexKey] retain];
	} else {
		_regex = [[decoder decodeObject] retain];
	}
	if (_regex == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreEnumeratorException format:@"fail to decode"];
	}
	
	
	//NSString			*_swappedTargetString;				// �����Ώە�����B\������ւ���Ă���(��������)�̂Œ���
	//unsigned char		*_utf8SwappedTargetString;			// UTF8�ł̌����Ώە�����
	//		_utf8lengthOfSwappedTargetString;	// strlen([_swappedTargetString UTF8String])
    if (allowsKeyedCoding) {
		_swappedTargetString = [[decoder decodeObjectForKey: OgreSwappedTargetStringKey] retain];	// [self targetString]�ł͂Ȃ��B
	} else {
		_swappedTargetString = [[decoder decodeObject] retain];
	}
	if (_swappedTargetString == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreEnumeratorException format:@"fail to decode"];
	}
	_utf8SwappedTargetString = (unsigned char*)[_swappedTargetString UTF8String];
	_utf8lengthOfSwappedTargetString = strlen(_utf8SwappedTargetString);
	
	
	// NSRange				_searchRange;						// �����͈�
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreStartOffsetKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreEnumeratorException format:@"fail to decode"];
	}
	_searchRange.location = [anObject unsignedIntValue];
	_searchRange.length = [_swappedTargetString length];
	
	
	
	// 	_searchOptions;			// �����I�v�V����
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreOptionsKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreEnumeratorException format:@"fail to decode"];
	}
	_searchOptions = [anObject unsignedIntValue];
	
	
	// int	_utf8TerminalOfLastMatch;	// �O��Ƀ}�b�`����������̏I�[�ʒu (_region->end[0])
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreTerminalOfLastMatchKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreEnumeratorException format:@"fail to decode"];
	}
	_utf8TerminalOfLastMatch = [anObject intValue];
	
	
	//			_startLocation;						// �}�b�`�J�n�ʒu
	//			_utf8StartLocation;					// UTF8�ł̃}�b�`�J�n�ʒu
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreStartLocationKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreEnumeratorException format:@"fail to decode"];
	}
	_startLocation = [anObject unsignedIntValue];
	_utf8StartLocation = strlen([[_swappedTargetString substringWithRange:NSMakeRange(0, _startLocation)] UTF8String]);
	

	//BOOL				_isLastMatchEmpty;					// �O��̃}�b�`���󕶎��񂾂������ǂ���
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreIsLastMatchEmptyKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreEnumeratorException format:@"fail to decode"];
	}
	_isLastMatchEmpty = [anObject boolValue];
	
	
	//	unsigned			_numberOfMatches;					// �}�b�`������
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreNumberOfMatchesKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreEnumeratorException format:@"fail to decode"];
	}
	_numberOfMatches = [anObject unsignedIntValue];
	
	
	return self;
}


// NSCopying protocol
- (id)copyWithZone:(NSZone*)zone
{
#ifdef DEBUG_OGRE
	NSLog(@"-copyWithZone: of OGRegularExpressionEnumerator");
#endif
	id	newObject = [[[self class] allocWithZone:zone] 
			initWithSwappedString: _swappedTargetString 
			options: _searchOptions
			range: _searchRange 
			regularExpression: _regex];
			
	// �l�̃Z�b�g
	[newObject _setUtf8TerminalOfLastMatch: _utf8TerminalOfLastMatch];
	[newObject _setIsLastMatchEmpty: _isLastMatchEmpty];
	[newObject _setStartLocation: _startLocation];
	[newObject _setUtf8StartLocation: _utf8StartLocation];
	[newObject _setNumberOfMatches: _numberOfMatches];

	return newObject;
}

// description
- (NSString*)description
{
	NSDictionary	*dictionary = [NSDictionary 
		dictionaryWithObjects: [NSArray arrayWithObjects: 
			_regex, 	// ���K�\���I�u�W�F�N�g
			[[_regex class] swapBackslashInString:_swappedTargetString forCharacter:[_regex escapeCharacter]],
			[NSString stringWithFormat:@"(%d, %d)", _searchRange.location, _searchRange.length], 	// �����͈�
			[[_regex class] stringsForOptions:_searchOptions], 	// �����I�v�V����
			[NSNumber numberWithInt:Ogre_utf8strlen(_utf8SwappedTargetString, _utf8SwappedTargetString + _utf8TerminalOfLastMatch)],	// �O��Ƀ}�b�`����������̏I�[�ʒu���O�̕�����̒���
			[NSNumber numberWithUnsignedInt:_startLocation], 	// �}�b�`�J�n�ʒu
			(_isLastMatchEmpty? @"YES" : @"NO"), 	// �O��̃}�b�`���󕶎��񂾂������ǂ���
			[NSNumber numberWithUnsignedInt:_numberOfMatches], 
			nil]
		forKeys:[NSArray arrayWithObjects: 
			@"Regular Expression", 
				@"Target String", 
			@"Search Range", 
			@"Options", 
			@"Terminal of the Last Match", 
			@"Location of the Next Search Start", 
			@"Was the Last Match Empty", 
			@"Number Of Matches", 
			nil]
		];
		
	return [dictionary description];
}

@end
