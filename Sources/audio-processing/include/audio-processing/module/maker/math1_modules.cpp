//
//  math1_modules.cpp
//

#include "math1_modules.h"

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
proc::module_ptr proc::make_signal_module(math1::kind const kind) {
    using namespace yas::proc::math1;

    auto make_processors = [kind] {
        auto context = std::make_shared<signal_process_context<T, 1>>();

        auto prepare_processor = [context](time::range const &, connector_map_t const &, connector_map_t const &,
                                           stream &stream) mutable {
            context->reset(stream.sync_source().slice_length);
        };

        auto receive_processor = proc::make_receive_signal_processor<T>(
            [context](time::range const &time_range, sync_source const &, channel_index_t const,
                      connector_index_t const co_idx, T const *const signal_ptr) mutable {
                if (co_idx == to_connector_index(input::parameter)) {
                    context->set_time(time{time_range}, co_idx);
                    context->copy_data_from(signal_ptr, time_range.length, co_idx);
                }
            });

        auto send_processor = proc::make_send_signal_processor<T>(
            [context, kind, out_each = fast_each<T *>{}](proc::time::range const &time_range, sync_source const &,
                                                         channel_index_t const, connector_index_t const co_idx,
                                                         T *const signal_ptr) mutable {
                if (co_idx == to_connector_index(output::result)) {
                    auto const input_co_idx = to_connector_index(input::parameter);

                    T const *const input_ptr = context->data(input_co_idx);
                    proc::time const &input_time = context->time(input_co_idx);
                    auto const input_offset = input_time ? time_range.frame - input_time.get<time::range>().frame : 0;
                    auto const &input_length =
                        input_time ? input_time.get<time::range>().length : constant::zero_length;

                    out_each.reset(signal_ptr, time_range.length);
                    while (yas_each_next(out_each)) {
                        auto const &idx = yas_each_index(out_each);
                        auto const input_idx = idx + input_offset;

                        static T constexpr zero_value = 0;
                        auto const &input_value =
                            (input_idx >= 0 && input_idx < input_length) ? input_ptr[input_idx] : zero_value;

                        switch (kind) {
                            case kind::sin:
                                yas_each_value(out_each) = std::sin(input_value);
                                break;
                            case kind::cos:
                                yas_each_value(out_each) = std::cos(input_value);
                                break;
                            case kind::tan:
                                yas_each_value(out_each) = std::tan(input_value);
                                break;
                            case kind::asin:
                                yas_each_value(out_each) = std::asin(input_value);
                                break;
                            case kind::acos:
                                yas_each_value(out_each) = std::acos(input_value);
                                break;
                            case kind::atan:
                                yas_each_value(out_each) = std::atan(input_value);
                                break;

                            case kind::sinh:
                                yas_each_value(out_each) = std::sinh(input_value);
                                break;
                            case kind::cosh:
                                yas_each_value(out_each) = std::cosh(input_value);
                                break;
                            case kind::tanh:
                                yas_each_value(out_each) = std::tanh(input_value);
                                break;
                            case kind::asinh:
                                yas_each_value(out_each) = std::asinh(input_value);
                                break;
                            case kind::acosh:
                                yas_each_value(out_each) = std::acosh(input_value);
                                break;
                            case kind::atanh:
                                yas_each_value(out_each) = std::atanh(input_value);
                                break;

                            case kind::exp:
                                yas_each_value(out_each) = std::exp(input_value);
                                break;
                            case kind::exp2:
                                yas_each_value(out_each) = std::exp2(input_value);
                                break;
                            case kind::expm1:
                                yas_each_value(out_each) = std::expm1(input_value);
                                break;
                            case kind::log:
                                yas_each_value(out_each) = std::log(input_value);
                                break;
                            case kind::log10:
                                yas_each_value(out_each) = std::log10(input_value);
                                break;
                            case kind::log1p:
                                yas_each_value(out_each) = std::log1p(input_value);
                                break;
                            case kind::log2:
                                yas_each_value(out_each) = std::log2(input_value);
                                break;

                            case kind::sqrt:
                                yas_each_value(out_each) = std::sqrt(input_value);
                                break;
                            case kind::cbrt:
                                yas_each_value(out_each) = std::cbrt(input_value);
                                break;
                            case kind::abs:
                                yas_each_value(out_each) = std::abs(input_value);
                                break;

                            case kind::ceil:
                                yas_each_value(out_each) = std::ceil(input_value);
                                break;
                            case kind::floor:
                                yas_each_value(out_each) = std::floor(input_value);
                                break;
                            case kind::trunc:
                                yas_each_value(out_each) = std::trunc(input_value);
                                break;
                            case kind::round:
                                yas_each_value(out_each) = std::round(input_value);
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

template proc::module_ptr proc::make_signal_module<double>(math1::kind const);
template proc::module_ptr proc::make_signal_module<float>(math1::kind const);

#pragma mark - number

template <typename T>
proc::module_ptr proc::make_number_module(math1::kind const kind) {
    using namespace yas::proc::math1;

    auto make_processors = [kind] {
        auto context = std::make_shared<number_process_context<T, 1>>();

        auto prepare_processor = [context](time::range const &current_range, connector_map_t const &,
                                           connector_map_t const &,
                                           stream &stream) mutable { context->reset(current_range); };

        auto receive_processor =
            make_receive_number_processor<T>([context](proc::time::frame::type const &frame, channel_index_t const,
                                                       connector_index_t const co_idx, T const &value) mutable {
                if (co_idx == to_connector_index(input::parameter)) {
                    context->insert_input(frame, value, 0);
                }
            });

        auto send_processor = make_send_number_processor<T>([context, kind](proc::time::range const &,
                                                                            sync_source const &, channel_index_t const,
                                                                            connector_index_t const co_idx) mutable {
            number_event::value_map_t<T> result;

            if (co_idx == to_connector_index(output::result)) {
                static auto const input_co_idx = to_connector_index(input::parameter);

                for (auto const &input_pair : context->inputs()) {
                    auto const &input_value = *input_pair.second.values[input_co_idx];
                    T result_value = 0;

                    switch (kind) {
                        case kind::sin:
                            result_value = std::sin(input_value);
                            break;
                        case kind::cos:
                            result_value = std::cos(input_value);
                            break;
                        case kind::tan:
                            result_value = std::tan(input_value);
                            break;
                        case kind::asin:
                            result_value = std::asin(input_value);
                            break;
                        case kind::acos:
                            result_value = std::acos(input_value);
                            break;
                        case kind::atan:
                            result_value = std::atan(input_value);
                            break;

                        case kind::sinh:
                            result_value = std::sinh(input_value);
                            break;
                        case kind::cosh:
                            result_value = std::cosh(input_value);
                            break;
                        case kind::tanh:
                            result_value = std::tanh(input_value);
                            break;
                        case kind::asinh:
                            result_value = std::asinh(input_value);
                            break;
                        case kind::acosh:
                            result_value = std::acosh(input_value);
                            break;
                        case kind::atanh:
                            result_value = std::atanh(input_value);
                            break;

                        case kind::exp:
                            result_value = std::exp(input_value);
                            break;
                        case kind::exp2:
                            result_value = std::exp2(input_value);
                            break;
                        case kind::expm1:
                            result_value = std::expm1(input_value);
                            break;
                        case kind::log:
                            result_value = std::log(input_value);
                            break;
                        case kind::log10:
                            result_value = std::log10(input_value);
                            break;
                        case kind::log1p:
                            result_value = std::log1p(input_value);
                            break;
                        case kind::log2:
                            result_value = std::log2(input_value);
                            break;

                        case kind::sqrt:
                            result_value = std::sqrt(input_value);
                            break;
                        case kind::cbrt:
                            result_value = std::cbrt(input_value);
                            break;
                        case kind::abs:
                            result_value = std::abs(input_value);
                            break;

                        case kind::ceil:
                            result_value = std::ceil(input_value);
                            break;
                        case kind::floor:
                            result_value = std::floor(input_value);
                            break;
                        case kind::trunc:
                            result_value = std::trunc(input_value);
                            break;
                        case kind::round:
                            result_value = std::round(input_value);
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

template proc::module_ptr proc::make_number_module<double>(math1::kind const);
template proc::module_ptr proc::make_number_module<float>(math1::kind const);

#pragma mark -

void yas::connect(proc::module_ptr const &module, proc::math1::input const &input,
                  proc::channel_index_t const &ch_idx) {
    module->connect_input(proc::to_connector_index(input), ch_idx);
}

void yas::connect(proc::module_ptr const &module, proc::math1::output const &output,
                  proc::channel_index_t const &ch_idx) {
    module->connect_output(proc::to_connector_index(output), ch_idx);
}

std::string yas::to_string(proc::math1::kind const &kind) {
    using namespace proc::math1;

    switch (kind) {
        case kind::sin:
            return "sin";

        case kind::cos:
            return "cos";
        case kind::tan:
            return "tan";
        case kind::asin:
            return "asin";
        case kind::acos:
            return "acos";
        case kind::atan:
            return "atan";

        case kind::sinh:
            return "sinh";
        case kind::cosh:
            return "cosh";
        case kind::tanh:
            return "tanh";
        case kind::asinh:
            return "asinh";
        case kind::acosh:
            return "acosh";
        case kind::atanh:
            return "atanh";

        case kind::exp:
            return "exp";
        case kind::exp2:
            return "exp2";
        case kind::expm1:
            return "expm1";
        case kind::log:
            return "log";
        case kind::log10:
            return "log10";
        case kind::log1p:
            return "log1p";
        case kind::log2:
            return "log2";

        case kind::sqrt:
            return "sqrt";
        case kind::cbrt:
            return "cbrt";
        case kind::abs:
            return "abs";

        case kind::ceil:
            return "ceil";
        case kind::floor:
            return "floor";
        case kind::trunc:
            return "trunc";
        case kind::round:
            return "round";
    }

    throw "kind not found.";
}

std::string yas::to_string(proc::math1::input const &input) {
    using namespace proc::math1;

    switch (input) {
        case input::parameter:
            return "parameter";
    }

    throw "input not found.";
}

std::string yas::to_string(proc::math1::output const &output) {
    using namespace proc::math1;

    switch (output) {
        case output::result:
            return "result";
    }

    throw "output not found.";
}

std::ostream &operator<<(std::ostream &os, yas::proc::math1::kind const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::proc::math1::input const &value) {
    os << to_string(value);
    return os;
}

std::ostream &operator<<(std::ostream &os, yas::proc::math1::output const &value) {
    os << to_string(value);
    return os;
}
