//
//  yas_audio_unit_impl_private.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#pragma once

#include <AudioToolbox/AudioToolbox.h>
#include <memory>
#include <vector>
#include "yas_audio_exception.h"

template <typename T>
void yas::audio::unit::impl::set_property_data(std::vector<T> const &data, AudioUnitPropertyID const property_id,
                                               AudioUnitScope const scope, AudioUnitElement const element) {
    UInt32 const size = static_cast<UInt32>(data.size());
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
    UInt32 vector_size = byte_size / sizeof(T);

    auto data = std::vector<T>(vector_size);

    if (vector_size > 0) {
        byte_size = vector_size * sizeof(T);
        raise_if_au_error(AudioUnitGetProperty(au, property_id, scope, element, data.data(), &byte_size));
    }

    return data;
}
