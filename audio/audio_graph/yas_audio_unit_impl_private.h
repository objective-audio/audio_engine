//
//  yas_audio_unit_impl_private.h
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <vector>
#include "yas_audio_exception.h"

template <typename T>
void yas::audio::unit::impl::set_property_data(std::vector<T> const &data, AudioUnitPropertyID const property_id,
                                               AudioUnitScope const scope, AudioUnitElement const element) {
    uint32_t const size = static_cast<uint32_t>(data.size());
    const void *const raw_data = size > 0 ? data.data() : nullptr;

    raise_if_au_error(
        AudioUnitSetProperty(audio_unit_instance(), property_id, scope, element, raw_data, size * sizeof(T)));
}

template <typename T>
std::vector<T> yas::audio::unit::impl::property_data(AudioUnitPropertyID const property_id, AudioUnitScope const scope,
                                                     AudioUnitElement const element) const {
    AudioUnit au = audio_unit_instance();

    UInt32 byte_size = 0;
    raise_if_au_error(AudioUnitGetPropertyInfo(au, property_id, scope, element, &byte_size, nullptr));
    uint32_t vector_size = byte_size / sizeof(T);

    auto data = std::vector<T>(vector_size);

    if (vector_size > 0) {
        byte_size = vector_size * sizeof(T);
        raise_if_au_error(AudioUnitGetProperty(au, property_id, scope, element, data.data(), &byte_size));
    }

    return data;
}
