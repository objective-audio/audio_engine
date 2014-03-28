
/**
 * YASAudioUtility.h
 */

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreGraphics/CoreGraphics.h>
#import <mach/mach_time.h>

#pragma mark -
#pragma mark Error Handling
#pragma mark -

#if !DEBUG

#define YAS_Require_NoErr(errorCode, exceptionLabel)                    \
do                                                                      \
{                                                                       \
    if ( __builtin_expect(0 != (errorCode), 0) )                        \
    {                                                                   \
        goto exceptionLabel;                                            \
    }                                                                   \
} while ( 0 )

#else

#define YAS_Require_NoErr(errorCode, exceptionLabel)                    \
do                                                                      \
{                                                                       \
    long evalOnceErrorCode = (errorCode);                               \
    if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
    {                                                                   \
        NSLog(@"YASRequireError %s %d", __PRETTY_FUNCTION__, __LINE__); \
        goto exceptionLabel;                                            \
    }                                                                   \
} while ( 0 )

#endif


#if !DEBUG

#define YAS_Verify_NoErr(errorCode)                                     \
do                                                                      \
{                                                                       \
    if ( 0 != (errorCode) )                                             \
    {                                                                   \
    }                                                                   \
} while ( 0 )

#else

#define YAS_Verify_NoErr(errorCode)                                     \
do                                                                      \
{                                                                       \
    long evalOnceErrorCode = (errorCode);                               \
    if ( __builtin_expect(0 != evalOnceErrorCode, 0) )                  \
    {                                                                   \
        NSLog(@"YASVerifyError %s %d", __PRETTY_FUNCTION__, __LINE__);  \
    }                                                                   \
} while ( 0 )

#endif


#pragma mark -
#pragma mark Prototypes
#pragma mark -

/*! AudioBufferListを生成します */
static AudioBufferList *YASAllocateAudioBufferList(UInt32 bufferCount, UInt32 ch, UInt32 size);

/*! AudioBufferListを解放します */
static void YASRemoveAudioBufferList(AudioBufferList *list);

/*! AudioBufferListのバッファをゼロでクリアします */
static void YASClearAudioBufferList(AudioBufferList *list);

/*! AudioBufferListにサイン波を書き込みます（デバッグ用） */
static void YASFillFloat32SinewaveToAudioBufferList(AudioBufferList *list, UInt32 cycle);

/*! リニア値をdB値に変換します */
static CGFloat YASDBValueFromLinearValue(CGFloat val);

/*! dB値をリニア値に変換します */
static CGFloat YASLinearValueFromDBValue(CGFloat val);

/*! 秒数をテンポに変換します */
static CGFloat YASTempoValueFromSeconds(CGFloat sec);

/*! テンポを秒数に変換します */
static CGFloat YASSecondsFromTempoValue(CGFloat tempo);

/*! ASBDにFloat32・NonInterleavedのデータをセットします */
static void YASGetFloat32NonInterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate);

/*! ASBDにSInt16・Interleavedのデータをセットします */
static void YASGetSInt16InterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate);

/*! フレーム数を秒数に変換します */
static NSTimeInterval YASSecFromFrames(UInt32 frames, Float64 sampleRate);


#pragma mark -
#pragma mark Implementation
#pragma mark -

static AudioBufferList *YASAllocateAudioBufferList(UInt32 bufferCount, UInt32 ch, UInt32 size)
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

static void YASRemoveAudioBufferList(AudioBufferList *list)
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

static void YASClearAudioBufferList(AudioBufferList *list)
{
    if (list) {
        for (NSInteger i = 0; i < list->mNumberBuffers; i++) {
            if (list->mBuffers && list->mBuffers[i].mData) {
                memset(list->mBuffers[i].mData, 0, list->mBuffers[i].mDataByteSize);
            }
        }
    }
}

static void YASFillFloat32SinewaveToAudioBufferList(AudioBufferList *list, UInt32 cycle)
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

static void YASFillSInt16SinewaveToAudioBufferList(AudioBufferList *list, UInt32 cycle)
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

static CGFloat YASDBValueFromLinearValue(CGFloat val)
{
    return 20.0 * log10(val);
}

static CGFloat YASLinearValueFromDBValue(CGFloat val)
{
    return pow(10.0, val / 20.0);
}

static CGFloat YASTempoValueFromSeconds(CGFloat sec)
{
    return pow(2, -log2(sec)) * 60.0;
}

static CGFloat YASSecondsFromTempoValue(CGFloat tempo)
{
    return pow(2, -log2(tempo / 60.0));
}

static void YASGetFloat32NonInterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate)
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

static void YASGetSInt16InterleavedStereoFormat(AudioStreamBasicDescription *outFormat, Float64 sampleRate)
{
    outFormat->mSampleRate = sampleRate;
    outFormat->mFormatID = kAudioFormatLinearPCM;
    outFormat->mFormatFlags = kAudioFormatFlagsCanonical;
    outFormat->mBitsPerChannel = 16;
    outFormat->mChannelsPerFrame = 2;
    outFormat->mFramesPerPacket = 1;
    outFormat->mBytesPerFrame = outFormat->mBitsPerChannel / 8 * outFormat->mChannelsPerFrame;
    outFormat->mBytesPerPacket = outFormat->mBytesPerFrame;
}

static NSTimeInterval YASSecFromFrames(UInt32 frames, Float64 sampleRate)
{
    return (Float64)frames / sampleRate;
}

static uint64_t YASNanoSecFromHosttime(uint64_t hostTime)
{
    static mach_timebase_info_data_t sTimebaseInfo;
    if ( sTimebaseInfo.denom == 0 ) {
        (void)mach_timebase_info(&sTimebaseInfo);
    }
    return hostTime * sTimebaseInfo.numer / sTimebaseInfo.denom;
}
