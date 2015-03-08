//
//  YASAudioUtility.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#ifndef __YASAudio__YASAudioUtility__
#define __YASAudio__YASAudioUtility__

#include <AudioToolbox/AudioToolbox.h>

#if defined(__cplusplus)
extern "C" {
#endif

extern void YASAudioRemoveAudioBufferList(AudioBufferList *ioAbl);
extern void YASAudioRemoveAudioBufferListWithoutData(AudioBufferList *ioAbl);
extern AudioBufferList *YASAudioAllocateAudioBufferList(const UInt32 inBufferCount, const UInt32 inNumberChannels,
                                                        const UInt32 inSize);
extern AudioBufferList *YASAudioAllocateAudioBufferListWithoutData(const UInt32 inBufferCount,
                                                                   const UInt32 inNumberChannels);
extern void YASAudioClearAudioBufferList(AudioBufferList *ioAbl);
extern Boolean YASAudioCopyAudioBufferListDirectly(const AudioBufferList *inFromList, AudioBufferList *ioToList);
extern Boolean YASAudioCopyAudioBufferListFlexibly(const AudioBufferList *inFromList, AudioBufferList *ioToList,
                                                   const UInt32 inSampleByteCount, UInt32 *outFrameLength);
extern void YASAudioSetDataByteSizeToAudioBufferList(AudioBufferList *ioAbl, const UInt32 inDataByteSize);
extern UInt32 YASAudioGetFrameLengthFromAudioBufferList(const AudioBufferList *inAbl, const UInt32 inSampleByteCount);
extern Boolean YASAudioIsEqualAudioBufferListStructure(const AudioBufferList *inAbl1, const AudioBufferList *inAbl2);

extern Boolean YASAudioIsEqualDoubleWithAccuracy(const double inVal1, const double inVal2, const double inAccuracy);
extern Boolean YASAudioIsEqualData(const void *inData1, const void *inData2, const size_t inSize);
extern Boolean YASAudioIsEqualAudioTimeStamp(const AudioTimeStamp *inTs1, const AudioTimeStamp *inTs2);
extern Boolean YASAudioIsEqualASBD(const AudioStreamBasicDescription *inAsbd1,
                                   const AudioStreamBasicDescription *inAsbd2);

#if defined(__cplusplus)
}
#endif

#endif
