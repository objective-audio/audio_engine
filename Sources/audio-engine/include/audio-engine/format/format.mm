//
//  format.mm
//

#include "format.h"

#import <AVFoundation/AVFoundation.h>

#include <audio-engine/utils/exception.h>
#include <cpp-utils/yas_cf_utils.h>
#include <cpp-utils/yas_stl_utils.h>
#include <unordered_map>

using namespace yas;
using namespace yas::audio;

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

static AudioStreamBasicDescription const empty_asbd = {0};

#pragma mark - main

format::format(AudioStreamBasicDescription asbd) : _asbd(std::move(asbd)) {
    this->_asbd.mReserved = 0;

    if (asbd.mFormatID == kAudioFormatLinearPCM) {
        if ((asbd.mFormatFlags & kAudioFormatFlagIsFloat) &&
            ((asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian) &&
            (asbd.mFormatFlags & kAudioFormatFlagIsPacked)) {
            if (asbd.mBitsPerChannel == 64) {
                this->_pcm_format = pcm_format::float64;
            } else if (asbd.mBitsPerChannel == 32) {
                this->_pcm_format = pcm_format::float32;
                if (asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                    this->_standard = true;
                }
            }
        } else if ((asbd.mFormatFlags & kAudioFormatFlagIsSignedInteger) &&
                   ((asbd.mFormatFlags & kAudioFormatFlagIsBigEndian) == kAudioFormatFlagsNativeEndian) &&
                   (asbd.mFormatFlags & kAudioFormatFlagIsPacked)) {
            uint32_t fraction = (asbd.mFormatFlags & kLinearPCMFormatFlagsSampleFractionMask) >>
                                kLinearPCMFormatFlagsSampleFractionShift;
            if (asbd.mBitsPerChannel == 32 && fraction == 24) {
                this->_pcm_format = pcm_format::fixed824;
            } else if (asbd.mBitsPerChannel == 16) {
                this->_pcm_format = pcm_format::int16;
            }
        }
    }
}

format::format(CFDictionaryRef const &settings) : format(to_stream_description(settings)) {
}

format::format(args args)
    : format(to_stream_description(args.sample_rate, args.channel_count, args.pcm_format, args.interleaved)) {
}

bool format::is_empty() const {
    return memcmp(&this->_asbd, &empty_asbd, sizeof(AudioStreamBasicDescription)) == 0;
}

bool format::is_broken() const {
    return this->channel_count() == 0 || this->sample_rate() <= 0.0;
}

bool format::is_standard() const {
    return this->_standard;
}

audio::pcm_format format::pcm_format() const {
    return this->_pcm_format;
}

uint32_t format::channel_count() const {
    return this->_asbd.mChannelsPerFrame;
}

uint32_t format::buffer_count() const {
    return is_interleaved() ? 1 : this->_asbd.mChannelsPerFrame;
}

uint32_t format::stride() const {
    return is_interleaved() ? this->_asbd.mChannelsPerFrame : 1;
}

double format::sample_rate() const {
    return this->_asbd.mSampleRate;
}

bool format::is_interleaved() const {
    return !(this->_asbd.mFormatFlags & kAudioFormatFlagIsNonInterleaved);
}

AudioStreamBasicDescription const &format::stream_description() const {
    return this->_asbd;
}

uint32_t format::sample_byte_count() const {
    switch (this->_pcm_format) {
        case pcm_format::float32:
        case pcm_format::fixed824:
            return 4;
        case pcm_format::int16:
            return 2;
        case pcm_format::float64:
            return 8;
        case pcm_format::other:
            return 0;
    }
}

uint32_t format::frame_byte_count() const {
    return sample_byte_count() * stride();
}

CFStringRef format::description() const {
    return to_cf_object(to_string(*this));
}

bool format::operator==(format const &rhs) const {
    return yas::is_equal(this->_asbd, rhs._asbd);
}

bool format::operator!=(format const &rhs) const {
    return !(*this == rhs);
}

#pragma mark - utility

AudioStreamBasicDescription yas::to_stream_description(CFDictionaryRef const &settings) {
    AudioStreamBasicDescription asbd = {0};

    CFNumberRef const formatIDNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVFormatIDKey));
    if (formatIDNumber != NULL) {
        int64_t value = 0;
        CFNumberGetValue(formatIDNumber, kCFNumberSInt64Type, &value);
        asbd.mFormatID = static_cast<uint32_t>(value);
    }

    CFNumberRef const sampleRateNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVSampleRateKey));
    if (sampleRateNumber != NULL) {
        CFNumberGetValue(sampleRateNumber, kCFNumberDoubleType, &asbd.mSampleRate);
    }

    CFNumberRef const channelsNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVNumberOfChannelsKey));
    if (channelsNumber != NULL) {
        int64_t value = 0;
        CFNumberGetValue(channelsNumber, kCFNumberSInt64Type, &value);
        asbd.mChannelsPerFrame = static_cast<uint32_t>(value);
    }

    CFNumberRef const bitNumber =
        static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVLinearPCMBitDepthKey));
    if (bitNumber != NULL) {
        int64_t value = 0;
        CFNumberGetValue(bitNumber, kCFNumberSInt64Type, &value);
        asbd.mBitsPerChannel = static_cast<uint32_t>(value);
    }

    if (asbd.mFormatID == kAudioFormatLinearPCM) {
        asbd.mFormatFlags = kAudioFormatFlagIsPacked;

        CFNumberRef const isBigEndianNumber =
            (CFNumberRef)CFDictionaryGetValue(settings, (const void *)AVLinearPCMIsBigEndianKey);
        if (isBigEndianNumber != NULL) {
            int8_t value = 0;
            CFNumberGetValue(isBigEndianNumber, kCFNumberSInt8Type, &value);
            if (value) {
                asbd.mFormatFlags |= kAudioFormatFlagIsBigEndian;
            }
        }

        CFNumberRef const isFloatNumber =
            static_cast<CFNumberRef>(CFDictionaryGetValue(settings, (const void *)AVLinearPCMIsFloatKey));
        if (isFloatNumber != NULL) {
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
        if (isNonInterleavedNumber != NULL) {
            int8_t value = 0;
            CFNumberGetValue(isNonInterleavedNumber, kCFNumberSInt8Type, &value);
            if (value) {
                asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            }
        }
    }

    UInt32 size = sizeof(AudioStreamBasicDescription);
    raise_if_raw_audio_error(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd));

    return asbd;
}

AudioStreamBasicDescription yas::to_stream_description(double const sample_rate, uint32_t const channel_count,
                                                       pcm_format const pcm_format, bool const interleaved) {
    if (pcm_format == pcm_format::other || channel_count == 0) {
        throw std::invalid_argument(std::string(__PRETTY_FUNCTION__) + " : invalid argument. pcm_format(" +
                                    to_string(pcm_format) + ") channel_count(" + std::to_string(channel_count) + ")");
    }

    AudioStreamBasicDescription asbd = {
        .mSampleRate = sample_rate,
        .mFormatID = kAudioFormatLinearPCM,
    };

    AudioFormatFlags const nativeEndianFlag = kAudioFormatFlagsNativeEndian;
    AudioFormatFlags const packedFlag = kAudioFormatFlagIsPacked;
    asbd.mFormatFlags = nativeEndianFlag | packedFlag;

    if (pcm_format == pcm_format::float32 || pcm_format == pcm_format::float64) {
        asbd.mFormatFlags |= kAudioFormatFlagIsFloat;
    } else if (pcm_format == pcm_format::int16) {
        asbd.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
    } else if (pcm_format == pcm_format::fixed824) {
        asbd.mFormatFlags |= kAudioFormatFlagIsSignedInteger | (24 << kLinearPCMFormatFlagsSampleFractionShift);
    }

    if (!interleaved) {
        asbd.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
    }

    if (pcm_format == pcm_format::float64) {
        asbd.mBitsPerChannel = 64;
    } else if (pcm_format == pcm_format::int16) {
        asbd.mBitsPerChannel = 16;
    } else {
        asbd.mBitsPerChannel = 32;
    }

    asbd.mChannelsPerFrame = channel_count;

    UInt32 size = sizeof(AudioStreamBasicDescription);
    raise_if_raw_audio_error(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &asbd));

    return asbd;
}

bool yas::is_equal(AudioStreamBasicDescription const &asbd1, AudioStreamBasicDescription const &asbd2) {
    return memcmp(&asbd1, &asbd2, sizeof(AudioStreamBasicDescription)) == 0;
}

std::string yas::to_string(audio::format const &format) {
    std::string string;
    AudioStreamBasicDescription const &asbd = format.stream_description();
    string += "{\n";
    string += "    pcmFormat = " + to_string(format.pcm_format()) + ";\n";
    string += "    sampleRate = " + std::to_string(asbd.mSampleRate) + ";\n";
    string += "    bitsPerChannel = " + std::to_string(asbd.mBitsPerChannel) + ";\n";
    string += "    bytesPerFrame = " + std::to_string(asbd.mBytesPerFrame) + ";\n";
    string += "    bytesPerPacket = " + std::to_string(asbd.mBytesPerPacket) + ";\n";
    string += "    channelsPerFrame = " + std::to_string(asbd.mChannelsPerFrame) + ";\n";
    string += "    formatFlags = " + format_flags_string(format.stream_description()) + ";\n";
    string += "    formatID = " + to_string(file_type_for_hfs_type_code(asbd.mFormatID)) + ";\n";
    string += "    framesPerPacket = " + std::to_string(asbd.mFramesPerPacket) + ";\n";
    string += "}\n";
    return string;
}
