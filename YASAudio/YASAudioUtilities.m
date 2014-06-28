
//
//  YASAudioUtilities.m
//  Created by Yuki Yasoshima
//

#import <AudioToolbox/AudioToolbox.h>
#import <mach/mach_time.h>

void YASRemoveAudioBufferList(AudioBufferList *list)
{
    UInt32 i;
	
	if(list) {
		for(i = 0; i < list->mNumberBuffers; i++) {
			if(list->mBuffers[i].mData)
				free(list->mBuffers[i].mData);
		}
		free(list);
	}
}

AudioBufferList *YASAllocateAudioBufferList(UInt32 bufferCount, UInt32 ch, UInt32 size)
{
	AudioBufferList *list;
	UInt32 i;
	
	list = (AudioBufferList*)calloc(1, sizeof(AudioBufferList) + bufferCount * sizeof(AudioBuffer));
	if(list == NULL)
		return NULL;
	
	list->mNumberBuffers = bufferCount;
	for(i = 0; i < bufferCount; ++i) {
		list->mBuffers[i].mNumberChannels = ch;
		list->mBuffers[i].mDataByteSize = size;
		list->mBuffers[i].mData = malloc(size);
		if(list->mBuffers[i].mData == NULL) {
            YASRemoveAudioBufferList(list);
			return NULL;
		}
	}
	return list;
}

void YASClearAudioBufferList(AudioBufferList *list)
{
    if (list) {
        for (NSInteger i = 0; i < list->mNumberBuffers; i++) {
            if (list->mBuffers && list->mBuffers[i].mData) {
                memset(list->mBuffers[i].mData, 0, list->mBuffers[i].mDataByteSize);
            }
        }
    }
}

void YASCopyAudioBufferList(AudioBufferList *fromList, AudioBufferList *toList)
{
    if ((!fromList || !toList) ||
        (fromList->mNumberBuffers != toList->mNumberBuffers)) {
        return;
    }
    
    NSUInteger bufferCount = fromList->mNumberBuffers;
    
    for (NSInteger bufIndex = 0; bufIndex < bufferCount; bufIndex++) {
        if ((toList->mBuffers[bufIndex].mNumberChannels != fromList->mBuffers[bufIndex].mNumberChannels) ||
            (toList->mBuffers[bufIndex].mDataByteSize < fromList->mBuffers[bufIndex].mDataByteSize)) {
            return;
        }
        toList->mBuffers[bufIndex].mDataByteSize = fromList->mBuffers[bufIndex].mDataByteSize;
        memcpy(toList->mBuffers[bufIndex].mData, fromList->mBuffers[bufIndex].mData, fromList->mBuffers[bufIndex].mDataByteSize); 
    }
}

void YASSetDataByteSizeToAudioBufferList(AudioBufferList *list, UInt32 dataByteSize)
{
    if (list) {
        for (NSInteger i = 0; i < list->mNumberBuffers; i++) {
            list->mBuffers[i].mDataByteSize = dataByteSize;
        }
    }
}

void YASFillFloat32SinewaveToAudioBufferList(AudioBufferList *list, UInt32 cycle)
{
    if (!list || !list->mBuffers || list->mNumberBuffers == 0) return;
    UInt32 frames = list->mBuffers[0].mDataByteSize / sizeof(Float32);
    
    double onePhase = (double)cycle / (double)frames * 2.0 * M_PI;
    for (NSInteger i = 0; i < list->mNumberBuffers; i++) {
        Float32 *ptr = list->mBuffers[i].mData;
        UInt32 channels = list->mBuffers[i].mNumberChannels;
        for (NSInteger j = 0; j < frames; j++) {
            float val = sin(onePhase * j);
            for (NSInteger ch = 0; ch < channels; ch++) {
                ptr[j * channels + ch] = val * 0.1f;
            }
        }
    }
}

void YASFillSInt16SinewaveToAudioBufferList(AudioBufferList *list, UInt32 cycle)
{
    if (!list || !list->mBuffers || list->mNumberBuffers == 0) return;
    UInt32 frames = list->mBuffers[0].mDataByteSize / sizeof(Float32);
    
    double onePhase = (double)cycle / (double)frames * 2.0 * M_PI;
    for (NSInteger i = 0; i < list->mNumberBuffers; i++) {
        SInt16 *ptr = list->mBuffers[i].mData;
        UInt32 channels = list->mBuffers[i].mNumberChannels;
        for (NSInteger j = 0; j < frames; j++) {
            float val = sin(onePhase * j) * INT16_MAX;
            for (NSInteger ch = 0; ch < channels; ch++) {
                ptr[j * channels + ch] = val * 0.1f;
            }
        }
    }
}

double YASDBValueFromLinearValue(double val)
{
    return 20.0 * log10(val);
}

double YASLinearValueFromDBValue(double val)
{
    return pow(10.0, val / 20.0);
}

double YASTempoValueFromSeconds(double sec)
{
    return pow(2, -log2(sec)) * 60.0;
}

double YASSecondsFromTempoValue(double tempo)
{
    return pow(2, -log2(tempo / 60.0));
}

void YASGetFloat32NonInterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate)
{
    outFormat->mSampleRate = sampleRate;
    outFormat->mFormatID = kAudioFormatLinearPCM;
    outFormat->mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    outFormat->mBitsPerChannel = 32;
    outFormat->mChannelsPerFrame = 2;
    outFormat->mFramesPerPacket = 1;
    outFormat->mBytesPerFrame = outFormat->mBitsPerChannel / 8;
    outFormat->mBytesPerPacket = outFormat->mBytesPerFrame;
}

void YASGetSInt16InterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate)
{
    outFormat->mSampleRate = sampleRate;
    outFormat->mFormatID = kAudioFormatLinearPCM;
    outFormat->mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;
    outFormat->mBitsPerChannel = 16;
    outFormat->mChannelsPerFrame = 2;
    outFormat->mFramesPerPacket = 1;
    outFormat->mBytesPerFrame = outFormat->mBitsPerChannel / 8 * outFormat->mChannelsPerFrame;
    outFormat->mBytesPerPacket = outFormat->mBytesPerFrame;
}

BOOL YASIsEqualFormat(AudioStreamBasicDescription *list1, AudioStreamBasicDescription *list2)
{
    return memcmp(list1, list2, sizeof(AudioStreamBasicDescription)) == 0;
}

Float64 YASSecFromFrames(UInt32 frames, Float64 sampleRate)
{
    return (Float64)frames / sampleRate;
}

uint64_t YASNanoSecFromHosttime(uint64_t hostTime)
{
    static mach_timebase_info_data_t sTimebaseInfo = {0, 0};
    if (sTimebaseInfo.denom == 0) {
        mach_timebase_info(&sTimebaseInfo);
    }
    return hostTime * sTimebaseInfo.numer / sTimebaseInfo.denom;
}