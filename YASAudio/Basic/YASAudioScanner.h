//
//  YASAudioScanner.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import "YASAudioTypes.h"

@class YASAudioData;

@interface YASAudioScanner : NSObject {
   @public
    YASAudioPointer _pointer;
    YASAudioPointer _topPointer;
    NSUInteger _stride;
    NSUInteger _length;
    NSUInteger _index;
}

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

@interface YASAudioFrameScanner : NSObject {
   @public
    YASAudioPointer _pointer;
    YASAudioPointer *_pointers;
    YASAudioPointer *_topPointers;
    NSUInteger _pointersSize;
    NSUInteger _frameStride;
    NSUInteger _frameLength;
    NSUInteger _frame;
    NSUInteger _channel;
    NSUInteger _channelCount;
}

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

#define YASAudioScannerMove(__v)             \
    if (++(__v)->_index >= (__v)->_length) { \
        (__v)->_pointer.v = NULL;            \
    } else {                                 \
        (__v)->_pointer.v += (__v)->_stride; \
    }

#define YASAudioScannerReset(__v) \
    (__v)->_index = 0;            \
    (__v)->_pointer.v = (__v)->_topPointer.v;

#define YASAudioFrameScannerMoveFrame(__v)                           \
    if (++(__v)->_frame >= (__v)->_frameLength) {                    \
        memset((__v)->_pointers, 0, (__v)->_pointersSize);           \
        (__v)->_pointer.v = NULL;                                    \
    } else {                                                         \
        NSUInteger index = (__v)->_channelCount;                     \
        while (index--) {                                            \
            (__v)->_pointers[index].u8 += (__v)->_frameStride;       \
        }                                                            \
        if ((__v)->_pointer.v) {                                     \
            (__v)->_pointer.v = (__v)->_pointers[(__v)->_channel].v; \
        } else {                                                     \
            (__v)->_channel = 0;                                     \
            (__v)->_pointer.v = (__v)->_pointers->v;                 \
        }                                                            \
    }

#define YASAudioFrameScannerMoveChannel(__v)                     \
    if (++(__v)->_channel >= (__v)->_channelCount) {             \
        (__v)->_pointer.v = NULL;                                \
    } else {                                                     \
        (__v)->_pointer.v = (__v)->_pointers[(__v)->_channel].v; \
    }

#define YASAudioFrameScannerReset(__v)                                                               \
    (__v)->_frame = 0;                                                                               \
    (__v)->_channel = 0;                                                                             \
    memcpy((__v)->_pointers, (__v)->_topPointers, (__v)->_channelCount * sizeof(YASAudioPointer *)); \
    (__v)->_pointer.v = (__v)->_pointers->v;
