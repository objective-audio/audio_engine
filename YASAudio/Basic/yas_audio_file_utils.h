//
//  yas_audio_file_utils.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <CoreFoundation/CoreFoundation.h>
#include <AVFoundation/AVFoundation.h>

namespace yas
{
    namespace audio_file_type
    {
        extern const CFStringRef three_gpp;
        extern const CFStringRef three_gpp2;
        extern const CFStringRef aifc;
        extern const CFStringRef aiff;
        extern const CFStringRef amr;
        extern const CFStringRef ac3;
        extern const CFStringRef mpeg_layer3;
        extern const CFStringRef core_audio_format;
        extern const CFStringRef mpeg4;
        extern const CFStringRef apple_m4a;
        extern const CFStringRef wave;
    }

    AudioFileTypeID to_audio_file_type_id(const CFStringRef fileType);
    CFStringRef to_audio_file_type(const AudioFileTypeID fileTypeID);

    namespace ext_audio_file_utils
    {
        Boolean can_open(const CFURLRef url);
        Boolean open(ExtAudioFileRef *ext_audio_file, const CFURLRef url);
        Boolean create(ExtAudioFileRef *extAudioFile, const CFURLRef url, const AudioFileTypeID file_type_id,
                       const AudioStreamBasicDescription &asbd);
        Boolean dispose(const ExtAudioFileRef ext_audio_file);
        Boolean set_client_format(const AudioStreamBasicDescription &asbd, const ExtAudioFileRef ext_audio_file);
        Boolean get_audio_file_format(AudioStreamBasicDescription *asbd, const ExtAudioFileRef ext_audio_file);
        AudioFileID get_audio_file_id(const ExtAudioFileRef ext_audio_file);
        SInt64 get_file_length_frames(const ExtAudioFileRef ext_audio_file);
        AudioFileTypeID get_audio_file_type_id(const ExtAudioFileRef ext_audio_file);
        CFStringRef get_audio_file_type(const ExtAudioFileRef ext_auidio_file);
    }

    CFDictionaryRef wave_file_settings(const Float64 sample_rate, const UInt32 channels, const UInt32 bit_depth);
    CFDictionaryRef aiff_file_settings(const Float64 sample_rate, const UInt32 channels, const UInt32 bit_depth);
    CFDictionaryRef linear_pcm_file_settings(const Float64 sample_rate, const UInt32 channels, const UInt32 bit_depth,
                                             const bool is_big_endian, const bool is_float,
                                             const bool is_non_interleaved);
    CFDictionaryRef aac_settings(const Float64 sample_rate, const UInt32 channels, const UInt32 bit_depth,
                                 const AVAudioQuality encoder_quality, const UInt32 bit_rate,
                                 const UInt32 bit_depth_hint, const AVAudioQuality converter_quality);
}
