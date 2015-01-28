//
//  YASAudioPCMBuffer.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@class YASAudioFormat;

@interface YASAudioPCMBuffer : NSObject <NSCopying>

@property (nonatomic, strong, readonly) YASAudioFormat *format;
@property (nonatomic, readonly) const AudioBufferList *audioBufferList;
@property (nonatomic, readonly) AudioBufferList *mutableAudioBufferList;

@property (nonatomic, readonly) UInt32 frameCapacity;
@property (nonatomic) UInt32 frameLength;
@property (nonatomic, readonly) UInt32 bufferCount;
@property (nonatomic, readonly) UInt32 stride;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPCMFormat:(YASAudioFormat *)format frameCapacity:(UInt32)frameCapacity;

- (Float32 *)float32DataAtBufferIndex:(NSUInteger)index;
- (Float64 *)float64DataAtBufferIndex:(NSUInteger)index;
- (SInt16 *)int16DataAtBufferIndex:(NSUInteger)index;
- (SInt32 *)int32DataAtBufferIndex:(NSUInteger)index;

- (void)clearData;
- (void)clearDataWithStartFrame:(UInt32)frame length:(UInt32)length;

- (BOOL)copyDataFromBuffer:(YASAudioPCMBuffer *)fromBuffer;
- (BOOL)copyDataFromBuffer:(YASAudioPCMBuffer *)fromBuffer fromStartFrame:(UInt32)fromFrame toStartFrame:(UInt32)toFrame length:(UInt32)length;

- (BOOL)copyDataFlexiblyFromBuffer:(YASAudioPCMBuffer *)buffer;
- (BOOL)copyDataFlexiblyFromAudioBufferList:(const AudioBufferList *)fromAudioBufferList;
- (BOOL)copyDataFlexiblyToAudioBufferList:(AudioBufferList *)toAudioBufferList;

@end

@interface YASAudioPCMBuffer (YASInternal)

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format audioBufferList:(AudioBufferList *)audioBufferList needsFree:(BOOL)needsFree;

@end
