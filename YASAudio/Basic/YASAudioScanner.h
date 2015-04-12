//
//  YASAudioScanner.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import "YASAudioTypes.h"

@class YASAudioData;

@interface YASAudioScanner : NSObject

@property (nonatomic, assign, readonly) const YASAudioConstPointer *pointer;
@property (nonatomic, assign, readonly) const NSUInteger *index;
@property (nonatomic, assign, readonly) const NSUInteger length;

- (instancetype)initWithAudioData:(YASAudioData *)data atBuffer:(const NSUInteger)buffer;
- (instancetype)initWithPointer:(const YASAudioPointer)pointer
                         stride:(const NSUInteger)stride
                         length:(const NSUInteger)length NS_DESIGNATED_INITIALIZER;

- (void)move;
- (void)setPosition:(const NSUInteger)index;
- (void)reset;

@end

@interface YASAudioMutableScanner : YASAudioScanner

@property (nonatomic, assign, readonly) const YASAudioPointer *mutablePointer;

@end

@interface YASAudioFrameScanner : NSObject

@property (nonatomic, assign, readonly) const YASAudioConstPointer *pointer;
@property (nonatomic, assign, readonly) const NSUInteger *frame;
@property (nonatomic, assign, readonly) const NSUInteger *channel;
@property (nonatomic, assign, readonly) const NSUInteger frameLength;
@property (nonatomic, assign, readonly) const NSUInteger channelCount;

- (instancetype)initWithAudioData:(YASAudioData *)data;

- (void)moveFrame;
- (void)moveChannel;

- (void)setFramePosition:(const NSUInteger)frame;
- (void)setChannelPosition:(const NSUInteger)channel;

- (void)reset;

@end

@interface YASAudioMutableFrameScanner : YASAudioFrameScanner

@property (nonatomic, assign, readonly) const YASAudioPointer *mutablePointer;

@end
