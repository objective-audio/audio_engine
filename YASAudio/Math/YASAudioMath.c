//
//  YASAudioMath.c
//  Copyright (c) 2015 Yuki Yasoshima.
//

#include "YASAudioMath.h"
#include <math.h>
#include <Accelerate/Accelerate.h>

Float64 YASAudioDecibelFromLinear(Float64 linear)
{
    return 20.0 * log10(linear);
}

Float64 YASAudioLinearFromDecibel(Float64 decibel)
{
    return pow(10.0, decibel / 20.0);
}

Float64 YASAudioTempoFromSeconds(Float64 sec)
{
    return pow(2, -log2(sec)) * 60.0;
}

Float64 YASAudioSecondsFromTempo(Float64 tempo)
{
    return pow(2, -log2(tempo / 60.0));
}

Float64 YASAudioSecondsFromFrames(UInt32 frames, Float64 sampleRate)
{
    return (Float64)frames / sampleRate;
}

UInt32 YASAudioFramesFromSeconds(Float64 seconds, Float64 sampleRate)
{
    return seconds * sampleRate;
}

Float32 YASAudioDecibelFromLinearf(Float32 linear)
{
    return 20.0f * log10f(linear);
}

Float32 YASAudioLinearFromDecibelf(Float32 decibel)
{
    return powf(10.0f, decibel / 20.0f);
}

Float32 YASAudioVectorSinef(Float32 *outData, const UInt32 count, const Float64 startPhase, const Float64 phasePerFrame) {
    if (!outData || count == 0) {
        return startPhase;
    }
    
    Float64 phase = startPhase;
    
    for (UInt32 i = 0; i < count; i++) {
        outData[i] = phase;
        phase = fmod(phase + phasePerFrame, YAS_2_PI);
    }
    
    const int length = count;
    vvsinf(outData, outData, &length);
    
    return phase;
}
