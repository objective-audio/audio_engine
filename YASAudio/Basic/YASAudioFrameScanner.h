//
//  YASAudioFrameScanner.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import "YASAudioTypes.h"

@class YASAudioPCMBuffer;

@interface YASAudioFrameScanner : NSObject

@property (nonatomic, assign, readonly) YASAudioConstPointer *pointer;
@property (nonatomic, assign, readonly) const NSUInteger *frame;
@property (nonatomic, assign, readonly) const NSUInteger *channel;
@property (nonatomic, assign, readonly) const BOOL *isAtFrameEnd;
@property (nonatomic, assign, readonly) const BOOL *isAtChannelEnd;
@property (nonatomic, assign, readonly) NSUInteger channelCount;

- (instancetype)initWithPCMBuffer:(YASAudioPCMBuffer *)pcmBuffer;

- (void)moveFrame;
- (void)moveChannel;

- (void)setFramePosition:(NSUInteger)frame;
- (void)setChannelPosition:(NSUInteger)channel;

- (void)reset;

@end

@interface YASAudioMutableFrameScanner : YASAudioFrameScanner

@property (nonatomic, assign, readonly) YASAudioPointer *mutablePointer;

@end
