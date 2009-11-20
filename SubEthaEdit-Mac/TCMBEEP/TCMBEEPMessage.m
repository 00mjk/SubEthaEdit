//
//  TCMBEEPMessage.m
//  TCMBEEP
//
//  Created by Martin Ott on Wed Feb 18 2004.
//  Copyright (c) 2004 TheCodingMonkeys. All rights reserved.
//

#import "TCMBEEPMessage.h"
#import "TCMBEEPFrame.h"


@implementation TCMBEEPMessage

+ (TCMBEEPMessage *)messageWithQueue:(NSArray *)aQueue
{
    TCMBEEPMessage *message = [[TCMBEEPMessage alloc] initWithQueue:aQueue];
    return [message autorelease];
}

- (id)initWithTypeString:(NSString *)aType messageNumber:(int32_t)aMessageNumber payload:(NSData *)aPayload
{
    self = [super init];
    if (self) {
        [self setMessageTypeString:aType];
        [self setMessageNumber:aMessageNumber];
        [self setPayload:aPayload];
        I_channelNumber = -1;
        I_answerNumber = -1;
    }
    return self;
}

- (id)initWithQueue:(NSArray *)aQueue
{
    NSParameterAssert(aQueue != nil);
    self = [super init];
    if (self) {
        if ([aQueue count] == 0) {
            [super dealloc];
            self = nil;
        } else {
            TCMBEEPFrame *frame = [aQueue objectAtIndex:0];
            [self setMessageTypeString:[NSString stringWithUTF8String:[frame messageType]]];
            [self setMessageNumber:[frame messageNumber]];
            [self setAnswerNumber:[frame answerNumber]];
            I_payload = [NSMutableData new];
            NSEnumerator *frames = [aQueue objectEnumerator];
            while ((frame = [frames nextObject])) {
                [I_payload appendData:[frame payload]];
            }
        }
    }
    return self;
}

- (void)dealloc
{
    [I_messageTypeString release];
    [I_payload release];
    [super dealloc];
}

- (void)setMessageTypeString:(NSString *)aString
{
    [I_messageTypeString autorelease];
    I_messageTypeString = [aString copy];
}

- (NSString *)messageTypeString
{
    return I_messageTypeString;
}

- (void)setMessageNumber:(int32_t)aNumber
{
    I_messageNumber = aNumber;
}

- (int32_t)messageNumber
{
    return I_messageNumber;
}

- (void)setChannelNumber:(int32_t)aNumber
{
    I_channelNumber = aNumber;
}

- (int32_t)channelNumber
{
    return I_channelNumber;
}

- (void)setAnswerNumber:(int32_t)aNumber
{
    I_answerNumber = aNumber;
}

- (int32_t)answerNumber
{
    return I_answerNumber;
}

- (void)setPayload:(NSData *)aData
{
    [I_payload autorelease];
    I_payload = [aData retain];
}

- (NSData *)payload
{
    return I_payload;
}

- (unsigned)payloadLength
{
    return [I_payload length];
}

- (BOOL)isMSG
{
    return [I_messageTypeString isEqualTo:@"MSG"];
}

- (BOOL)isANS
{
    return [I_messageTypeString isEqualTo:@"ANS"];
}

- (BOOL)isNUL
{
    return [I_messageTypeString isEqualTo:@"NUL"];
}

- (BOOL)isRPY
{
    return [I_messageTypeString isEqualTo:@"RPY"];
}

- (BOOL)isERR
{
    return [I_messageTypeString isEqualTo:@"ERR"];
}

@end
