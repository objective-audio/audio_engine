//
//  yas_audio_file_utils.mm
//

#include "yas_audio_file_utils.h"
#include <AVFoundation/AVFoundation.h>
#include <cpp_utils/yas_cf_utils.h>
#include "yas_audio_exception.h"

using namespace yas;
using namespace yas::audio;

AudioFileTypeID audio::to_audio_file_type_id(audio::file_type const file_type) {
    switch (file_type) {
        case audio::file_type::three_gpp:
            return kAudioFile3GPType;
        case audio::file_type::three_gpp2:
            return kAudioFile3GP2Type;
        case audio::file_type::aifc:
            return kAudioFileAIFCType;
        case audio::file_type::aiff:
            return kAudioFileAIFFType;
        case audio::file_type::amr:
            return kAudioFileAMRType;
        case audio::file_type::ac3:
            return kAudioFileAC3Type;
        case audio::file_type::mpeg_layer3:
            return kAudioFileMP3Type;
        case audio::file_type::core_audio_format:
            return kAudioFileCAFType;
        case audio::file_type::mpeg4:
            return kAudioFileMPEG4Type;
        case audio::file_type::apple_m4a:
            return kAudioFileM4AType;
        case audio::file_type::wave:
            return kAudioFileWAVEType;
    }
}

std::string yas::to_string(audio::file_type const file_type) {
    switch (file_type) {
        case audio::file_type::three_gpp:
            return "public.3gpp";
        case audio::file_type::three_gpp2:
            return "public.3gpp2";
        case audio::file_type::aifc:
            return "public.aifc-audio";
        case audio::file_type::aiff:
            return "public.aiff-audio";
        case audio::file_type::amr:
            return "org.3gpp.adaptive-multi-rate-audio";
        case audio::file_type::ac3:
            return "public.ac3-audio";
        case audio::file_type::mpeg_layer3:
            return "public.mp3";
        case audio::file_type::core_audio_format:
            return "com.apple.coreaudio-format";
        case audio::file_type::mpeg4:
            return "public.mpeg-4";
        case audio::file_type::apple_m4a:
            return "com.apple.m4a-audio";
        case audio::file_type::wave:
            return "com.microsoft.waveform-audio";
    }
}

audio::file_type audio::to_file_type(AudioFileTypeID const fileTypeID) {
    switch (fileTypeID) {
        case kAudioFile3GPType:
            return audio::file_type::three_gpp;
        case kAudioFile3GP2Type:
            return audio::file_type::three_gpp2;
        case kAudioFileAIFCType:
            return audio::file_type::aifc;
        case kAudioFileAIFFType:
            return audio::file_type::aiff;
        case kAudioFileAMRType:
            return audio::file_type::amr;
        case kAudioFileAC3Type:
            return audio::file_type::ac3;
        case kAudioFileMP3Type:
            return audio::file_type::mpeg_layer3;
        case kAudioFileCAFType:
            return audio::file_type::core_audio_format;
        case kAudioFileMPEG4Type:
            return audio::file_type::mpeg4;
        case kAudioFileM4AType:
            return audio::file_type::apple_m4a;
        case kAudioFileWAVEType:
            return audio::file_type::wave;
        default:
            throw std::invalid_argument("invalid file type id.");
    }
}

audio::file_type audio::to_file_type(std::string const &string) {
    if (string == to_string(audio::file_type::three_gpp)) {
        return audio::file_type::three_gpp;
    } else if (string == to_string(audio::file_type::three_gpp2)) {
        return audio::file_type::three_gpp2;
    } else if (string == to_string(audio::file_type::aifc)) {
        return audio::file_type::aifc;
    } else if (string == to_string(audio::file_type::aiff)) {
        return audio::file_type::aiff;
    } else if (string == to_string(audio::file_type::amr)) {
        return audio::file_type::amr;
    } else if (string == to_string(audio::file_type::ac3)) {
        return audio::file_type::ac3;
    } else if (string == to_string(audio::file_type::mpeg_layer3)) {
        return audio::file_type::mpeg_layer3;
    } else if (string == to_string(audio::file_type::core_audio_format)) {
        return audio::file_type::core_audio_format;
    } else if (string == to_string(audio::file_type::mpeg4)) {
        return audio::file_type::mpeg4;
    } else if (string == to_string(audio::file_type::apple_m4a)) {
        return audio::file_type::apple_m4a;
    } else if (string == to_string(audio::file_type::wave)) {
        return audio::file_type::wave;
    }
    throw std::invalid_argument("invalid file type string.");
}

#pragma mark - audio file

namespace yas::audio_file_utils {
static Boolean open(AudioFileID *file_id, CFURLRef const url) {
    OSStatus err = AudioFileOpenURL(url, kAudioFileReadPermission, kAudioFileWAVEType, file_id);
    return err == noErr;
}

static Boolean close(AudioFileID const file_id) {
    OSStatus err = AudioFileClose(file_id);
    return err == noErr;
}

static AudioFileTypeID get_audio_file_type_id(AudioFileID const file_id) {
    uint32_t fileType;
    UInt32 size = sizeof(AudioFileTypeID);
    raise_if_raw_audio_error(AudioFileGetProperty(file_id, kAudioFilePropertyFileFormat, &size, &fileType));
    return fileType;
}

static Boolean get_audio_file_format(AudioStreamBasicDescription *asbd, AudioFileID const file_id) {
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = AudioFileGetProperty(file_id, kAudioFilePropertyDataFormat, &size, asbd);
    return err == noErr;
}
}

#pragma mark - ext audio file

Boolean ext_audio_file_utils::can_open(CFURLRef const url) {
    Boolean result = true;
    AudioFileID file_id;
    AudioStreamBasicDescription asbd;
    if (audio_file_utils::open(&file_id, url)) {
        if (!audio_file_utils::get_audio_file_format(&asbd, file_id)) {
            result = false;
        }
        audio_file_utils::close(file_id);
    } else {
        result = false;
    }
    return result;
}

Boolean ext_audio_file_utils::open(ExtAudioFileRef *ext_audio_file, CFURLRef const url) {
    OSStatus err = ExtAudioFileOpenURL(url, ext_audio_file);
    return err == noErr;
}

Boolean ext_audio_file_utils::create(ExtAudioFileRef *extAudioFile, CFURLRef const url,
                                     AudioFileTypeID const file_type_id, AudioStreamBasicDescription const &asbd) {
    OSStatus err = ExtAudioFileCreateWithURL(url, file_type_id, &asbd, NULL, kAudioFileFlags_EraseFile, extAudioFile);
    return err == noErr;
}

Boolean ext_audio_file_utils::dispose(ExtAudioFileRef const ext_audio_file) {
    OSStatus err = ExtAudioFileDispose(ext_audio_file);
    return err == noErr;
}

Boolean ext_audio_file_utils::set_client_format(AudioStreamBasicDescription const &asbd,
                                                ExtAudioFileRef const ext_audio_file) {
    uint32_t size = sizeof(AudioStreamBasicDescription);
    OSStatus err = noErr;
    raise_if_raw_audio_error(
        err = ExtAudioFileSetProperty(ext_audio_file, kExtAudioFileProperty_ClientDataFormat, size, &asbd));
    return err == noErr;
}

Boolean ext_audio_file_utils::get_audio_file_format(AudioStreamBasicDescription *asbd,
                                                    ExtAudioFileRef const ext_audio_file) {
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = noErr;
    raise_if_raw_audio_error(
        err = ExtAudioFileGetProperty(ext_audio_file, kExtAudioFileProperty_FileDataFormat, &size, asbd));
    return err == noErr;
}

AudioFileID ext_audio_file_utils::get_audio_file_id(ExtAudioFileRef const ext_audio_file) {
    UInt32 size = sizeof(AudioFileID);
    AudioFileID file_id = 0;
    raise_if_raw_audio_error(ExtAudioFileGetProperty(ext_audio_file, kExtAudioFileProperty_AudioFile, &size, &file_id));
    return file_id;
}

int64_t ext_audio_file_utils::get_file_length_frames(ExtAudioFileRef const ext_audio_file) {
    int64_t result = 0;
    UInt32 size = sizeof(int64_t);
    raise_if_raw_audio_error(
        ExtAudioFileGetProperty(ext_audio_file, kExtAudioFileProperty_FileLengthFrames, &size, &result));
    return result;
}

AudioFileTypeID ext_audio_file_utils::get_audio_file_type_id(ExtAudioFileRef const ext_audio_file) {
    AudioFileID file_id = get_audio_file_id(ext_audio_file);
    return audio_file_utils::get_audio_file_type_id(file_id);
}

#pragma mark -

CFDictionaryRef audio::wave_file_settings(double const sample_rate, uint32_t const channel_count,
                                          uint32_t const bit_depth) {
    return linear_pcm_file_settings(sample_rate, channel_count, bit_depth, false, bit_depth >= 32, false);
}

CFDictionaryRef audio::aiff_file_settings(double const sample_rate, uint32_t const channel_count,
                                          uint32_t const bit_depth) {
    return linear_pcm_file_settings(sample_rate, channel_count, bit_depth, true, bit_depth >= 32, false);
}

CFDictionaryRef audio::linear_pcm_file_settings(double const sample_rate, uint32_t const channel_count,
                                                uint32_t const bit_depth, bool const is_big_endian, bool const is_float,
                                                bool const is_non_interleaved) {
    return (__bridge CFDictionaryRef) @{
        AVFormatIDKey: @(kAudioFormatLinearPCM),
        AVSampleRateKey: @(sample_rate),
        AVNumberOfChannelsKey: @(channel_count),
        AVLinearPCMBitDepthKey: @(bit_depth),
        AVLinearPCMIsBigEndianKey: @(is_big_endian),
        AVLinearPCMIsFloatKey: @(is_float),
        AVLinearPCMIsNonInterleaved: @(is_non_interleaved),
        AVChannelLayoutKey: [NSData data]
    };
}

namespace yas::audio {
static AVAudioQuality to_av_audio_quality(audio::quality const quality) {
    switch (quality) {
        case quality::min:
            return AVAudioQualityMin;
        case quality::low:
            return AVAudioQualityLow;
        case quality::medium:
            return AVAudioQualityMedium;
        case quality::high:
            return AVAudioQualityHigh;
        case quality::max:
            return AVAudioQualityMax;
    }
}
}

CFDictionaryRef audio::aac_settings(double const sample_rate, uint32_t const channel_count, uint32_t const bit_depth,
                                    audio::quality const encoder_quality, uint32_t const bit_rate,
                                    uint32_t const bit_depth_hint, audio::quality const converter_quality) {
    return (__bridge CFDictionaryRef) @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVSampleRateKey: @(sample_rate),
        AVNumberOfChannelsKey: @(channel_count),
        AVLinearPCMBitDepthKey: @(bit_depth),
        AVLinearPCMIsBigEndianKey: @(NO),
        AVLinearPCMIsFloatKey: @(NO),
        AVEncoderAudioQualityKey: @(to_av_audio_quality(encoder_quality)),
        AVEncoderBitRateKey: @(bit_rate),
        AVEncoderBitDepthHintKey: @(bit_depth_hint),
        AVSampleRateConverterAudioQualityKey: @(to_av_audio_quality(converter_quality))
    };
}
