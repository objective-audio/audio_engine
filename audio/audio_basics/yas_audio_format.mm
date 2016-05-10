//
//  yas_audio_format.mm
//

#import <AVFoundation/AVFoundation.h>
#include <unordered_map>
#include "yas_audio_exception.h"
#include "yas_audio_format.h"
#include "yas_cf_utils.h"
#include "yas_stl_utils.h"

using namespace yas;

#pragma mark - private

static std::string format_flags_string(AudioStreamBasicDescription const &asbd) {
    static std::unordered_map<AudioFormatFlags, std::string> const flags = {
        {kAudioFormatFlagIsFloat, "kAudioFormatFlagIsFloat"},
        {kAudioFormatFlagIsBigEndian, "kAudioFormatFlagIsBigEndian"},
        {kAudioFormatFlagIsSignedInteger, "kAudioFormatFlagIsSignedInteger"},
        {kAudioFormatFlagIsPacked, "kAudioFormatFlagIsPacked"},
        {kAudioFormatFlagIsAlignedHigh, "kAudioFormatFlagIsAlignedHigh"},
        {kAudioFormatFlagIsNonInterleaved, "kAudioFormatFlagIsNonInterleaved"},
        {kAudioFormatFlagIsNonMixable, "kAudioFormatFlagIsNonMixable"}};

    return joined(
        to_vector<std::string>(filter(flags, [&asbd](auto const &pair) { return asbd.mFormatFlags & pair.first; }),
                               [](auto const &pair) { return pair.second; }),
        " | ");
}

#pragma mark - impl

static AudioStreamBasicDescription const empty_asbd = {0};

struct audio::format::impl : base::impl {
    AudioStreamBasicDescription _asbd = {0};
    audio::pcm_format _pcm_format = audio::pcm_format::other;
    bool _standard = false;

    impl(AudioStreamBasicDescription &&asbd) : _asbd(std::move(asbd)) {
        _asbd.mReserved = 0;

        if (asbd.mFormatID == kAudioFormatLinearPCM) {
            if ((asbd.mFormatFlags & kAudioFormatFlagIsFloat) &&
                ((asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian) &&
                (asbd.mFormatFlags & kAudioFormatFlagIsPacked)) {
                if (asbd.mBitsPerChannel == 64) {
                    _pcm_format = audio::pcm_format::float64;
                } else if (asbd.mBitsPerChannel == 32) {
                    _pcm_format = audio::pcm_format::float32;
                    if (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                        _standard = true;
                    }
                }
            } else if ((asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) &&
                       ((asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian) &&
                       (asbd.mFormatFlags & kAudioFormatFlagIsPacked)) {
                uint32_t fraction = (asbd.mFormatFlags & kLinearPCMFormatFlagsSampleFractionMask) >>
                                    kLinearPCMFormatFlagsSampleFractionShift;
                if (asbd.mBitsPerChannel == 32 && fraction == 24) {
                    _pcm_format = audio::pcm_format::fixed824;
                } else if (asbd.mBitsPerChannel == 16) {
                    _pcm_format = audio::pcm_format::int16;
                }
            }
        }
    }

    bool is_equal(std::shared_ptr<base::impl> const &rhs) const override {
        if (auto casted_rhs = std::dynamic_pointer_cast<impl>(rhs)) {
            return yas::is_equal(_asbd, casted_rhs->_asbd);
        }

        return false;
    }
};

#pragma mark - main

audio::format::format(AudioStreamBasicDescription asbd) : base(std::make_shared<impl>(std::move(asbd))) {
}

audio::format::format(CFDictionaryRef const &settings) : format(to_stream_description(settings)) {
}

audio::format::format(double const sample_rate, uint32_t const channel_count, audio::pcm_format const pcm_format,
                      bool const interleaved)
    : format(to_stream_description(sample_rate, channel_count, pcm_format, interleaved)) {
}

audio::format::format(std::nullptr_t) : base(nullptr) {
}

bool audio::format::is_empty() const {
    return memcmp(&impl_ptr<impl>()->_asbd, &empty_asbd, sizeof(AudioStreamBasicDescription)) == 0;
}

bool audio::format::is_standard() const {
    return impl_ptr<impl>()->_standard;
}

audio::pcm_format audio::format::pcm_format() const {
    return impl_ptr<impl>()->_pcm_format;
}

uint32_t audio::format::channel_count() const {
    return impl_ptr<impl>()->_asbd.mChannelsPerFrame;
}

uint32_t audio::format::buffer_count() const {
    return is_interleaved() ? 1 : impl_ptr<impl>()->_asbd.mChannelsPerFrame;
}

uint32_t audio::format::stride() const {
    return is_interleaved() ? impl_ptr<impl>()->_asbd.mChannelsPerFrame : 1;
}

double audio::format::sample_rate() const {
    return impl_ptr<impl>()->_asbd.mSampleRate;
}

bool audio::format::is_interleaved() const {
    return !(impl_ptr<impl>()->_asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
}

AudioStreamBasicDescription const &audio::format::stream_description() const {
    return impl_ptr<impl>()->_asbd;
}

uint32_t audio::format::sample_byte_count() const {
    switch (impl_ptr<impl>()->_pcm_format) {
        case audio::pcm_format::float32:
        case audio::pcm_format::fixed824:
            return 4;
        case audio::pcm_format::int16:
            return 2;
        case audio::pcm_format::float64:
            return 8;
        case audio::pcm_format::other:
            return 0;
    }
}

uint32_t audio::format::buffer_frame_byte_count() const {
    return sample_byte_count() * stride();
}

CFStringRef audio::format::description() const {
    std::string string;
    AudioStreamBasicDescription const &asbd = stream_description();
    string += "{\n";
    string += "    pcmFormat = " + to_string(pcm_format()) + ";\n";
    string += "    sampleRate = " + std::to_string(asbd.mSampleRate) + ";\n";
    string += "    bitsPerChannel = " + std::to_string(asbd.mBitsPerChannel) + ";\n";
    string += "    bytesPerFrame = " + std::to_string(asbd.mBytesPerFrame) + ";\n";
    string += "    bytesPerPacket = " + std::to_string(asbd.mBytesPerPacket) + ";\n";
    string += "    channelsPerFrame = " + std::to_string(asbd.mChannelsPerFrame) + ";\n";
    string += "    formatFlags = " + format_flags_string(stream_description()) + ";\n";
    string += "    formatID = " + to_string(file_type_for_hfs_type_code(asbd.mFormatID)) + ";\n";
    string += "    framesPerPacket = " + std::to_string(asbd.mFramesPerPacket) + ";\n";
    string += "}\n";
    return to_cf_object(string);
}

audio::format const &audio::format::null_format() {
    static format const _format{nullptr};
    return _format;
}

#pragma mark - utility

std::string yas::to_string(audio::pcm_format const &pcm_format) {
    switch (pcm_format) {
        case audio::pcm_format::float32:
            return "Float32";
        case audio::pcm_format::float64:
            return "Float64";
        case audio::pcm_format::int16:
            return "Int16";
        case audio::pcm_format::fixed824:
            return "Fixed8.24";
        case audio::pcm_format::other:
            return "Other";
    }
    return "";
}

AudioStreamBasicDescription yas::to_stream_description(CFDictionaryRef const &settings) {
    AudioStreamBasicDescription asbd = {0};

    CFNumberRef const formatIDNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVFormatIDKey));
    if (formatIDNumber) {
        int64_t value = 0;
        CFNumberGetValue(formatIDNumber, kCFNumberSInt64Type, &value);
        asbd.mFormatID = static_cast<uint32_t>(value);
    }

    CFNumberRef const sampleRateNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVSampleRateKey));
    if (sampleRateNumber) {
        CFNumberGetValue(sampleRateNumber, kCFNumberDoubleType, &asbd.mSampleRate);
    }

    CFNumberRef const channelsNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVNumberOfChannelsKey));
    if (channelsNumber) {
        int64_t value = 0;
        CFNumberGetValue(channelsNumber, kCFNumberSInt64Type, &value);
        asbd.mChannelsPerFrame = static_cast<uint32_t>(value);
    }

    CFNumberRef const bitNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVLinearPCMBitDepthKey));
    if (bitNumber) {
        int64_t value = 0;
        CFNumberGetValue(bitNumber, kCFNumberSInt64Type, &value);
        asbd.mBitsPerChannel = static_cast<uint32_t>(value);
    }

    if (asbd.mFormatID == kAudioFormatLinearPCM) {
        asbd.mFormatFlags = kAudioFormatFlagIsPacked;

        CFNumberRef const isBigEndianNumber =
            (CFNumberRef)CFDictionaryGetValue(settings, (const void *)AVLinearPCMIsBigEndianKey);
        if (isBigEndianNumber) {
            int8_t value = 0;
            CFNumberGetValue(isBigEndianNumber, kCFNumberSInt8Type, &value);
            if (value) {
                asbd.mFormatFlags |= kAudioFormatFlagIsBigEndian;
            }
        }

        CFNumberRef const isFloatNumber =
            static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVLinearPCMIsFloatKey));
        if (isFloatNumber) {
            int8_t value = 0;
            CFNumberGetValue(isFloatNumber, kCFNumberSInt8Type, &value);
            if (value) {
                asbd.mFormatFlags |= kAudioFormatFlagIsFloat;
            } else {
                asbd.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
            }
        }

        CFNumberRef const isNonInterleavedNumber =
            static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVLinearPCMIsNonInterleaved));
        if (isNonInterleavedNumber) {
            int8_t value = 0;
            CFNumberGetValue(isNonInterleavedNumber, kCFNumberSInt8Type, &value);
            if (value) {
                asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            }
        }
    }

    UInt32 size = sizeof(AudioStreamBasicDescription);
    raise_if_au_error(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd));

    return asbd;
}

AudioStreamBasicDescription yas::to_stream_description(double const sample_rate, uint32_t const channel_count,
                                                       audio::pcm_format const pcm_format, bool const interleaved) {
    if (pcm_format == audio::pcm_format::other || channel_count == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument. pcm_format(" +
                                    to_string(pcm_format) + ") channel_count(" + std::to_string(channel_count) + ")");
    }

    AudioStreamBasicDescription asbd = {
        .mSampleRate = sample_rate, .mFormatID = kAudioFormatLinearPCM,
    };

    asbd.mFormatFlags = kAudioFormatFlagsNativeEndian | kAudioFormatFlagIsPacked;

    if (pcm_format == audio::pcm_format::float32 || pcm_format == audio::pcm_format::float64) {
        asbd.mFormatFlags |= kAudioFormatFlagIsFloat;
    } else if (pcm_format == audio::pcm_format::int16) {
        asbd.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
    } else if (pcm_format == audio::pcm_format::fixed824) {
        asbd.mFormatFlags |= kAudioFormatFlagIsSignedInteger | (24 << kLinearPCMFormatFlagsSampleFractionShift);
    }

    if (!interleaved) {
        asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
    }

    if (pcm_format == audio::pcm_format::float64) {
        asbd.mBitsPerChannel = 64;
    } else if (pcm_format == audio::pcm_format::int16) {
        asbd.mBitsPerChannel = 16;
    } else {
        asbd.mBitsPerChannel = 32;
    }

    asbd.mChannelsPerFrame = channel_count;

    UInt32 size = sizeof(AudioStreamBasicDescription);
    raise_if_au_error(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd));

    return asbd;
}

bool yas::is_equal(AudioStreamBasicDescription const &asbd1, AudioStreamBasicDescription const &asbd2) {
    return memcmp(&asbd1, &asbd2, sizeof(AudioStreamBasicDescription)) == 0;
}
