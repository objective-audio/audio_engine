//
//  number_process_context.h
//

#pragma once

#include <audio-processing/common/common_types.h>
#include <audio-processing/time/time.h>

#include <map>
#include <optional>
#include <vector>

namespace yas::proc {
template <typename T, std::size_t N>
struct number_process_context {
    struct input {
        std::optional<T> values[N];
    };

    number_process_context();

    void insert_input(frame_index_t const &frame, T const &value, std::size_t const idx);
    void update_last_values(input const &input);
    void reset(time::range const &);

    [[nodiscard]] std::map<frame_index_t, input> const &inputs() const;
    [[nodiscard]] std::vector<T> const &last_values() const;

   private:
    std::map<frame_index_t, input> _inputs;
    std::vector<T> _last_values;
    std::optional<time::range> _last_process_range;
};
}  // namespace yas::proc

#include "number_process_context_private.h"
