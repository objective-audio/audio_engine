//
//  yas_audio_file_utils.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <CoreFoundation/CoreFoundation.h>

#include <filesystem>
#include <ostream>
#include <string>

namespace yas::audio {
enum class file_type {
    three_gpp,
    three_gpp2,
    aifc,
    aiff,
    amr,
    ac3,
    mpeg_layer3,
    core_audio_format,
    mpeg4,
    apple_m4a,
    wave,
};

audio::file_type to_file_type(AudioFileTypeID const);
audio::file_type to_file_type(std::string const &);
AudioFileTypeID to_audio_file_type_id(audio::file_type const);
}  // namespace yas::audio

namespace yas {
std::string to_string(audio::file_type const);
}  // namespace yas

std::ostream &operator<<(std::ostream &, yas::audio::file_type const &);

namespace yas::audio::ext_audio_file_utils {
[[nodiscard]] Boolean can_open(std::filesystem::path const &);
Boolean open(ExtAudioFileRef *ext_audio_file, std::filesystem::path const &);
Boolean create(ExtAudioFileRef *extAudioFile, std::filesystem::path const &, AudioFileTypeID const file_type_id,
               AudioStreamBasicDescription const &asbd);
Boolean dispose(ExtAudioFileRef const ext_audio_file);
Boolean set_client_format(AudioStreamBasicDescription const &asbd, ExtAudioFileRef const ext_audio_file);
Boolean get_audio_file_format(AudioStreamBasicDescription *asbd, ExtAudioFileRef const ext_audio_file);
[[nodiscard]] AudioFileID get_audio_file_id(ExtAudioFileRef const ext_audio_file);
[[nodiscard]] int64_t get_file_length_frames(ExtAudioFileRef const ext_audio_file);
[[nodiscard]] AudioFileTypeID get_audio_file_type_id(ExtAudioFileRef const ext_audio_file);
}  // namespace yas::audio::ext_audio_file_utils

namespace yas::audio {
enum class quality {
    min,
    low,
    medium,
    high,
    max,
};

[[nodiscard]] CFDictionaryRef wave_file_settings(double const sample_rate, uint32_t const channel_count,
                                                 uint32_t const bit_depth);
[[nodiscard]] CFDictionaryRef aiff_file_settings(double const sample_rate, uint32_t const channel_count,
                                                 uint32_t const bit_depth);
[[nodiscard]] CFDictionaryRef linear_pcm_file_settings(double const sample_rate, uint32_t const channel_count,
                                                       uint32_t const bit_depth, bool const is_big_endian,
                                                       bool const is_float, bool const is_non_interleaved);
[[nodiscard]] CFDictionaryRef aac_settings(double const sample_rate, uint32_t const channel_count,
                                           uint32_t const bit_depth, const quality encoder_quality,
                                           uint32_t const bit_rate, uint32_t const bit_depth_hint,
                                           const quality converter_quality);
}  // namespace yas::audio
