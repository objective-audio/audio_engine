//
//  routing_module.cpp
//

#include "routing_modules.h"

#include <cpp-utils/boolean.h>
#include <cpp-utils/fast_each.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/module/context/number_process_context.h>
#include <audio-processing/module/context/signal_process_context.h>
#include <audio-processing/module/module.h>
#include <audio-processing/processor/maker/receive_number_processor.h>
#include <audio-processing/processor/maker/receive_signal_processor.h>
#include <audio-processing/processor/maker/remove_number_processor.h>
#include <audio-processing/processor/maker/remove_signal_processor.h>
#include <audio-processing/processor/maker/send_number_processor.h>
#include <audio-processing/processor/maker/send_signal_processor.h>

using namespace yas;
using namespace yas::proc;

#pragma mark - signal

template <typename T>
proc::module_ptr proc::make_signal_module(proc::routing::kind const kind) {
    using namespace yas::proc::routing;

    auto make_processors = [kind] {
        auto context = std::make_shared<signal_process_context<T, 1>>();

        auto prepare_processor = [context](time::range const &, connector_map_t const &, connector_map_t const &,
                                           stream &stream) mutable {
            context->reset(stream.sync_source().slice_length);
        };

        auto receive_processor = proc::make_receive_signal_processor<T>(
            [context](time::range const &time_range, sync_source const &, channel_index_t const,
                      connector_index_t const co_idx, T const *const signal_ptr) mutable {
                if (co_idx == to_connector_index(input::value)) {
                    context->set_time(time{time_range}, co_idx);
                    context->copy_data_from(signal_ptr, time_range.length, co_idx);
                }
            });

        auto send_processor = proc::make_send_signal_processor<T>(
            [context, kind, out_each = fast_each<T *>{}](proc::time::range const &time_range, sync_source const &,
                                                         channel_index_t const, connector_index_t const co_idx,
                                                         T *const signal_ptr) mutable {
                if (co_idx == to_connector_index(output::value)) {
                    static auto const input_co_idx = to_connector_index(input::value);

                    auto const *src_ptr = context->data(input_co_idx);
                    proc::time const &input_time = context->time(input_co_idx);
                    auto const src_offset = input_time ? time_range.frame - input_time.get<time::range>().frame : 0;
                    auto const &src_length = input_time ? input_time.get<time::range>().length : 0;

                    out_each.reset(signal_ptr, time_range.length);
                    while (yas_each_next(out_each)) {
                        auto const &idx = yas_each_index(out_each);
                        auto const src_idx = idx + src_offset;
                        auto const &src_value = (src_idx >= 0 && src_idx < src_length) ? src_ptr[src_idx] : 0;
                        yas_each_value(out_each) = src_value;
                    }
                }
            });

        module::processors_t processors{prepare_processor, receive_processor};
        if (kind == kind::move) {
            auto remove_processor = proc::make_remove_signal_processor<T>({to_connector_index(input::value)});
            processors.emplace_back(std::move(remove_processor));
        }
        processors.emplace_back(std::move(send_processor));
        return processors;
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::make_signal_module<double>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<float>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<int64_t>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<int32_t>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<int16_t>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<int8_t>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<uint64_t>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<uint32_t>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<uint16_t>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<uint8_t>(proc::routing::kind const);
template proc::module_ptr proc::make_signal_module<boolean>(proc::routing::kind const);

#pragma mark - number

template <typename T>
proc::module_ptr proc::make_number_module(routing::kind const kind) {
    using namespace yas::proc::routing;

    auto make_processors = [kind] {
        auto context = std::make_shared<number_process_context<T, 1>>();

        auto prepare_processor = [context](time::range const &current_range, connector_map_t const &,
                                           connector_map_t const &,
                                           stream &stream) mutable { context->reset(current_range); };

        auto receive_processor =
            make_receive_number_processor<T>([context](proc::time::frame::type const &frame, channel_index_t const,
                                                       connector_index_t const co_idx, T const &value) mutable {
                if (co_idx == to_connector_index(input::value)) {
                    context->insert_input(frame, value, 0);
                }
            });

        auto send_processor = make_send_number_processor<T>([context, kind](proc::time::range const &,
                                                                            sync_source const &, channel_index_t const,
                                                                            connector_index_t const co_idx) mutable {
            number_event::value_map_t<T> result;

            if (co_idx == to_connector_index(output::value)) {
                static auto const input_co_idx = to_connector_index(input::value);

                for (auto const &input_pair : context->inputs()) {
                    auto const &input_value = *input_pair.second.values[input_co_idx];
                    result.emplace(input_pair.first, input_value);
                }
            }

            return result;
        });

        module::processors_t processors{prepare_processor, receive_processor};
        if (kind == kind::move) {
            auto remove_processor = proc::make_remove_number_processor<T>({to_connector_index(input::value)});
            processors.emplace_back(std::move(remove_processor));
        }
        processors.emplace_back(std::move(send_processor));

        return processors;
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::make_number_module<double>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<float>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<int64_t>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<int32_t>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<int16_t>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<int8_t>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<uint64_t>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<uint32_t>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<uint16_t>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<uint8_t>(proc::routing::kind const);
template proc::module_ptr proc::make_number_module<boolean>(proc::routing::kind const);

#pragma mark -

void yas::connect(proc::module_ptr const &module, proc::routing::input const &input,
                  proc::channel_index_t const &ch_idx) {
    module->connect_input(proc::to_connector_index(input), ch_idx);
}

void yas::connect(proc::module_ptr const &module, proc::routing::output const &output,
                  proc::channel_index_t const &ch_idx) {
    module->connect_output(proc::to_connector_index(output), ch_idx);
}

std::string yas::to_string(proc::routing::input const &input) {
    using namespace yas::proc::routing;

    switch (input) {
        case input::value:
            return "value";
    }

    throw "input not found.";
}

std::string yas::to_string(proc::routing::output const &output) {
    using namespace yas::proc::routing;

    switch (output) {
        case output::value:
            return "value";
    }

    throw "output not found.";
}

std::ostream &operator<<(std::ostream &os, yas::proc::routing::input const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::proc::routing::output const &value) {
    os << to_string(value);
    return os;
}
