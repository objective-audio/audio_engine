//
//  YASAudioMath.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#ifndef __YASAudio_YASAudioMath_h
#define __YASAudio_YASAudioMath_h

#include <MacTypes.h>

#define YAS_2_PI 6.28318530717958647692528676655000596

#if defined(__cplusplus)
extern "C" {
#endif

extern Float64 YASAudioDecibelFromLinear(Float64 linear);
extern Float64 YASAudioLinearFromDecibel(Float64 decibel);
extern Float64 YASAudioTempoFromSeconds(Float64 seconds);
extern Float64 YASAudioSecondsFromTempo(Float64 tempo);
extern Float64 YASAudioSecondsFromFrames(UInt32 frames, Float64 sampleRate);
extern UInt32 YASAudioFramesFromSeconds(Float64 seconds, Float64 sampleRate);

extern Float32 YASAudioDecibelFromLinearf(Float32 linear);
extern Float32 YASAudioLinearFromDecibelf(Float32 decibel);

extern Float32 YASAudioVectorSinef(Float32 *outData, const UInt32 count, const Float64 startPhase,
                                   const Float64 phasePerFrame);

#if defined(__cplusplus)
}
#endif

#endif
