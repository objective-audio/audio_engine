//
//  generator_modules.cpp
//

#include "generator_modules.h"

#include <cpp-utils/fast_each.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/module/module.h>
#include <audio-processing/processor/maker/send_signal_processor.h>
#include <audio-processing/sync_source/sync_source.h>

using namespace yas;
using namespace yas::proc;

template <typename T>
proc::module_ptr proc::make_signal_module(generator::kind const kind, frame_index_t const frame_offset) {
    using namespace yas::proc::generator;

    auto make_processors = [kind, frame_offset] {
        auto prepare_processor = [](time::range const &, connector_map_t const &, connector_map_t const &,
                                    stream &) mutable {};

        auto send_processor = proc::make_send_signal_processor<T>(
            [kind, frame_offset, out_each = fast_each<T *>{}](
                proc::time::range const &time_range, sync_source const &sync_src, channel_index_t const,
                connector_index_t const co_idx, T *const signal_ptr) mutable {
                if (co_idx == to_connector_index(output::value)) {
                    out_each.reset(signal_ptr, time_range.length);
                    auto const top_idx = frame_offset + time_range.frame;
                    T const sr = sync_src.sample_rate;

                    while (yas_each_next(out_each)) {
                        auto const &idx = yas_each_index(out_each);
                        switch (kind) {
                            case kind::second:
                                yas_each_value(out_each) = (T)(top_idx + idx) / sr;
                                break;
                            case kind::frame:
                                yas_each_value(out_each) = (T)(top_idx + idx);
                                break;
                        }
                    }
                }
            });

        return module::processors_t{{std::move(prepare_processor), std::move(send_processor)}};
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::make_signal_module<double>(generator::kind const, frame_index_t const);
template proc::module_ptr proc::make_signal_module<float>(generator::kind const, frame_index_t const);
template proc::module_ptr proc::make_signal_module<int64_t>(generator::kind const, frame_index_t const);

#pragma mark -

void yas::connect(proc::module_ptr const &module, proc::generator::output const &output,
                  proc::channel_index_t const &ch_idx) {
    module->connect_output(proc::to_connector_index(output), ch_idx);
}

std::string yas::to_string(proc::generator::output const &output) {
    using namespace yas::proc::generator;

    switch (output) {
        case output::value:
            return "value";
    }

    throw "output not found.";
}

std::ostream &operator<<(std::ostream &os, yas::proc::generator::output const &value) {
    os << to_string(value);
    return os;
}
