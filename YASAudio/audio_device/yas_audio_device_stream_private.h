//
//  yas_audio_device_stream_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <TargetConditionals.h>
#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#include "yas_exception.h"
#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <vector>

namespace yas
{
    template <typename T>
    std::unique_ptr<std::vector<T>> audio::device_stream::_property_data(
        const AudioStreamID stream_id, const AudioObjectPropertySelector selector) const
    {
        const AudioObjectPropertyAddress address = {.mSelector = selector,
                                                    .mScope = kAudioObjectPropertyScopeGlobal,
                                                    .mElement = kAudioObjectPropertyElementMaster};

        UInt32 byte_size = 0;
        yas_raise_if_au_error(AudioObjectGetPropertyDataSize(stream_id, &address, 0, nullptr, &byte_size));
        UInt32 vector_size = byte_size / sizeof(T);

        if (vector_size > 0) {
            auto data = std::make_unique<std::vector<T>>(vector_size);
            byte_size = vector_size * sizeof(T);
            yas_raise_if_au_error(
                AudioObjectGetPropertyData(stream_id, &address, 0, nullptr, &byte_size, data->data()));
            return data;
        }

        return nullptr;
    }
}

#endif
