//
//  YASAudioData.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "YASAudioTypes.h"

@class YASAudioFormat, YASAudioScanner, YASAudioMutableScanner;

typedef void (^YASAudioDataReadBlock)(YASAudioScanner *scanner, const UInt32 buffer);
typedef void (^YASAudioDataWriteBlock)(YASAudioMutableScanner *scanner, const UInt32 buffer);

@interface YASAudioData : NSObject <NSCopying>

@property (nonatomic, strong, readonly) YASAudioFormat *format;
@property (nonatomic, readonly) const AudioBufferList *audioBufferList;
@property (nonatomic, readonly) AudioBufferList *mutableAudioBufferList;

@property (nonatomic, readonly) UInt32 frameCapacity;
@property (nonatomic) UInt32 frameLength;
@property (nonatomic, readonly) UInt32 bufferCount;
@property (nonatomic, readonly) UInt32 stride;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFormat:(YASAudioFormat *)format frameCapacity:(UInt32)frameCapacity;

- (YASAudioPointer)pointerAtBuffer:(NSUInteger)buffer;

- (Float64)valueAtBuffer:(UInt32)buffer channel:(UInt32)channel frame:(UInt32)frame;
- (void)setValue:(Float64)value atBuffer:(UInt32)buffer channel:(UInt32)channel frame:(UInt32)frame;

- (void)readBuffersUsingBlock:(YASAudioDataReadBlock)readBlock;
- (void)writeBuffersUsingBlock:(YASAudioDataWriteBlock)writeBlock;

- (void)clear;
- (void)clearWithStartFrame:(UInt32)frame length:(UInt32)length;

- (BOOL)copyFromData:(YASAudioData *)fromData;
- (BOOL)copyFromData:(YASAudioData *)fromData
      fromStartFrame:(UInt32)fromFrame
        toStartFrame:(UInt32)toFrame
              length:(UInt32)length;

- (BOOL)copyFlexiblyFromData:(YASAudioData *)data;
- (BOOL)copyFlexiblyFromAudioBufferList:(const AudioBufferList *)fromAbl;
- (BOOL)copyFlexiblyToAudioBufferList:(AudioBufferList *)toAbl;

@end
