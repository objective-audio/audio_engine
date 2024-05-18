//
//  number_to_signal_module.cpp
//

#include "number_to_signal_module.h"

#include <cpp-utils/boolean.h>
#include <cpp-utils/fast_each.h>
#include <audio-processing/event/number_event.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/module/context/number_process_context.h>
#include <audio-processing/module/module.h>
#include <audio-processing/processor/maker/receive_number_processor.h>
#include <audio-processing/processor/maker/remove_number_processor.h>
#include <audio-processing/processor/maker/send_signal_processor.h>

#include <map>

using namespace yas;
using namespace yas::proc;

template <typename T>
proc::module_ptr proc::make_number_to_signal_module() {
    auto make_processors = [] {
        auto context = std::make_shared<number_process_context<T, 1>>();

        auto prepare_processor = [context](time::range const &current_range, connector_map_t const &,
                                           connector_map_t const &,
                                           stream &) mutable { context->reset(current_range); };

        auto receive_processor = make_receive_number_processor<T>(
            [context](proc::time::frame::type const &frame, channel_index_t const, connector_index_t const,
                      T const &value) mutable { context->insert_input(frame, value, 0); });

        auto remove_processor = make_remove_number_processor<T>({to_connector_index(number_to_signal::input::number)});

        auto send_processor = make_send_signal_processor<T>(
            [context, out_each = fast_each<T *>{}](proc::time::range const &time_range, sync_source const &,
                                                   channel_index_t const, connector_index_t const,
                                                   T *const signal_ptr) mutable {
                auto const top_frame = time_range.frame;
                auto iterator = context->inputs().cbegin();
                auto const end_iterator = context->inputs().cend();
                T const &last_value = context->last_values()[0];

                out_each.reset(signal_ptr, time_range.length);
                while (yas_each_next(out_each)) {
                    auto const frame = top_frame + yas_each_index(out_each);
                    if (iterator != end_iterator) {
                        if (iterator->first == frame) {
                            context->update_last_values(iterator->second);
                            ++iterator;
                        }
                    }
                    yas_each_value(out_each) = last_value;
                }
            });

        return module::processors_t{{std::move(prepare_processor), std::move(receive_processor),
                                     std::move(remove_processor), std::move(send_processor)}};
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::make_number_to_signal_module<double>();
template proc::module_ptr proc::make_number_to_signal_module<float>();
template proc::module_ptr proc::make_number_to_signal_module<int64_t>();
template proc::module_ptr proc::make_number_to_signal_module<int32_t>();
template proc::module_ptr proc::make_number_to_signal_module<int16_t>();
template proc::module_ptr proc::make_number_to_signal_module<int8_t>();
template proc::module_ptr proc::make_number_to_signal_module<uint64_t>();
template proc::module_ptr proc::make_number_to_signal_module<uint32_t>();
template proc::module_ptr proc::make_number_to_signal_module<uint16_t>();
template proc::module_ptr proc::make_number_to_signal_module<uint8_t>();
template proc::module_ptr proc::make_number_to_signal_module<boolean>();

#pragma mark -

void yas::connect(proc::module_ptr const &module, proc::number_to_signal::input const &input,
                  proc::channel_index_t const &ch_idx) {
    module->connect_input(proc::to_connector_index(input), ch_idx);
}

void yas::connect(proc::module_ptr const &module, proc::number_to_signal::output const &output,
                  proc::channel_index_t const &ch_idx) {
    module->connect_output(proc::to_connector_index(output), ch_idx);
}

std::string yas::to_string(proc::number_to_signal::input const &input) {
    using namespace yas::proc::number_to_signal;

    switch (input) {
        case input::number:
            return "number";
    }

    throw "input not found.";
}

std::string yas::to_string(proc::number_to_signal::output const &output) {
    using namespace yas::proc::number_to_signal;

    switch (output) {
        case output::signal:
            return "signal";
    }

    throw "output not found.";
}

std::ostream &operator<<(std::ostream &os, yas::proc::number_to_signal::input const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::proc::number_to_signal::output const &value) {
    os << to_string(value);
    return os;
}
