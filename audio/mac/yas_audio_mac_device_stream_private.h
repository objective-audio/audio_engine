//
//  yas_audio_device_stream_private.h
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include <audio/yas_audio_exception.h>

template <typename T>
std::unique_ptr<std::vector<T>> yas::audio::mac_device::stream::_property_data(
    AudioStreamID const stream_id, AudioObjectPropertySelector const selector) const {
    AudioObjectPropertyAddress const address = {
        .mSelector = selector, .mScope = kAudioObjectPropertyScopeGlobal, .mElement = kAudioObjectPropertyElementMain};

    UInt32 byte_size = 0;
    raise_if_raw_audio_error(AudioObjectGetPropertyDataSize(stream_id, &address, 0, nullptr, &byte_size));
    uint32_t vector_size = byte_size / sizeof(T);

    if (vector_size > 0) {
        auto data = std::make_unique<std::vector<T>>(vector_size);
        byte_size = vector_size * sizeof(T);
        raise_if_raw_audio_error(AudioObjectGetPropertyData(stream_id, &address, 0, nullptr, &byte_size, data->data()));
        return data;
    }

    return nullptr;
}

#endif
