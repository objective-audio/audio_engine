//
//  constant_module.cpp
//

#include "constant_module.h"

#include <cpp-utils/boolean.h>
#include <cpp-utils/fast_each.h>
#include <audio-processing/module/module.h>
#include <audio-processing/processor/maker/send_number_processor.h>
#include <audio-processing/processor/maker/send_signal_processor.h>

using namespace yas;
using namespace yas::proc;

template <typename T>
proc::module_ptr proc::make_signal_module(T value) {
    auto make_processors = [value] {
        return module::processors_t{{proc::make_send_signal_processor<T>(
            [value, each = fast_each<T *>{}](proc::time::range const &time_range, sync_source const &,
                                             channel_index_t const, connector_index_t const,
                                             T *const signal_ptr) mutable {
                each.reset(signal_ptr, time_range.length);

                while (yas_each_next(each)) {
                    yas_each_value(each) = value;
                }
            })}};
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::make_signal_module(double);
template proc::module_ptr proc::make_signal_module(float);
template proc::module_ptr proc::make_signal_module(int64_t);
template proc::module_ptr proc::make_signal_module(int32_t);
template proc::module_ptr proc::make_signal_module(int16_t);
template proc::module_ptr proc::make_signal_module(int8_t);
template proc::module_ptr proc::make_signal_module(uint64_t);
template proc::module_ptr proc::make_signal_module(uint32_t);
template proc::module_ptr proc::make_signal_module(uint16_t);
template proc::module_ptr proc::make_signal_module(uint8_t);
template proc::module_ptr proc::make_signal_module(boolean);

template <typename T>
proc::module_ptr proc::make_number_module(T value) {
    auto make_processors = [value]() {
        return module::processors_t{{proc::make_send_number_processor<T>(
            [value](proc::time::range const &time_range, sync_source const &, channel_index_t const,
                    connector_index_t const) { return number_event::value_map_t<T>{{time_range.frame, value}}; })}};
    };

    return proc::module::make_shared(std::move(make_processors));
}

template proc::module_ptr proc::make_number_module(double);
template proc::module_ptr proc::make_number_module(float);
template proc::module_ptr proc::make_number_module(int64_t);
template proc::module_ptr proc::make_number_module(int32_t);
template proc::module_ptr proc::make_number_module(int16_t);
template proc::module_ptr proc::make_number_module(int8_t);
template proc::module_ptr proc::make_number_module(uint64_t);
template proc::module_ptr proc::make_number_module(uint32_t);
template proc::module_ptr proc::make_number_module(uint16_t);
template proc::module_ptr proc::make_number_module(uint8_t);
template proc::module_ptr proc::make_number_module(boolean);
