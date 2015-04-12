//
//  YASAudioScanner.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import "YASAudioTypes.h"

@class YASAudioData;

@interface YASAudioScanner : NSObject

@property (nonatomic, assign, readonly) YASAudioConstPointer *pointer;
@property (nonatomic, assign, readonly) const NSUInteger *index;
@property (nonatomic, assign, readonly) const BOOL *isAtEnd;
@property (nonatomic, assign, readonly) NSUInteger length;

- (instancetype)initWithAudioData:(YASAudioData *)data atBuffer:(NSUInteger)buffer;
- (instancetype)initWithPointer:(YASAudioPointer)pointer
                         stride:(const NSUInteger)stride
                         length:(const NSUInteger)length NS_DESIGNATED_INITIALIZER;

- (void)move;
- (void)setPosition:(NSUInteger)index;
- (void)reset;

@end

@interface YASAudioMutableScanner : YASAudioScanner

@property (nonatomic, assign, readonly) YASAudioPointer *mutablePointer;

@end

@interface YASAudioFrameScanner : NSObject

@property (nonatomic, assign, readonly) YASAudioConstPointer *pointer;
@property (nonatomic, assign, readonly) const NSUInteger *frame;
@property (nonatomic, assign, readonly) const NSUInteger *channel;
@property (nonatomic, assign, readonly) const BOOL *isAtFrameEnd;
@property (nonatomic, assign, readonly) const BOOL *isAtChannelEnd;
@property (nonatomic, assign, readonly) NSUInteger frameLength;
@property (nonatomic, assign, readonly) NSUInteger channelCount;

- (instancetype)initWithAudioData:(YASAudioData *)data;

- (void)moveFrame;
- (void)moveChannel;

- (void)setFramePosition:(NSUInteger)frame;
- (void)setChannelPosition:(NSUInteger)channel;

- (void)reset;

@end

@interface YASAudioMutableFrameScanner : YASAudioFrameScanner

@property (nonatomic, assign, readonly) YASAudioPointer *mutablePointer;

@end
