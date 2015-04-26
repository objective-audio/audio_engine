//
//  YASAudioTestUtils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <Foundation/Foundation.h>
#import "YASAudio.h"
#import "YASAudioData+Internal.h"
#import "YASAudioNode+Internal.h"
#import "YASAudioConnection+Internal.h"
#import "YASAudioOfflineOutputNode+Internal.h"

extern UInt32 TestValue(UInt32 frame, UInt32 channel, UInt32 buffer);

@interface YASAudioTestUtils : NSObject

+ (void)fillTestValuesToData:(YASAudioData *)data;
+ (BOOL)isClearedDataWithBuffer:(YASAudioData *)data;
+ (YASAudioMutablePointer)mutablePointerWithData:(YASAudioData *)data channel:(UInt32)channel frame:(UInt32)frame;
+ (BOOL)compareDataFlexiblyWithData:(YASAudioData *)data1 otherData:(YASAudioData *)data2;
+ (BOOL)isFilledData:(YASAudioData *)data;
+ (void)audioUnitRenderOnSubThreadWithAudioUnit:(YASAudioUnit *)audioUnit
                                         format:(YASAudioFormat *)format
                                    frameLength:(const UInt32)frameLength
                                          count:(const NSUInteger)count
                                           wait:(const NSTimeInterval)wait;
@end
