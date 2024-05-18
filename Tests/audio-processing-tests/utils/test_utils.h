//
//  test_utils.h
//

#pragma once

#include <audio-processing/connector/connector.h>
#include <audio-processing/time/time.h>

#include <filesystem>
#include <functional>

using namespace yas;
using namespace yas::proc;

namespace yas::proc::test_utils {
std::filesystem::path test_path();
void create_test_directory();
void remove_contents_in_test_directory();
}  // namespace yas::proc::test_utils

namespace yas {
namespace test {
    using process_f = std::function<void(proc::time::range const &, proc::connector_map_t const &,
                                         proc::connector_map_t const &, proc::stream &)>;

    template <typename T, typename Kind>
    static module_ptr make_signal_module(Kind const kind, channel_index_t const ch_idx) {
        auto module = proc::make_signal_module<T>(kind);
        connect(module, math1::input::parameter, ch_idx);
        connect(module, math1::output::result, ch_idx);

        return module;
    }

    template <typename T, typename Kind>
    static module_ptr make_number_module(Kind const kind, channel_index_t const ch_idx) {
        auto module = proc::make_number_module<T>(kind);
        connect(module, math1::input::parameter, ch_idx);
        connect(module, math1::output::result, ch_idx);

        return module;
    }

    template <typename T>
    static stream make_signal_stream(time::range const time_range, T const *const data,
                                     time::range const data_time_range, channel_index_t const ch_idx) {
        stream stream{sync_source{1, time_range.length}};

        auto &channel = stream.add_channel(ch_idx);

        signal_event_ptr phase_signal = signal_event::make_shared<T>(data_time_range.length);
        auto *phase_data = phase_signal->data<T>();
        auto each = make_fast_each_ptr(phase_data, data_time_range.length);
        while (yas_each_next(each)) {
            yas_each_value(each) = data[yas_each_index(each)];
        }

        channel.insert_event(proc::time{data_time_range}, std::move(phase_signal));

        return stream;
    }

    template <typename T>
    static stream make_signal_stream(time::range const time_range, T const *const left_data,
                                     time::range const left_time_range, channel_index_t const left_ch_idx,
                                     T const *const right_data, time::range const right_time_range,
                                     channel_index_t const right_ch_idx) {
        stream stream{sync_source{1, time_range.length}};

        {
            auto &channel = stream.add_channel(left_ch_idx);

            signal_event_ptr signal = signal_event::make_shared<T>(left_time_range.length);
            auto *out_data = signal->data<T>();
            auto each = make_fast_each_ptr(out_data, left_time_range.length);
            while (yas_each_next(each)) {
                yas_each_value(each) = left_data[yas_each_index(each)];
            }

            channel.insert_event(proc::time{left_time_range}, std::move(signal));
        }

        {
            auto &channel = stream.add_channel(right_ch_idx);

            signal_event_ptr signal = signal_event::make_shared<T>(right_time_range.length);
            auto *out_data = signal->data<T>();
            auto each = make_fast_each_ptr(out_data, right_time_range.length);
            while (yas_each_next(each)) {
                yas_each_value(each) = right_data[yas_each_index(each)];
            }

            channel.insert_event(proc::time{right_time_range}, std::move(signal));
        }

        return stream;
    }

    template <typename T>
    static stream make_number_stream(length_t const slice_length, T const *const data,
                                     time::range const data_time_range, channel_index_t const ch_idx) {
        stream stream{sync_source{1, slice_length}};

        auto &channel = stream.add_channel(ch_idx);

        auto each = make_fast_each(data_time_range.length);
        while (yas_each_next(each)) {
            auto const &idx = yas_each_index(each);
            channel.insert_event(make_frame_time(data_time_range.frame + idx), number_event::make_shared(data[idx]));
        }

        return stream;
    }

    template <typename T>
    static stream make_number_stream(length_t const slice_length, T const *const left_data,
                                     time::range const left_time_range, channel_index_t const left_ch_idx,
                                     T const *const right_data, time::range const right_time_range,
                                     channel_index_t const right_ch_idx) {
        stream stream{sync_source{1, slice_length}};

        {
            auto &channel = stream.add_channel(left_ch_idx);

            auto each = make_fast_each(left_time_range.length);
            while (yas_each_next(each)) {
                auto const &idx = yas_each_index(each);
                channel.insert_event(make_frame_time(left_time_range.frame + idx),
                                     number_event::make_shared(left_data[idx]));
            }
        }

        {
            auto &channel = stream.add_channel(right_ch_idx);

            auto each = make_fast_each(right_time_range.length);
            while (yas_each_next(each)) {
                auto const &idx = yas_each_index(each);
                channel.insert_event(make_frame_time(right_time_range.frame + idx),
                                     number_event::make_shared(right_data[idx]));
            }
        }

        return stream;
    }
}  // namespace test
}  // namespace yas
