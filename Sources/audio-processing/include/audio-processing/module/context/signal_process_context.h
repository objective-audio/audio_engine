//
//  signal_process_context.h
//

#pragma once

#include <audio-processing/event/signal_event.h>
#include <audio-processing/time/time.h>

namespace yas::proc {
template <typename T, std::size_t N>
struct signal_process_context {
    using pair_t = std::pair<time, signal_event_ptr>;
    using pair_vector_t = std::vector<pair_t>;

    signal_process_context();

    void reset(std::size_t const reserve_size);

    [[nodiscard]] pair_vector_t const &inputs() const;

    void copy_data_from(T const *ptr, std::size_t const size, std::size_t const idx);
    [[nodiscard]] T const *data(std::size_t const idx) const;

    void set_time(proc::time time, std::size_t const idx);
    [[nodiscard]] time const &time(std::size_t const idx) const;

   private:
    pair_vector_t _inputs;
};
}  // namespace yas::proc

#include "signal_process_context_private.h"
