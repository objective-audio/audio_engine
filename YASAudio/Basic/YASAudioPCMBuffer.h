//
//  YASAudioPCMBuffer.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

typedef void (^YASAudioPCMBufferReadBlock)(const void *data, const UInt32 bufferIndex);
typedef void (^YASAudioPCMBufferWriteBlock)(void *data, const UInt32 bufferIndex);
typedef void (^YASAudioPCMBufferReadValueBlock)(Float64 value, const UInt32 bufferIndex, const UInt32 channel,
                                                const UInt32 frame);
typedef Float64 (^YASAudioPCMBufferWriteValueBlock)(const UInt32 bufferIndex, const UInt32 channel, const UInt32 frame);

@class YASAudioFormat;

@interface YASAudioPCMBuffer : NSObject <NSCopying>

@property (nonatomic, strong, readonly) YASAudioFormat *format;
@property (nonatomic, readonly) const AudioBufferList *audioBufferList;

@property (nonatomic, readonly) UInt32 frameCapacity;
@property (nonatomic, readonly) UInt32 frameLength;
@property (nonatomic, readonly) UInt32 bufferCount;
@property (nonatomic, readonly) UInt32 stride;

- (instancetype)init NS_UNAVAILABLE;

- (const void *)dataAtBufferIndex:(NSUInteger)index;
- (Float64)valueAtBufferIndex:(UInt32)bufferIndex channel:(UInt32)channel frame:(UInt32)frame;
- (void)readDataUsingBlock:(YASAudioPCMBufferReadBlock)readDataBlock;
- (void)enumerateReadValuesUsingBlock:(YASAudioPCMBufferReadValueBlock)readValueBlock;

- (BOOL)copyDataFlexiblyToAudioBufferList:(AudioBufferList *)toAudioBufferList;

@end

@interface YASAudioWritablePCMBuffer : YASAudioPCMBuffer

@property (nonatomic, readonly) AudioBufferList *mutableAudioBufferList;
@property (nonatomic) UInt32 frameLength;

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format frameCapacity:(UInt32)frameCapacity;

- (void *)writableDataAtBufferIndex:(NSUInteger)index;
- (void)setValue:(Float64)value atBufferIndex:(UInt32)bufferIndex channel:(UInt32)channel frame:(UInt32)frame;
- (void)writeDataUsingBlock:(YASAudioPCMBufferWriteBlock)writeDataBlock;
- (void)enumerateWriteValuesUsingBlock:(YASAudioPCMBufferWriteValueBlock)writeValueBlock;

- (void)clearData;
- (void)clearDataWithStartFrame:(UInt32)frame length:(UInt32)length;

- (BOOL)copyDataFromBuffer:(YASAudioPCMBuffer *)fromBuffer;
- (BOOL)copyDataFromBuffer:(YASAudioPCMBuffer *)fromBuffer
            fromStartFrame:(UInt32)fromFrame
              toStartFrame:(UInt32)toFrame
                    length:(UInt32)length;

- (BOOL)copyDataFlexiblyFromBuffer:(YASAudioPCMBuffer *)buffer;
- (BOOL)copyDataFlexiblyFromAudioBufferList:(const AudioBufferList *)fromAudioBufferList;

@end

@interface YASAudioPCMBuffer (YASInternal)

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format
                  audioBufferList:(const AudioBufferList *)audioBufferList
                        needsFree:(BOOL)needsFree;

#if (!TARGET_OS_IPHONE && TARGET_OS_MAC)
- (instancetype)initWithPCMFormat:(YASAudioFormat *)format
                           buffer:(YASAudioPCMBuffer *)buffer
              outputChannelRoutes:(NSArray *)channelRoutes;
- (instancetype)initWithPCMFormat:(YASAudioFormat *)format
                           buffer:(YASAudioPCMBuffer *)buffer
               inputChannelRoutes:(NSArray *)channelRoutes;
#endif

@end

@interface YASAudioWritablePCMBuffer (YASInternal)

- (instancetype)initWithPCMFormat:(YASAudioFormat *)format
           mutableAudioBufferList:(AudioBufferList *)audioBufferList
                        needsFree:(BOOL)needsFree;

@end
