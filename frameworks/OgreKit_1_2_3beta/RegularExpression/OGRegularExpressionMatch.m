/*
 * Name: OGRegularExpressionMatch.m
 * Project: OgreKit
 *
 * Creation Date: Aug 30 2003
 * Author: Isao Sonobe <sonobe@gauge.scphys.kyoto-u.ac.jp>
 * Copyright: Copyright (c) 2003 Isao Sonobe, All rights reserved.
 * License: OgreKit License
 *
 * Encoding: UTF8
 * Tabsize: 4
 */

#ifndef NOT_RUBY
#	define NOT_RUBY
#endif
#ifndef HAVE_CONFIG_H
#	define HAVE_CONFIG_H
#endif
#import <OgreKit/oniguruma.h>

#import <OgreKit/OGRegularExpression.h>
#import <OgreKit/OGRegularExpressionPrivate.h>
#import <OgreKit/OGRegularExpressionMatch.h>
#import <OgreKit/OGRegularExpressionMatchPrivate.h>
#import <OgreKit/OGRegularExpressionEnumerator.h>
#import <OgreKit/OGRegularExpressionEnumeratorPrivate.h>


NSString	* const OgreMatchException = @"OGRegularExpressionMatchException";

// ���g��encoding/decoding���邽�߂�key
static NSString	* const OgreRegionKey              = @"OgreMatchRegion";
static NSString	* const OgreEnumeratorKey          = @"OgreMatchEnumerator";
static NSString	* const OgreLocationCacheKey       = @"OgreMatchLocationCache";
static NSString	* const OgreUtf8LocationCacheKey   = @"OgreMatchUtf8LocationCache";
static NSString	* const OgreTerminalOfLastMatchKey = @"OgreMatchTerminalOfLastMatch";
static NSString	* const OgreIndexOfMatchKey        = @"OgreMatchIndexOfMatch";


inline unsigned Ogre_utf8strlen(unsigned char *const utf8string, unsigned char *const end)
{
	unsigned		length = 0;
	unsigned char	*utf8str = utf8string;
	unsigned char	byte;
	while ( ((byte = *utf8str) != 0) && (utf8str < end) ) {
		if ((byte & 0x80) == 0x00) {
			// 1 byte
			utf8str++;
			length++;
		} else if ((byte & 0xe0) == 0xc0) {
			// 2 bytes
			utf8str += 2;
			length++;
		} else if ((byte & 0xf0) == 0xe0) {
			// 3 bytes
			utf8str += 3;
			length++;
		} else if ((byte & 0xf8) == 0xf0) {
			// 4 bytes
			utf8str += 4;
			length += 2;	// ����! Cocoa�ł͂Ȃ�ł���Ȏd�l�Ȃ񂾂낤?
		} else if ((byte & 0xfc) == 0xf8) {
			// 5 bytes
			utf8str += 5;
			length += 2;	// ����! Cocoa�ł͂Ȃ�ł���Ȏd�l�Ȃ񂾂낤?
		} else if ((byte & 0xfe) == 0xfc) {
			// 6 bytes
			utf8str += 6;
			length += 2;	// ����! Cocoa�ł͂Ȃ�ł���Ȏd�l�Ȃ񂾂낤?
		} else {
			// subsequent byte in a multibyte code
			// �o���Ȃ��͂��Ȃ̂ŁA�o��������O���N�����B
			[NSException raise:OgreMatchException format:@"illegal byte code"];
		}
	}
	
	return length;
}

static NSArray *Ogre_arrayWithOnigRegion(OnigRegion *region)
{
	if (region == NULL) return nil;
	
	NSMutableArray	*regionArray = [NSMutableArray arrayWithCapacity:0];
	unsigned	i = 0, n = region->num_regs;
	OnigRegion  *cap;
	
	for( i = 0; i < n; i++ ) {
		if (ONIG_IS_CAPTURE_HISTORY_GROUP(region, i)) {
			cap = region->list[i];
		} else {
			cap = NULL;
		}
		
		[regionArray addObject: [NSArray arrayWithObjects:
			[NSNumber numberWithInt:region->beg[i]], 
			[NSNumber numberWithInt:region->end[i]], 
			Ogre_arrayWithOnigRegion(cap), 
			nil]];
	}
	
	return regionArray;
}

static OnigRegion *Ogre_onigRegionWithArray(NSArray *array)
{
	if (array == nil) return NULL;
	
	NSEnumerator	*enumerator = [array objectEnumerator];
	OnigRegion		*region = onig_region_new();
	if (region == NULL) {
		// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
		[NSException raise:OgreMatchException format:@"fail to memory allocation"];
	}
	unsigned		i = 0, j;
	NSArray			*anObject;
	BOOL			hasList = NO;
	int				r;
	
	r = onig_region_resize(region, [array count]);
	if (r != ONIG_NORMAL) {
		// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
		onig_region_free(region, 1);
		[NSException raise:OgreMatchException format:@"fail to memory allocation"];
	}
	region->list = NULL;
	while ( (anObject = [enumerator nextObject]) != nil ) {
		region->beg[i] = [[anObject objectAtIndex:0] unsignedIntValue];
		region->end[i] = [[anObject objectAtIndex:1] unsignedIntValue];
		if ([anObject count] > 2) {
			if (!hasList) {
				OnigRegion  **list = (OnigRegion**)malloc(sizeof(OnigRegion*) * (ONIG_MAX_CAPTURE_HISTORY_GROUP + 1));
				if (list == NULL) {
					// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
					onig_region_free(region, 1);
					[NSException raise:OgreMatchException format:@"fail to memory allocation"];
				}
				region->list = list;
				for (j = 0; j <= ONIG_MAX_CAPTURE_HISTORY_GROUP; j++) region->list[j] = (OnigRegion*)NULL;
				hasList = YES;
			}
			region->list[i] = Ogre_onigRegionWithArray((NSArray*)[anObject objectAtIndex:2]);
		}
		i++;
	}
	
	return region;
}

@implementation OGRegularExpressionMatch

// �}�b�`��������
- (unsigned)index
{
	return _index;
}

// ����������̐� + 1
- (unsigned)count
{
	return _region->num_regs;
}

// �}�b�`����������͈̔�
- (NSRange)rangeOfMatchedString
{
	return [self rangeOfSubstringAtIndex:0];
}

// �}�b�`���������� \&, \0
- (NSString*)matchedString
{
	return [self substringAtIndex:0];
}

// index�Ԗڂ�substring�͈̔�
- (NSRange)rangeOfSubstringAtIndex:(unsigned)index
{
	int	location, length;
	
	if ( (index >= _region->num_regs) || (_region->beg[index] == -1) ) {
		// index�Ԗڂ�substring�����݂��Ȃ��ꍇ
		return NSMakeRange(-1, 0);
	}
	//NSLog(@"%d %d-%d", index, _region->beg[index], _region->end[index]);
	
	/* substring�����O�̕�����̒����𓾂�B */
	location = _searchRange.location + _locationCache + Ogre_utf8strlen(_utf8SwappedTargetString + _utf8LocationCache, _utf8SwappedTargetString + _region->beg[index]);
	
	/* substring�̒����𓾂�B */
	length = Ogre_utf8strlen(_utf8SwappedTargetString + _region->beg[index], _utf8SwappedTargetString + _region->end[index]);
	
	return NSMakeRange(location, length);
}

// index�Ԗڂ�substring \n
- (NSString*)substringAtIndex:(unsigned)index
{
	// index�Ԗڂ�substring�����݂��Ȃ����ɂ� nil ��Ԃ�
	if ( (index >= _region->num_regs) || (_region->beg[index] == -1) ){
		return nil;
	}
	if (_region->end[index] == _region->beg[index]) {
		// substring����̏ꍇ
		return @"";
	}
	
	/* substring */
	unsigned char* utf8Substr;
	utf8Substr = malloc((_region->end[index] - _region->beg[index] + 1) * sizeof(unsigned char));
	if ( utf8Substr == NULL ) {
		// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
		[NSException raise:OgreMatchException format:@"fail to memory allocation"];
	}
	// �R�s�[
	memcpy( utf8Substr, _utf8SwappedTargetString + _region->beg[index], _region->end[index] - _region->beg[index]);
	*(utf8Substr + (_region->end[index] - _region->beg[index])) = 0;
	NSString *substr = [NSString stringWithUTF8String:utf8Substr];
	// �J��
	free(utf8Substr);
	
	// \�����ւ���
	return [OGRegularExpression swapBackslashInString:substr forCharacter:_escapeCharacter];
}

// �}�b�`�̑ΏۂɂȂ���������
- (NSString*)targetString
{
	// \�����ւ���
	return [OGRegularExpression swapBackslashInString:_swappedTargetString forCharacter:_escapeCharacter];
}

// �}�b�`�����������O�̕����� \`
- (NSString*)prematchString
{
	if (_region->beg[0] == -1) {
		// �}�b�`���������񂪑��݂��Ȃ��ꍇ
		return nil;
	}
	if (_region->beg[0] == _region->end[0]) {
		// �}�b�`�����������O�̕����񂪋�̏ꍇ
		return @"";
	}
	
	/* �}�b�`�����������O�̕����� */
	unsigned char* utf8Substr = malloc((_region->beg[0] + 1) * sizeof(unsigned char));
	if ( utf8Substr == NULL ) {
		// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
		[NSException raise:OgreMatchException format:@"fail to memory allocation"];
	}
	// �R�s�[
	memcpy( utf8Substr, _utf8SwappedTargetString, _region->beg[0] );
	*(utf8Substr + _region->beg[0]) = 0;
	NSString *substr = [NSString stringWithUTF8String: utf8Substr];
	// �J��
	free(utf8Substr);
	
	// \�����ւ���
	return [OGRegularExpression swapBackslashInString:substr forCharacter:_escapeCharacter];
}

// �}�b�`�����������O�̕����� \` �͈̔�
- (NSRange)rangeOfPrematchString
{
	if (_region->beg[0] == -1) {
		// �}�b�`���������񂪑��݂��Ȃ��ꍇ
		return NSMakeRange(-1,0);
	}

	/* �}�b�`�����������O�̕����� */
	unsigned length = _locationCache + Ogre_utf8strlen(_utf8SwappedTargetString + _utf8LocationCache, _utf8SwappedTargetString + _region->beg[0]);

	return NSMakeRange(_searchRange.location, length);
}

// �}�b�`�������������̕����� \'
- (NSString*)postmatchString
{
	if (_region->beg[0] == -1) {
		// �}�b�`�������������̕����񂪑��݂��Ȃ��ꍇ
		return nil;
	}

	unsigned	utf8strlen = strlen(_utf8SwappedTargetString);
	if (_region->end[0] == utf8strlen) {
		// �}�b�`�������������̕����񂪋�̏ꍇ
		return @"";
	}
	
	/* �}�b�`�������������̕����� */
	unsigned char* utf8Substr = malloc((utf8strlen - _region->end[0] + 1) * sizeof(unsigned char));
	if ( utf8Substr == NULL ) {
		// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
		[NSException raise:OgreMatchException format:@"fail to memory allocation"];
	}
	// �R�s�[
	memcpy( utf8Substr, _utf8SwappedTargetString + _region->end[0], utf8strlen - _region->end[0]);
	*(utf8Substr + (utf8strlen - _region->end[0])) = 0;
	NSString *substr = [NSString stringWithUTF8String:utf8Substr];
	// �J��
	free(utf8Substr);
	
	// \�����ւ���
	return [OGRegularExpression swapBackslashInString:substr forCharacter:_escapeCharacter];
}

// �}�b�`�������������̕����� \' �͈̔�
- (NSRange)rangeOfPostmatchString
{
	if (_region->beg[0] == -1) {
		// �}�b�`�������������̕����񂪑��݂��Ȃ��ꍇ
		return NSMakeRange(-1, 0);
	}
	
	unsigned	utf8strlen = strlen(_utf8SwappedTargetString);
	unsigned	length = Ogre_utf8strlen(_utf8SwappedTargetString + _region->end[0], _utf8SwappedTargetString + utf8strlen);
	
	return NSMakeRange(_searchRange.location + _searchRange.length - length, length);
}

// �}�b�`����������ƈ�O�Ƀ}�b�`����������̊Ԃ̕����� \-
- (NSString*)stringBetweenMatchAndLastMatch
{
	if (_region->beg[0] == -1) {
		// �}�b�`���������񂪑��݂��Ȃ��ꍇ
		return nil;
	}
	if (_region->beg[0] == _utf8TerminalOfLastMatch) {
		// �Ԃ̕����񂪋�̏ꍇ
		return @"";
	}
	
	/* �Ԃ̕����� */
	unsigned char* utf8Substr = malloc((_region->beg[0] - _utf8TerminalOfLastMatch + 1) * sizeof(unsigned char));
	if ( utf8Substr == NULL ) {
		// ���������m�ۂł��Ȃ������ꍇ�A��O�𔭐�������B
		[NSException raise:OgreMatchException format:@"fail to memory allocation"];
	}
	// �R�s�[
	memcpy( utf8Substr, _utf8SwappedTargetString + _utf8TerminalOfLastMatch, _region->beg[0] - _utf8TerminalOfLastMatch);
	*(utf8Substr + (_region->beg[0] - _utf8TerminalOfLastMatch)) = 0;
	NSString *substr = [NSString stringWithUTF8String: utf8Substr];
	// �J��
	free(utf8Substr);
	
	// \�����ւ���
	return [OGRegularExpression swapBackslashInString:substr forCharacter:_escapeCharacter];
}

// �}�b�`����������ƈ�O�Ƀ}�b�`����������̊Ԃ̕����� \- �͈̔�
- (NSRange)rangeOfStringBetweenMatchAndLastMatch
{
	if (_region->beg[0] == -1) {
		// �}�b�`���������񂪑��݂��Ȃ��ꍇ
		return NSMakeRange(-1,0);
	}

	unsigned length = Ogre_utf8strlen(_utf8SwappedTargetString + _utf8TerminalOfLastMatch, _utf8SwappedTargetString + _region->beg[0]);
	
	NSRange		rangeOfPrematchString = [self rangeOfPrematchString];
	return NSMakeRange(rangeOfPrematchString.location + rangeOfPrematchString.length - length, length);
}

// �Ō�Ƀ}�b�`�������������� \+
- (NSString*)lastMatchSubstring
{
	int i = [self count] - 1;
	while ( (i > 0) && (_region->beg[i] == -1) ) {
		i--;
	}
	if ( i == 0) {
		return nil;
	} else {
		return [self substringAtIndex:i];
	}
}

// �Ō�Ƀ}�b�`��������������͈̔� \+
- (NSRange)rangeOfLastMatchSubstring
{
	int i = [self count] - 1;
	while ( (i > 0) && (_region->beg[i] == -1) ) {
		i--;
	}
	if ( i == 0) {
		return NSMakeRange(-1,0);
	} else {
		return [self rangeOfSubstringAtIndex:i];
	}
}


// NSCoding protocols
- (void)encodeWithCoder:(NSCoder*)encoder
{
#ifdef DEBUG_OGRE
	NSLog(@"-encodeWithCoder: of OGRegularExpressionMatch");
#endif
	//[super encodeWithCoder:encoder]; NSObject does ont respond to method encodeWithCoder:
	
   if ([encoder allowsKeyedCoding]) {
		[encoder encodeObject: Ogre_arrayWithOnigRegion(_region) forKey: OgreRegionKey];
		[encoder encodeObject: _enumerator forKey: OgreEnumeratorKey];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt: _locationCache] forKey: OgreLocationCacheKey];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt: _utf8LocationCache] forKey: OgreUtf8LocationCacheKey];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt: _utf8TerminalOfLastMatch] forKey: OgreTerminalOfLastMatchKey];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt: _index] forKey: OgreIndexOfMatchKey];
	} else {
		[encoder encodeObject: Ogre_arrayWithOnigRegion(_region)];
		[encoder encodeObject: _enumerator];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt: _locationCache]];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt: _utf8LocationCache]];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt: _utf8TerminalOfLastMatch]];
		[encoder encodeObject: [NSNumber numberWithUnsignedInt: _index]];
	}
}

- (id)initWithCoder:(NSCoder*)decoder
{
#ifdef DEBUG_OGRE
	NSLog(@"-initWithCoder: of OGRegularExpressionMatch");
#endif
	self = [super init];	// NSObject does ont respond to method initWithCoder:
	if (self == nil) return nil;
	
	BOOL			allowsKeyedCoding = [decoder allowsKeyedCoding];
	
	// OnigRegion		*_region;				// match result region
	// /* match result region type */
	// struct re_registers {
	// int  allocated;
	// int  num_regs;
	// int* beg;
	// int* end;
	// /* extended */
	// struct re_registers** list; /* capture history. list[1]-list[31] */
	// };
	id  anObject;
	NSArray	*regionArray;
    if (allowsKeyedCoding) {
		regionArray = [decoder decodeObjectForKey: OgreRegionKey];
	} else {
		regionArray = [decoder decodeObject];
	}
	if (regionArray == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreMatchException format:@"fail to decode"];
	}
	_region = Ogre_onigRegionWithArray(regionArray);	
	
	// OGRegularExpressionEnumerator*	_enumerator;	// ������
    if (allowsKeyedCoding) {
		_enumerator = [[decoder decodeObjectForKey: OgreEnumeratorKey] retain];
	} else {
		_enumerator = [[decoder decodeObject] retain];
	}
	if (_enumerator == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreMatchException format:@"fail to decode"];
	}
	
	
	// unsigned		_locationCache;	// ���ɕ������Ă���NSString�̒�����UTF8String�̒����̑Ή�
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreLocationCacheKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreMatchException format:@"fail to decode"];
	}
	_locationCache = [anObject unsignedIntValue];
	
	
	// unsigned		_utf8LocationCache;
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreUtf8LocationCacheKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreMatchException format:@"fail to decode"];
	}
	_utf8LocationCache = [anObject unsignedIntValue];
	
	
	// unsigned	_utf8TerminalOfLastMatch;	// �O��Ƀ}�b�`����������̏I�[�ʒu (_region->end[0])
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreTerminalOfLastMatchKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreMatchException format:@"fail to decode"];
	}
	_utf8TerminalOfLastMatch = [anObject unsignedIntValue];

	
	// 	unsigned		_index;		// �}�b�`��������
    if (allowsKeyedCoding) {
		anObject = [decoder decodeObjectForKey: OgreIndexOfMatchKey];
	} else {
		anObject = [decoder decodeObject];
	}
	if (anObject == nil) {
		// �G���[�B��O�𔭐�������B
		[self release];
		[NSException raise:OgreMatchException format:@"fail to decode"];
	}
	_index = [anObject unsignedIntValue];

	
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
	// ������
	_parentMatch = nil;
	
	
	return self;
}

// NSCopying protocol
- (id)copyWithZone:(NSZone*)zone
{
#ifdef DEBUG_OGRE
	NSLog(@"-copyWithZone: of OGRegularExpressionMatch");
#endif
	OnigRegion*	newRegion = onig_region_new();
	onig_region_copy(newRegion, _region);
	
	return [[[self class] allocWithZone:zone] 
		initWithRegion: newRegion 
		index: _index 
		enumerator: _enumerator
		locationCache: _locationCache 
		utf8LocationCache: _utf8LocationCache 
		utf8TerminalOfLastMatch: _utf8TerminalOfLastMatch
		parentMatch:nil];
}


// description
- (NSString*)description
{
	// OnigRegion		*_region;				// match result region
	// /* match result region type */
	// 		struct re_registers {
	// 		int  allocated;
	// 		int  num_regs;
	// 		int* beg;
	// 		int* end;
	// 		/* extended */
	// 		struct re_registers** list; /* capture history. list[1]-list[31] */
	// };
	
	NSRange	aRange = [self rangeOfStringBetweenMatchAndLastMatch];
	
	NSDictionary	*dictionary = [NSDictionary 
		dictionaryWithObjects: [NSArray arrayWithObjects: 
			Ogre_arrayWithOnigRegion(_region), 
			_enumerator, 
			[NSNumber numberWithUnsignedInt: _locationCache], 
			[NSNumber numberWithUnsignedInt: _utf8LocationCache], 
			[NSNumber numberWithUnsignedInt: aRange.location], 
			[NSNumber numberWithUnsignedInt: _index], 
			nil]
		forKeys:[NSArray arrayWithObjects: 
			@"Range of Substrings", 
			@"Regular Expression Enumerator", 
			@"Cache (Length of NSString)", 
			@"Cache (Length of UTF8String)", 
			@"Terminal of the Last Match", 
			@"Index", 
			nil]
		];
		
	return [dictionary description];
}


// ���O(���x��)��name�̕��������� (OgreCaptureGroupOption���w�肵���Ƃ��Ɏg�p�ł���)
// ���݂��Ȃ����O�̏ꍇ�� nil ��Ԃ��B
// ����̖��O�������������񂪕�������ꍇ�͗�O�𔭐�������B
- (NSString*)substringNamed:(NSString*)name
{
	int	index = [self indexOfSubstringNamed:name];
	if (index == -1) return nil;
		
	return [self substringAtIndex:index];
}

// ���O��name�̕���������͈̔�
// ���݂��Ȃ����O�̏ꍇ�� {-1, 0} ��Ԃ��B
// ����̖��O�������������񂪕�������ꍇ�͗�O�𔭐�������B
- (NSRange)rangeOfSubstringNamed:(NSString*)name
{
	int	index = [self indexOfSubstringNamed:name];
	if (index == -1) return NSMakeRange(-1, 0);
	
	return [self rangeOfSubstringAtIndex:index];
}

// ���O��name�̕����������index
// ���݂��Ȃ��ꍇ��-1��Ԃ�
// ����̖��O�������������񂪕�������ꍇ�͗�O�𔭐�������B
- (unsigned)indexOfSubstringNamed:(NSString*)name
{
	int	index = [[_enumerator regularExpression] groupIndexForName:name];
	if (index == -2) {
		// ����̖��O�������������񂪕�������ꍇ�͗�O�𔭐�������B
		[NSException raise:OgreMatchException format:@"multiplex definition name <%@> call", name];
	}
	
	return index;
}

// index�Ԗڂ̕���������̖��O
// ���݂��Ȃ����O�̏ꍇ�� nil ��Ԃ��B
- (NSString*)nameOfSubstringAtIndex:(unsigned)index
{
	return [[_enumerator regularExpression] nameForGroupIndex:index];
}



// �}�b�`��������������̂����O���[�v�ԍ����ŏ��̂���
- (unsigned)indexOfFirstMatchedSubstringInRange:(NSRange)aRange
{
	unsigned	index, count = [self count];
	if (count > NSMaxRange(aRange)) count = NSMaxRange(aRange);
	
	for (index = aRange.location; index < count; index++) {
		if (_region->beg[index] != -1) return index;
	}
	
	return 0;   // �ǂ̕������ɂ��}�b�`���Ȃ������ꍇ
}

- (NSString*)nameOfFirstMatchedSubstringInRange:(NSRange)aRange
{
	return [self nameOfSubstringAtIndex:[self indexOfFirstMatchedSubstringInRange:aRange]];
}


// �}�b�`��������������̂����O���[�v�ԍ����ő�̂���
- (unsigned)indexOfLastMatchedSubstringInRange:(NSRange)aRange
{
	unsigned	index, count = [self count];
	if (count > NSMaxRange(aRange)) count = NSMaxRange(aRange);

	for (index = count - 1; index >= aRange.location; index--) {
		if (_region->beg[index] != -1) return index;
	}
	
	return 0;   // �ǂ̕������ɂ��}�b�`���Ȃ������ꍇ
}

- (NSString*)nameOfLastMatchedSubstringInRange:(NSRange)aRange
{
	return [self nameOfSubstringAtIndex:[self indexOfLastMatchedSubstringInRange:aRange]];
}


// �}�b�`��������������̂����Œ��̂���
- (unsigned)indexOfLongestSubstringInRange:(NSRange)aRange
{
	BOOL		matched = NO;
	unsigned	maxLength = 0;
	unsigned	maxIndex = 0, i, count = [self count];
	NSRange		range;
	if (count > NSMaxRange(aRange)) count = NSMaxRange(aRange);

	for (i = aRange.location; i < count; i++) {
		range = [self rangeOfSubstringAtIndex:i];
		if ((range.location != -1) && ((maxLength < range.length) || !matched)) {
			matched = YES;
			maxLength = range.length;
			maxIndex = i;
		}
	}
	
	return maxIndex;
}

- (NSString*)nameOfLongestSubstringInRange:(NSRange)aRange
{
	return [self nameOfSubstringAtIndex:[self indexOfLongestSubstringInRange:aRange]];
}


// �}�b�`��������������̂����ŒZ�̂���
- (unsigned)indexOfShortestSubstringInRange:(NSRange)aRange
{
	BOOL		matched = NO;
	unsigned	minLength = 0;
	unsigned	minIndex = 0, i, count = [self count];
	NSRange		range;
	if (count > NSMaxRange(aRange)) count = NSMaxRange(aRange);
	
	for (i = aRange.location; i < count; i++) {
		range = [self rangeOfSubstringAtIndex:i];
		if ((range.location != -1) && ((minLength > range.length) || !matched)) {
			matched = YES;
			minLength = range.length;
			minIndex = i;
		}
	}
	
	return minIndex;
}

- (NSString*)nameOfShortestSubstringInRange:(NSRange)aRange
{
	return [self nameOfSubstringAtIndex:[self indexOfShortestSubstringInRange:aRange]];
}

// �}�b�`��������������̂����O���[�v�ԍ����ŏ��̂��� (�Ȃ��ꍇ��0��Ԃ�)
- (unsigned)indexOfFirstMatchedSubstring
{
	return [self indexOfFirstMatchedSubstringInRange:NSMakeRange(1, [self count] - 1)];
}

- (unsigned)indexOfFirstMatchedSubstringBeforeIndex:(unsigned)anIndex
{
	return [self indexOfFirstMatchedSubstringInRange:NSMakeRange(1, anIndex - 1)];
}

- (unsigned)indexOfFirstMatchedSubstringAfterIndex:(unsigned)anIndex
{
	return [self indexOfFirstMatchedSubstringInRange:NSMakeRange(anIndex, [self count] - anIndex)];
}

// ���̖��O
- (NSString*)nameOfFirstMatchedSubstring
{
	return [self nameOfFirstMatchedSubstringInRange:NSMakeRange(1, [self count] - 1)];
}

- (NSString*)nameOfFirstMatchedSubstringBeforeIndex:(unsigned)anIndex
{
	return [self nameOfFirstMatchedSubstringInRange:NSMakeRange(1, anIndex - 1)];
}

- (NSString*)nameOfFirstMatchedSubstringAfterIndex:(unsigned)anIndex
{
	return [self nameOfFirstMatchedSubstringInRange:NSMakeRange(anIndex, [self count] - anIndex)];
}


// �}�b�`��������������̂����O���[�v�ԍ����ő�̂��� (�Ȃ��ꍇ��0��Ԃ�)
- (unsigned)indexOfLastMatchedSubstring
{
	return [self indexOfLastMatchedSubstringInRange:NSMakeRange(1, [self count] - 1)];
}

- (unsigned)indexOfLastMatchedSubstringBeforeIndex:(unsigned)anIndex
{
	return [self indexOfLastMatchedSubstringInRange:NSMakeRange(1, anIndex - 1)];
}

- (unsigned)indexOfLastMatchedSubstringAfterIndex:(unsigned)anIndex
{
	return [self indexOfLastMatchedSubstringInRange:NSMakeRange(anIndex, [self count] - anIndex)];
}

// ���̖��O
- (NSString*)nameOfLastMatchedSubstring
{
	return [self nameOfLastMatchedSubstringInRange:NSMakeRange(1, [self count] - 1)];
}

- (NSString*)nameOfLastMatchedSubstringBeforeIndex:(unsigned)anIndex
{
	return [self nameOfLastMatchedSubstringInRange:NSMakeRange(1, anIndex - 1)];
}

- (NSString*)nameOfLastMatchedSubstringAfterIndex:(unsigned)anIndex
{
	return [self nameOfLastMatchedSubstringInRange:NSMakeRange(anIndex, [self count] - anIndex)];
}


// �}�b�`��������������̂����Œ��̂��� (�Ȃ��ꍇ��0��Ԃ��B���������̕�����������΁A�ԍ��̏����������D�悳���)
- (unsigned)indexOfLongestSubstring
{
	return [self indexOfLongestSubstringInRange:NSMakeRange(1, [self count] - 1)];
}

- (unsigned)indexOfLongestSubstringBeforeIndex:(unsigned)anIndex
{
	return [self indexOfLongestSubstringInRange:NSMakeRange(1, anIndex - 1)];
}

- (unsigned)indexOfLongestSubstringAfterIndex:(unsigned)anIndex
{
	return [self indexOfLongestSubstringInRange:NSMakeRange(anIndex, [self count] - anIndex)];
}

// ���̖��O
- (NSString*)nameOfLongestSubstring
{
	return [self nameOfLongestSubstringInRange:NSMakeRange(1, [self count] - 1)];
}

- (NSString*)nameOfLongestSubstringBeforeIndex:(unsigned)anIndex
{
	return [self nameOfLongestSubstringInRange:NSMakeRange(1, anIndex - 1)];
}

- (NSString*)nameOfLongestSubstringAfterIndex:(unsigned)anIndex
{
	return [self nameOfLongestSubstringInRange:NSMakeRange(anIndex, [self count] - anIndex)];
}


// �}�b�`��������������̂����ŒZ�̂��� (�Ȃ��ꍇ��0��Ԃ��B���������̕�����������΁A�ԍ��̏����������D�悳���)
- (unsigned)indexOfShortestSubstring
{
	return [self indexOfShortestSubstringInRange:NSMakeRange(1, [self count] - 1)];
}

- (unsigned)indexOfShortestSubstringBeforeIndex:(unsigned)anIndex
{
	return [self indexOfShortestSubstringInRange:NSMakeRange(1, anIndex - 1)];
}

- (unsigned)indexOfShortestSubstringAfterIndex:(unsigned)anIndex
{
	return [self indexOfShortestSubstringInRange:NSMakeRange(anIndex, [self count] - anIndex)];
}

// ���̖��O
- (NSString*)nameOfShortestSubstring
{
	return [self nameOfShortestSubstringInRange:NSMakeRange(1, [self count] - 1)];
}

- (NSString*)nameOfShortestSubstringBeforeIndex:(unsigned)anIndex
{
	return [self nameOfShortestSubstringInRange:NSMakeRange(1, anIndex - 1)];
}

- (NSString*)nameOfShortestSubstringAfterIndex:(unsigned)anIndex
{
	return [self nameOfShortestSubstringInRange:NSMakeRange(anIndex, [self count] - anIndex)];
}

/******************
* Capture History *
*******************/
// index�Ԗڂ̃O���[�v�̕ߊl����
// �������Ȃ��ꍇ��nil��Ԃ��B
- (OGRegularExpressionMatch*)captureHistoryAtIndex:(unsigned)index
{
	if ((index >= [self count]) || !ONIG_IS_CAPTURE_HISTORY_GROUP(_region, index)) return nil;
	
	return [[[[self class] allocWithZone:[self zone]] 
		initWithRegion: _region->list[index] 
		index: _index 
		enumerator: _enumerator 
		locationCache: _locationCache 
		utf8LocationCache: _utf8LocationCache 
		utf8TerminalOfLastMatch: _utf8TerminalOfLastMatch 
		parentMatch:self] autorelease];
}

- (OGRegularExpressionMatch*)captureHistoryNamed:(NSString*)name
{
	int	index = [self indexOfSubstringNamed:name];
	if (index == -1) return nil;
	
	return [self captureHistoryAtIndex:index];
}

@end
