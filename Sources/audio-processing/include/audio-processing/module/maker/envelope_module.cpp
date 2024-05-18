//
//  envelope_module.cpp
//

#include "envelope_module.h"

#include <cpp-utils/fast_each.h>
#include <audio-processing/module/module.h>
#include <audio-processing/module/module_utils.h>
#include <audio-processing/processor/maker/send_signal_processor.h>

using namespace yas;
using namespace yas::proc;

namespace yas::proc::envelope {
template <typename T>
struct context {
    context(anchors_t<T> &&anchors)
        : _anchors(std::move(anchors)), _prev(_anchors.cbegin()), _next(_anchors.cbegin()), _end(_anchors.cend()) {
    }

    void reset(time::range const &current_range) {
        if (this->_last_range && this->_last_range->next_frame() != current_range.frame) {
            this->_prev = this->_next = _anchors.cbegin();
        }

        this->_last_range = current_range;
    }

    T value(frame_index_t const env_frame) {
        if (this->_prev == this->_end) {
            return 0;
        }

        if (this->_prev == this->_next) {
            ++this->_next;
        }

        if (env_frame < this->_prev->first) {
            return this->_prev->second;
        }

        while (this->_next != this->_end) {
            if (env_frame < this->_next->first) {
                break;
            }
            this->_prev = this->_next;
            ++this->_next;
        }

        if (this->_next == this->_end) {
            return this->_prev->second;
        } else {
            auto const &prev_value = this->_prev->second;
            auto const &prev_frame = this->_prev->first;
            double const rate = double(env_frame - prev_frame) / (this->_next->first - prev_frame);
            return static_cast<T>((this->_next->second - prev_value) * rate + prev_value);
        }
    }

   private:
    anchors_t<T> _anchors;
    typename anchors_t<T>::const_iterator _prev;
    typename anchors_t<T>::const_iterator _next;
    typename anchors_t<T>::const_iterator _end;
    std::optional<time::range> _last_range;
};
}  // namespace yas::proc::envelope

template <typename T>
proc::module_ptr proc::envelope::make_signal_module(anchors_t<T> anchors, frame_index_t const module_offset) {
    auto context = std::make_shared<envelope::context<T>>(std::move(anchors));

    auto make_processors = [context = std::move(context), module_offset] {
        auto prepare_processor = [context](time::range const &current_range, connector_map_t const &,
                                           connector_map_t const &,
                                           stream &) mutable { context->reset(current_range); };

        auto send_processor = proc::make_send_signal_processor<T>(
            [context, module_offset, out_each = fast_each<T *>{}](
                proc::time::range const &time_range, sync_source const &sync_src, channel_index_t const,
                connector_index_t const co_idx, T *const signal_ptr) mutable {
                static auto const output_co_idx = to_connector_index(output::value);
                if (co_idx == output_co_idx) {
                    out_each.reset(signal_ptr, time_range.length);

                    while (yas_each_next(out_each)) {
                        auto const &idx = yas_each_index(out_each);
                        auto const env_idx = module_frame(time_range.frame, module_offset) + idx;
                        yas_each_value(out_each) = context->value(env_idx);
                    }
                }
            });

        return module::processors_t{{std::move(prepare_processor), std::move(send_processor)}};
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::envelope::make_signal_module(anchors_t<double>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<float>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<int64_t>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<int32_t>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<int16_t>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<int8_t>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<uint64_t>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<uint32_t>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<uint16_t>, frame_index_t const);
template proc::module_ptr proc::envelope::make_signal_module(anchors_t<uint8_t>, frame_index_t const);

void yas::connect(proc::module_ptr const &module, proc::envelope::output const &output,
                  proc::channel_index_t const &ch_idx) {
    module->connect_output(proc::to_connector_index(output), ch_idx);
}

std::string yas::to_string(proc::envelope::output const &output) {
    using namespace yas::proc::envelope;

    switch (output) {
        case output::value:
            return "value";
    }

    throw "output not found.";
}

std::ostream &operator<<(std::ostream &os, yas::proc::envelope::output const &value) {
    os << to_string(value);
    return os;
}
