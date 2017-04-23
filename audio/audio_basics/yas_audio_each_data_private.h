//
//  yas_audio_each_data_private.h
//

#pragma once

#include "yas_audio_pcm_buffer.h"
#include "yas_audio_format.h"
#include "yas_fast_each.h"

namespace yas {
namespace audio {
    template <typename T>
    each_data<T> make_each_data(pcm_buffer &buffer) {
        auto const &format = buffer.format();
        auto const buffer_count = format.buffer_count();

        std::vector<T *> vec;
        vec.resize(buffer_count);

        auto each = make_fast_each(buffer_count);
        while (yas_each_next(each)) {
            auto const &idx = yas_each_index(each);
            vec[idx] = buffer.data_ptr_at_index<T>(idx);
        }

        return yas::make_each_data<T>(vec.data(), buffer.frame_length(), format.buffer_count(), format.stride());
    }
}
}
