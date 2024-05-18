//
//  compare_modules.cpp
//

#include "compare_modules.h"

#include <cpp-utils/boolean.h>
#include <cpp-utils/fast_each.h>
#include <audio-processing/common/constants.h>
#include <audio-processing/event/signal_event.h>
#include <audio-processing/module/context/number_process_context.h>
#include <audio-processing/module/context/signal_process_context.h>
#include <audio-processing/module/module.h>
#include <audio-processing/processor/maker/receive_number_processor.h>
#include <audio-processing/processor/maker/receive_signal_processor.h>
#include <audio-processing/processor/maker/send_number_processor.h>
#include <audio-processing/processor/maker/send_signal_processor.h>

using namespace yas;
using namespace yas::proc;

#pragma mark - signal

template <typename T>
proc::module_ptr proc::make_signal_module(compare::kind const kind) {
    using namespace yas::proc::compare;

    auto make_processors = [kind] {
        auto context = std::make_shared<signal_process_context<T, 2>>();

        auto prepare_processor = [context](time::range const &, connector_map_t const &, connector_map_t const &,
                                           stream &stream) mutable {
            context->reset(stream.sync_source().slice_length);
        };

        auto receive_processor = proc::make_receive_signal_processor<T>(
            [context](time::range const &time_range, sync_source const &, channel_index_t const,
                      connector_index_t const co_idx, T const *const signal_ptr) mutable {
                if (co_idx == to_connector_index(input::left) || co_idx == to_connector_index(input::right)) {
                    context->set_time(time{time_range}, co_idx);
                    context->copy_data_from(signal_ptr, time_range.length, co_idx);
                }
            });

        auto send_processor = proc::make_send_signal_processor<boolean>(
            [context, kind, out_each = fast_each<boolean *>{}](proc::time::range const &time_range, sync_source const &,
                                                               channel_index_t const, connector_index_t const co_idx,
                                                               boolean *const signal_ptr) mutable {
                if (co_idx == to_connector_index(output::result)) {
                    static auto const left_co_idx = to_connector_index(input::left);
                    static auto const right_co_idx = to_connector_index(input::right);

                    auto const *left_ptr = context->data(left_co_idx);
                    auto const *right_ptr = context->data(right_co_idx);
                    proc::time const &left_time = context->time(left_co_idx);
                    proc::time const &right_time = context->time(right_co_idx);
                    auto const left_offset = left_time ? time_range.frame - left_time.get<time::range>().frame : 0;
                    auto const right_offset = right_time ? time_range.frame - right_time.get<time::range>().frame : 0;
                    auto const &left_length = left_time ? left_time.get<time::range>().length : constant::zero_length;
                    auto const &right_length =
                        right_time ? right_time.get<time::range>().length : constant::zero_length;

                    out_each.reset(signal_ptr, time_range.length);
                    while (yas_each_next(out_each)) {
                        auto const &idx = yas_each_index(out_each);
                        auto const left_idx = idx + left_offset;
                        auto const right_idx = idx + right_offset;
                        auto const &left_value = (left_idx >= 0 && left_idx < left_length) ? left_ptr[left_idx] : 0;
                        auto const &right_value =
                            (right_idx >= 0 && right_idx < right_length) ? right_ptr[right_idx] : 0;

                        switch (kind) {
                            case kind::is_equal:
                                yas_each_value(out_each) = left_value == right_value;
                                break;
                            case kind::is_not_equal:
                                yas_each_value(out_each) = left_value != right_value;
                                break;

                            case kind::is_greater:
                                yas_each_value(out_each) = left_value > right_value;
                                break;
                            case kind::is_greater_equal:
                                yas_each_value(out_each) = left_value >= right_value;
                                break;
                            case kind::is_less:
                                yas_each_value(out_each) = left_value < right_value;
                                break;
                            case kind::is_less_equal:
                                yas_each_value(out_each) = left_value <= right_value;
                                break;
                        }
                    }
                }
            });
        return module::processors_t{
            {std::move(prepare_processor), std::move(receive_processor), std::move(send_processor)}};
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::make_signal_module<double>(compare::kind const);
template proc::module_ptr proc::make_signal_module<float>(compare::kind const);
template proc::module_ptr proc::make_signal_module<int64_t>(compare::kind const);
template proc::module_ptr proc::make_signal_module<int32_t>(compare::kind const);
template proc::module_ptr proc::make_signal_module<int16_t>(compare::kind const);
template proc::module_ptr proc::make_signal_module<int8_t>(compare::kind const);
template proc::module_ptr proc::make_signal_module<uint64_t>(compare::kind const);
template proc::module_ptr proc::make_signal_module<uint32_t>(compare::kind const);
template proc::module_ptr proc::make_signal_module<uint16_t>(compare::kind const);
template proc::module_ptr proc::make_signal_module<uint8_t>(compare::kind const);
template proc::module_ptr proc::make_signal_module<boolean>(compare::kind const);

#pragma mark - number

template <typename T>
proc::module_ptr proc::make_number_module(compare::kind const kind) {
    using namespace yas::proc::compare;

    auto make_processors = [kind] {
        auto context = std::make_shared<number_process_context<T, 2>>();

        auto prepare_processor = [context](time::range const &current_range, connector_map_t const &,
                                           connector_map_t const &,
                                           stream &stream) mutable { context->reset(current_range); };

        auto receive_processor =
            make_receive_number_processor<T>([context](proc::time::frame::type const &frame, channel_index_t const,
                                                       connector_index_t const co_idx, T const &value) mutable {
                if (co_idx == to_connector_index(input::left)) {
                    context->insert_input(frame, value, co_idx);
                } else if (co_idx == to_connector_index(input::right)) {
                    context->insert_input(frame, value, co_idx);
                }
            });

        auto send_processor = make_send_number_processor<boolean>(
            [context, kind](proc::time::range const &, sync_source const &, channel_index_t const,
                            connector_index_t const co_idx) mutable {
                number_event::value_map_t<boolean> result;

                if (co_idx == to_connector_index(output::result)) {
                    auto const left_co_idx = to_connector_index(input::left);
                    auto const right_co_idx = to_connector_index(input::right);
                    T const *last_values = context->last_values().data();

                    for (auto const &input_pair : context->inputs()) {
                        auto const &input = input_pair.second;
                        context->update_last_values(input);

                        T const &left_value = last_values[left_co_idx];
                        T const &right_value = last_values[right_co_idx];

                        boolean result_value;

                        switch (kind) {
                            case kind::is_equal:
                                result_value = left_value == right_value;
                                break;
                            case kind::is_not_equal:
                                result_value = left_value != right_value;
                                break;

                            case kind::is_greater:
                                result_value = left_value > right_value;
                                break;
                            case kind::is_greater_equal:
                                result_value = left_value >= right_value;
                                break;
                            case kind::is_less:
                                result_value = left_value < right_value;
                                break;
                            case kind::is_less_equal:
                                result_value = left_value <= right_value;
                                break;
                        }

                        result.emplace(input_pair.first, result_value);
                    }
                }

                return result;
            });

        return module::processors_t{
            {std::move(prepare_processor), std::move(receive_processor), std::move(send_processor)}};
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::make_number_module<double>(compare::kind const);
template proc::module_ptr proc::make_number_module<float>(compare::kind const);
template proc::module_ptr proc::make_number_module<int64_t>(compare::kind const);
template proc::module_ptr proc::make_number_module<int32_t>(compare::kind const);
template proc::module_ptr proc::make_number_module<int16_t>(compare::kind const);
template proc::module_ptr proc::make_number_module<int8_t>(compare::kind const);
template proc::module_ptr proc::make_number_module<uint64_t>(compare::kind const);
template proc::module_ptr proc::make_number_module<uint32_t>(compare::kind const);
template proc::module_ptr proc::make_number_module<uint16_t>(compare::kind const);
template proc::module_ptr proc::make_number_module<uint8_t>(compare::kind const);
template proc::module_ptr proc::make_number_module<boolean>(compare::kind const);

#pragma mark -

void yas::connect(proc::module_ptr const &module, proc::compare::input const &input,
                  proc::channel_index_t const &ch_idx) {
    module->connect_input(proc::to_connector_index(input), ch_idx);
}

void yas::connect(proc::module_ptr const &module, proc::compare::output const &output,
                  proc::channel_index_t const &ch_idx) {
    module->connect_output(proc::to_connector_index(output), ch_idx);
}

std::string yas::to_string(proc::compare::input const &input) {
    using namespace yas::proc::compare;

    switch (input) {
        case input::left:
            return "left";
        case input::right:
            return "right";
    }

    throw "input not found.";
}

std::string yas::to_string(proc::compare::output const &output) {
    using namespace yas::proc::compare;

    switch (output) {
        case output::result:
            return "result";
    }

    throw "output not found.";
}

std::ostream &operator<<(std::ostream &os, yas::proc::compare::input const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::proc::compare::output const &value) {
    os << to_string(value);
    return os;
}
