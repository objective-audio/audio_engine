//
//  yas_audio_unit_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <vector>

namespace yas
{
    template <typename T>
    void audio_unit::set_property_data(const std::vector<T> &data, const AudioUnitPropertyID property_id,
                                       const AudioUnitScope scope, const AudioUnitElement element)
    {
        const UInt32 size = static_cast<UInt32>(data.size());
        const void *raw_data = size > 0 ? data.data() : nullptr;

        yas_raise_if_au_error(
            AudioUnitSetProperty(audio_unit_instance(), property_id, scope, element, raw_data, size * sizeof(T)));
    }

    template <typename T>
    std::vector<T> audio_unit::property_data(const AudioUnitPropertyID property_id, const AudioUnitScope scope,
                                             const AudioUnitElement element) const
    {
        UInt32 byte_size = 0;
        yas_raise_if_au_error(
            AudioUnitGetPropertyInfo(audio_unit_instance(), property_id, scope, element, &byte_size, nullptr));
        UInt32 vector_size = byte_size / sizeof(T);

        auto data = std::vector<T>(vector_size);

        if (vector_size > 0) {
            byte_size = vector_size * sizeof(T);
            yas_raise_if_au_error(
                AudioUnitGetProperty(audio_unit_instance(), property_id, scope, element, data.data(), &byte_size));
        }

        return data;
    }
}
