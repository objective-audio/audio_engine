//
//  yas_audio_each_data_private.h
//

#pragma once

#include "yas_audio_pcm_buffer.h"
#include "yas_audio_format.h"
#include "yas_fast_each.h"

namespace yas::audio {
template <typename T>
each_data<T> make_each_data(pcm_buffer &buffer) {
    auto const &format = buffer.format();
    auto const buffer_count = format.buffer_count();

    std::vector<T *> vec;
    vec.reserve(buffer_count);

    auto each = make_fast_each(buffer_count);
    while (yas_each_next(each)) {
        vec.push_back(buffer.data_ptr_at_index<T>(yas_each_index(each)));
    }

    return yas::make_each_data<T>(vec.data(), buffer.frame_length(), format.buffer_count(), format.stride());
}

template <typename T>
const_each_data<T> make_each_data(pcm_buffer const &buffer) {
    auto const &format = buffer.format();
    auto const buffer_count = format.buffer_count();

    std::vector<T const *> vec;
    vec.reserve(buffer_count);

    auto each = make_fast_each(buffer_count);
    while (yas_each_next(each)) {
        vec.push_back(buffer.data_ptr_at_index<T>(yas_each_index(each)));
    }

    return yas::make_each_data<T>(vec.data(), buffer.frame_length(), format.buffer_count(), format.stride());
}
}
