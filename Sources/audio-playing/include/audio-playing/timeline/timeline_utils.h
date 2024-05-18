//
//  timeline_utils.h
//

#pragma once

#include <audio-engine/common/types.h>
#include <audio-engine/pcm_buffer/pcm_buffer.h>
#include <audio-playing/common/types.h>
#include <audio-processing/event/number_event.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/time/time.h>
#include <cpp-utils/result.h>

namespace yas::playing::timeline_utils {
[[nodiscard]] proc::time::range fragments_range(proc::time::range const &, sample_rate_t const);

[[nodiscard]] char const *char_data(proc::signal_event const &);
[[nodiscard]] char const *char_data(proc::time::frame::type const &);
[[nodiscard]] char const *char_data(sample_store_type const &);
[[nodiscard]] char const *char_data(proc::number_event const &);
[[nodiscard]] char *char_data(audio::pcm_buffer &);

[[nodiscard]] sample_store_type to_sample_store_type(std::type_info const &);
[[nodiscard]] std::type_info const &to_sample_type(sample_store_type const &);
}  // namespace yas::playing::timeline_utils
