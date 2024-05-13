//
//  each_data.h
//

#pragma once

#include <cpp-utils/each_data.h>

namespace yas::audio {
class pcm_buffer;

template <typename T>
each_data<T> make_each_data(pcm_buffer &buffer);

template <typename T>
const_each_data<T> make_each_data(pcm_buffer const &buffer);
}  // namespace yas::audio

#include "each_data_private.h"
