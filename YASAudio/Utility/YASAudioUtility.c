//
//  YASAudioUtility.c
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "YASAudioUtility.h"
#include <string.h>
#include <Accelerate/Accelerate.h>

void YASAudioRemoveAudioBufferList(AudioBufferList *ioAbl)
{
    if (ioAbl) {
        for (UInt32 i = 0; i < ioAbl->mNumberBuffers; i++) {
            if (ioAbl->mBuffers[i].mData) {
                free(ioAbl->mBuffers[i].mData);
            }
        }
        free(ioAbl);
    }
}

void YASAudioRemoveAudioBufferListWithoutData(AudioBufferList *ioAbl)
{
    if (ioAbl) {
        free(ioAbl);
    }
}

AudioBufferList *YASAudioAllocateAudioBufferList(const UInt32 inBufferCount, const UInt32 inNumberChannels,
                                                 const UInt32 inSize)
{
    AudioBufferList *abl = (AudioBufferList *)calloc(1, sizeof(AudioBufferList) + inBufferCount * sizeof(AudioBuffer));
    if (abl) {
        abl->mNumberBuffers = inBufferCount;
        for (UInt32 i = 0; i < inBufferCount; ++i) {
            abl->mBuffers[i].mNumberChannels = inNumberChannels;
            abl->mBuffers[i].mDataByteSize = inSize;
            if (inSize > 0) {
                abl->mBuffers[i].mData = malloc(inSize);
                if (abl->mBuffers[i].mData == NULL) {
                    YASAudioRemoveAudioBufferList(abl);
                    abl = NULL;
                    break;
                }
            }
        }
    }
    return abl;
}

AudioBufferList *YASAudioAllocateAudioBufferListWithoutData(const UInt32 inBufferCount, const UInt32 inNumberChannels)
{
    return YASAudioAllocateAudioBufferList(inBufferCount, inNumberChannels, 0);
}

void YASAudioClearAudioBufferList(AudioBufferList *ioAbl)
{
    if (ioAbl) {
        for (UInt32 i = 0; i < ioAbl->mNumberBuffers; i++) {
            if (ioAbl->mBuffers && ioAbl->mBuffers[i].mData) {
                memset(ioAbl->mBuffers[i].mData, 0, ioAbl->mBuffers[i].mDataByteSize);
            }
        }
    }
}

Boolean YASAudioCopyAudioBufferListDirectly(const AudioBufferList *inFromList, AudioBufferList *ioToList)
{
    if ((!inFromList || !ioToList) || (inFromList->mNumberBuffers != ioToList->mNumberBuffers)) {
        return false;
    }

    UInt32 bufferCount = inFromList->mNumberBuffers;

    for (UInt32 bufIndex = 0; bufIndex < bufferCount; bufIndex++) {
        if ((ioToList->mBuffers[bufIndex].mNumberChannels != inFromList->mBuffers[bufIndex].mNumberChannels) ||
            (ioToList->mBuffers[bufIndex].mDataByteSize < inFromList->mBuffers[bufIndex].mDataByteSize)) {
            return false;
        }
    }

    for (UInt32 bufIndex = 0; bufIndex < bufferCount; bufIndex++) {
        ioToList->mBuffers[bufIndex].mDataByteSize = inFromList->mBuffers[bufIndex].mDataByteSize;
        memcpy(ioToList->mBuffers[bufIndex].mData, inFromList->mBuffers[bufIndex].mData,
               inFromList->mBuffers[bufIndex].mDataByteSize);
    }

    return true;
}

static Boolean YASGetDataInfoFromAudioBufferList(const AudioBufferList *inList, UInt32 *outChannelCount,
                                                 UInt32 *outFrameLength, void ***outDatas, UInt32 **outStrides,
                                                 const UInt32 inSampleByteCount)
{
    if (!inList || !outChannelCount || !outFrameLength || !inSampleByteCount || !outDatas || !outStrides) {
        assert(0);
        return false;
    }

    const UInt32 bufferCount = inList->mNumberBuffers;

    UInt32 channelCount = 0;
    UInt32 frameLength = 0;

    for (UInt32 bufIndex = 0; bufIndex < bufferCount; bufIndex++) {
        const UInt32 stride = inList->mBuffers[bufIndex].mNumberChannels;
        const UInt32 frames = inList->mBuffers[bufIndex].mDataByteSize / stride / inSampleByteCount;
        if (frameLength == 0) {
            frameLength = frames;
        } else if (frameLength != frames) {
            return false;
        }
        channelCount += stride;
    }

    *outChannelCount = channelCount;
    *outFrameLength = frameLength;

    void **datas = NULL;
    UInt32 *strides = NULL;
    if (channelCount > 0) {
        datas = calloc(channelCount, sizeof(void *));
        strides = calloc(channelCount, sizeof(UInt32));

        channelCount = 0;
        for (UInt32 bufIndex = 0; bufIndex < bufferCount; bufIndex++) {
            const UInt32 stride = inList->mBuffers[bufIndex].mNumberChannels;
            Byte *data = inList->mBuffers[bufIndex].mData;
            for (UInt32 ch = 0; ch < stride; ch++) {
                datas[channelCount] = &data[ch * inSampleByteCount];
                strides[channelCount] = stride;
                channelCount++;
            }
        }
    }

    *outDatas = datas;
    *outStrides = strides;

    return true;
}

Boolean YASAudioCopyAudioBufferListFlexibly(const AudioBufferList *inFromList, AudioBufferList *outToList,
                                            const UInt32 inSampleByteCount, UInt32 *outFrameLength)
{
    Boolean result = false;
    UInt32 srcChannelCount = 0;
    UInt32 srcFrameLength = 0;
    void **srcDatas = NULL;
    UInt32 *srcStrides = NULL;
    UInt32 dstChannelCount = 0;
    UInt32 dstFrameLength = 0;
    void **dstDatas = NULL;
    UInt32 *dstStrides = NULL;

    if (!YASGetDataInfoFromAudioBufferList(inFromList, &srcChannelCount, &srcFrameLength, &srcDatas, &srcStrides,
                                           inSampleByteCount)) {
        goto bail;
    }

    if (!srcDatas || !srcStrides) {
        goto bail;
    }

    if (!YASGetDataInfoFromAudioBufferList(outToList, &dstChannelCount, &dstFrameLength, &dstDatas, &dstStrides,
                                           inSampleByteCount)) {
        goto bail;
    }

    if (!srcDatas || !srcStrides || !dstDatas || !dstStrides) {
        goto bail;
    }

    if (srcFrameLength > dstFrameLength || srcChannelCount > dstChannelCount) {
        goto bail;
    }

    for (UInt32 ch = 0; ch < srcChannelCount; ch++) {
        const void *srcData = srcDatas[ch];
        void *dstData = dstDatas[ch];
        if (!srcData || !dstData) {
            goto bail;
        }
        const UInt32 srcStride = srcStrides[ch];
        const UInt32 dstStride = dstStrides[ch];
        if (srcStride == 1 && dstStride == 1) {
            memcpy(dstData, srcData, srcFrameLength * inSampleByteCount);
        } else {
            if (inSampleByteCount == sizeof(Float32)) {
                const Float32 *srcFloatData = srcData;
                Float32 *dstFloatData = dstData;
                cblas_scopy(srcFrameLength, srcFloatData, srcStride, dstFloatData, dstStride);
            } else if (inSampleByteCount == sizeof(Float64)) {
                const Float64 *srcDoubleData = srcData;
                Float64 *dstDoubleData = dstData;
                cblas_dcopy(srcFrameLength, srcDoubleData, srcStride, dstDoubleData, dstStride);
            } else {
                for (UInt32 frame = 0; frame < srcFrameLength; frame++) {
                    const UInt32 sampleFrame = frame * inSampleByteCount;
                    const Byte *srcByteData = srcData;
                    Byte *dstByteData = dstData;
                    memcpy(&dstByteData[sampleFrame * dstStride], &srcByteData[sampleFrame * srcStride],
                           inSampleByteCount);
                }
            }
        }
    }

    if (outFrameLength) {
        *outFrameLength = srcFrameLength;
    }

    result = true;

bail:
    if (srcDatas) {
        free(srcDatas);
    }
    if (srcStrides) {
        free(srcStrides);
    }
    if (dstDatas) {
        free(dstDatas);
    }
    if (dstStrides) {
        free(dstStrides);
    }

    return result;
}

void YASAudioSetDataByteSizeToAudioBufferList(AudioBufferList *ioAbl, const UInt32 inDataByteSize)
{
    if (ioAbl) {
        for (UInt32 i = 0; i < ioAbl->mNumberBuffers; i++) {
            ioAbl->mBuffers[i].mDataByteSize = inDataByteSize;
        }
    }
}

UInt32 YASAudioGetFrameLengthFromAudioBufferList(const AudioBufferList *inAbl, const UInt32 inSampleByteCount)
{
    if (inAbl && inSampleByteCount > 0) {
        UInt32 outFrameLength = 0;
        for (UInt32 buf = 0; buf < inAbl->mNumberBuffers; buf++) {
            const AudioBuffer *buffer = &inAbl->mBuffers[buf];
            const UInt32 stride = buffer->mNumberChannels;
            const UInt32 frameLength = buffer->mDataByteSize / stride / inSampleByteCount;
            if (buf == 0) {
                outFrameLength = frameLength;
            } else if (outFrameLength != frameLength) {
                return 0;
            }
        }
        return outFrameLength;
    } else {
        return 0;
    }
}

Boolean YASAudioIsEqualAudioBufferListStructure(const AudioBufferList *inAbl1, const AudioBufferList *inAbl2)
{
    if (!inAbl1 || !inAbl2) {
        return false;
    }

    if (inAbl1->mNumberBuffers != inAbl2->mNumberBuffers) {
        return false;
    }

    for (UInt32 i = 0; i < inAbl1->mNumberBuffers; i++) {
        if (inAbl1->mBuffers[i].mData != inAbl2->mBuffers[i].mData) {
            return false;
        } else if (inAbl1->mBuffers[i].mNumberChannels != inAbl2->mBuffers[i].mNumberChannels) {
            return false;
        }
    }

    return true;
}

Boolean YASAudioIsEqualDoubleWithAccuracy(const double inVal1, const double inVal2, const double inAccuracy)
{
    return ((inVal1 - inAccuracy) <= inVal2 && inVal2 <= (inVal1 + inAccuracy));
}

Boolean YASAudioIsEqualData(const void *inData1, const void *inData2, const size_t inSize)
{
    return memcmp(inData1, inData2, inSize) == 0;
}

Boolean YASAudioIsEqualAudioTimeStamp(const AudioTimeStamp *inTs1, const AudioTimeStamp *inTs2)
{
    if (YASAudioIsEqualData(inTs1, inTs2, sizeof(AudioTimeStamp))) {
        return true;
    } else {
        return ((inTs1->mFlags == inTs2->mFlags) && (inTs1->mHostTime == inTs2->mHostTime) &&
                (inTs1->mWordClockTime == inTs2->mWordClockTime) &&
                YASAudioIsEqualDoubleWithAccuracy(inTs1->mSampleTime, inTs2->mSampleTime, 0.00001) &&
                YASAudioIsEqualDoubleWithAccuracy(inTs1->mRateScalar, inTs2->mRateScalar, 0.00001) &&
                YASAudioIsEqualData(&inTs1->mSMPTETime, &inTs2->mSMPTETime, sizeof(SMPTETime)));
    }
}

Boolean YASAudioIsEqualASBD(const AudioStreamBasicDescription *inAsbd1, const AudioStreamBasicDescription *inAsbd2)
{
    return memcmp(inAsbd1, inAsbd2, sizeof(AudioStreamBasicDescription)) == 0;
}
