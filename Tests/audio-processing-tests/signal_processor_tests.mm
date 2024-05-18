//
//  signal_processor_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/each_index.h>
#import <audio-processing/processor/maker/receive_signal_processor.h>
#import <audio-processing/processor/maker/send_signal_processor.h>

using namespace yas;
using namespace yas::proc;

@interface signal_processor_tests : XCTestCase

@end

@implementation signal_processor_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_send_signal_processor {
    auto const ch_idx = 5;
    connector_index_t const out_co_idx = 2;

    proc::time called_time = nullptr;
    connector_index_t called_co_idx;
    channel_index_t called_ch_idx;
    sample_rate_t called_sample_rate = 0;
    length_t called_slice_length = 0;

    auto clear = [&called_time, &called_co_idx, &called_ch_idx, &called_sample_rate, &called_slice_length]() {
        called_time = make_any_time();
        called_time = make_any_time();
        called_co_idx = 0;
        called_ch_idx = 0;
        called_sample_rate = 0;
        called_slice_length = 0;
    };

    auto handler = [&called_time, &called_co_idx, &called_ch_idx, &called_sample_rate, &called_slice_length](
                       proc::time::range const &time_range, sync_source const &sync_src, channel_index_t const ch_idx,
                       connector_index_t const co_idx, int64_t *const signal_ptr) {
        called_time = proc::time{time_range};
        called_co_idx = co_idx;
        called_ch_idx = ch_idx;
        called_sample_rate = sync_src.sample_rate;
        called_slice_length = sync_src.slice_length;
        for (auto const &idx : make_each_index(time_range.length)) {
            signal_ptr[idx] = idx + time_range.frame;
        }
    };

    auto module = module::make_shared([handler = std::move(handler)] {
        return module::processors_t{proc::make_send_signal_processor<int64_t>(std::move(handler))};
    });
    module->connect_output(out_co_idx, ch_idx);

    {
        clear();

        proc::stream stream{sync_source{1, 2}};

        module->process({0, 2}, stream);

        XCTAssertEqual(called_time.get<time::range>().frame, 0);
        XCTAssertEqual(called_time.get<time::range>().length, 2);
        XCTAssertEqual(called_co_idx, out_co_idx);
        XCTAssertEqual(called_ch_idx, ch_idx);
        XCTAssertEqual(called_sample_rate, 1);
        XCTAssertEqual(called_slice_length, 2);

        XCTAssertTrue(stream.has_channel(ch_idx));
        auto const &vec = stream.channel(ch_idx).events().cbegin()->second.get<signal_event>()->vector<int64_t>();
        XCTAssertEqual(vec.size(), 2);
        XCTAssertEqual(vec.at(0), 0);
        XCTAssertEqual(vec.at(1), 1);
    }

    {
        clear();

        proc::stream stream{sync_source{2, 1}};

        module->process({1, 1}, stream);

        XCTAssertEqual(called_time.get<time::range>().frame, 1);
        XCTAssertEqual(called_time.get<time::range>().length, 1);
        XCTAssertEqual(called_co_idx, out_co_idx);
        XCTAssertEqual(called_ch_idx, ch_idx);
        XCTAssertEqual(called_sample_rate, 2);
        XCTAssertEqual(called_slice_length, 1);

        XCTAssertTrue(stream.has_channel(ch_idx));
        auto const &vec = stream.channel(ch_idx).events().cbegin()->second.get<signal_event>()->vector<int64_t>();
        XCTAssertEqual(vec.size(), 1);
        XCTAssertEqual(vec.at(0), 1);
    }

    {
        clear();

        proc::stream stream{sync_source{8, 1}};

        module->process({0, 1}, stream);

        XCTAssertEqual(called_time.get<time::range>().frame, 0);
        XCTAssertEqual(called_time.get<time::range>().length, 1);
        XCTAssertEqual(called_co_idx, out_co_idx);
        XCTAssertEqual(called_ch_idx, ch_idx);
        XCTAssertEqual(called_sample_rate, 8);
        XCTAssertEqual(called_slice_length, 1);

        XCTAssertTrue(stream.has_channel(ch_idx));
        auto const &vec = stream.channel(ch_idx).events().cbegin()->second.get<signal_event>()->vector<int64_t>();
        XCTAssertEqual(vec.size(), 1);
        XCTAssertEqual(vec.at(0), 0);
    }
}

- (void)test_receive_signal_processor {
    auto const ch_idx = 7;
    connector_index_t const in_co_idx = 10;

    proc::time called_time = nullptr;
    connector_index_t called_co_idx;
    channel_index_t called_ch_idx;
    sample_rate_t called_sample_rate;
    length_t called_slice_length;
    int64_t called_signal[2];

    auto stream_signal = proc::signal_event::make_shared<int64_t>(2);
    auto &stream_vec = stream_signal->vector<int64_t>();
    stream_vec[0] = 10;
    stream_vec[1] = 11;

    auto clear = [&called_time, &called_co_idx, &called_ch_idx, &called_sample_rate, &called_slice_length,
                  &called_signal]() {
        called_time = make_any_time();
        called_co_idx = 0;
        called_ch_idx = 0;
        called_sample_rate = 0;
        called_slice_length = 0;
        called_signal[0] = 0.0;
        called_signal[1] = 0.0;
    };

    auto make_stream = [&stream_signal, &ch_idx](time::range const &time_range, sync_source sync_src) {
        proc::stream stream{std::move(sync_src)};
        stream.add_channel(ch_idx);

        auto &channel = stream.channel(ch_idx);
        channel.insert_event(proc::time{time_range}, stream_signal);

        return stream;
    };

    auto handler = [&called_time, &called_co_idx, &called_ch_idx, &called_sample_rate, &called_slice_length,
                    &called_signal](proc::time::range const &time_range, sync_source const &sync_src,
                                    channel_index_t const ch_idx, connector_index_t const co_idx,
                                    int64_t const *const signal_ptr) {
        called_time = proc::time{time_range};
        called_co_idx = co_idx;
        called_ch_idx = ch_idx;
        called_sample_rate = sync_src.sample_rate;
        called_slice_length = sync_src.slice_length;
        for (auto const &idx : make_each_index(time_range.length)) {
            called_signal[idx] = signal_ptr[idx];
        }
    };

    auto processor = make_receive_signal_processor<int64_t>(std::move(handler));

    auto module =
        module::make_shared([processor = std::move(processor)] { return module::processors_t{std::move(processor)}; });
    module->connect_input(in_co_idx, ch_idx);

    {
        clear();

        auto stream = make_stream({0, 2}, {1, 2});

        XCTAssertNoThrow(module->process({0, 2}, stream));

        XCTAssertEqual(called_time.get<time::range>().frame, 0);
        XCTAssertEqual(called_time.get<time::range>().length, 2);
        XCTAssertEqual(called_co_idx, in_co_idx);
        XCTAssertEqual(called_ch_idx, ch_idx);
        XCTAssertEqual(called_sample_rate, 1);
        XCTAssertEqual(called_slice_length, 2);

        XCTAssertEqual(called_signal[0], 10);
        XCTAssertEqual(called_signal[1], 11);
    }

    {
        clear();

        auto stream = make_stream({0, 2}, {4, 1});

        XCTAssertNoThrow(module->process({0, 1}, stream));

        XCTAssertEqual(called_time.get<time::range>().frame, 0);
        XCTAssertEqual(called_time.get<time::range>().length, 1);
        XCTAssertEqual(called_co_idx, in_co_idx);
        XCTAssertEqual(called_ch_idx, ch_idx);
        XCTAssertEqual(called_sample_rate, 4);
        XCTAssertEqual(called_slice_length, 1);

        XCTAssertEqual(called_signal[0], 10);
        XCTAssertEqual(called_signal[1], 0);
    }

    {
        clear();

        auto stream = make_stream({0, 2}, {16, 1});

        XCTAssertNoThrow(module->process({1, 1}, stream));

        XCTAssertEqual(called_time.get<time::range>().frame, 1);
        XCTAssertEqual(called_time.get<time::range>().length, 1);
        XCTAssertEqual(called_co_idx, in_co_idx);
        XCTAssertEqual(called_ch_idx, ch_idx);
        XCTAssertEqual(called_sample_rate, 16);
        XCTAssertEqual(called_slice_length, 1);

        XCTAssertEqual(called_signal[0], 11);
        XCTAssertEqual(called_signal[1], 0);
    }
}

- (void)test_receive_and_send_signal_processor {
    auto const receive_ch_idx = 3;
    auto const send_ch_idx = 9;
    connector_index_t const out_co_idx = 5;
    connector_index_t const in_co_idx = 6;

    proc::time process_time{0, 2};

    proc::stream stream{sync_source{1, 2}};
    stream.add_channel(receive_ch_idx);

    auto input_stream_signal = proc::signal_event::make_shared<int16_t>(2);
    auto &input_stream_vec = input_stream_signal->vector<int16_t>();
    input_stream_vec[0] = 1;
    input_stream_vec[1] = 2;

    auto &channel = stream.channel(receive_ch_idx);
    channel.insert_event(process_time, input_stream_signal);

    auto process_signal = proc::signal_event::make_shared<int16_t>(2);

    auto receive_handler = [&process_signal](proc::time::range const &time_range, sync_source const &,
                                             channel_index_t const ch_idx, connector_index_t const,
                                             int16_t const *const signal_ptr) {
        auto &process_vec = process_signal->vector<int16_t>();
        for (auto const &idx : make_each_index(time_range.length)) {
            process_vec[idx] = signal_ptr[idx] * 2;
        }
    };

    auto send_handler = [&process_signal](proc::time::range const &time_range, sync_source const &,
                                          channel_index_t const ch_idx, connector_index_t const,
                                          int16_t *const signal_ptr) {
        auto &process_vec = process_signal->vector<int16_t>();
        for (auto const &idx : make_each_index(time_range.length)) {
            signal_ptr[idx] = process_vec[idx];
        }
    };

    auto module =
        module::make_shared([receive_handler = std::move(receive_handler), send_handler = std::move(send_handler)] {
            auto receive_processor = make_receive_signal_processor<int16_t>(std::move(receive_handler));
            auto send_processor = proc::make_send_signal_processor<int16_t>(std::move(send_handler));
            return module::processors_t{{std::move(receive_processor), std::move(send_processor)}};
        });
    module->connect_input(in_co_idx, receive_ch_idx);
    module->connect_output(out_co_idx, send_ch_idx);

    module->process(process_time.get<time::range>(), stream);

    XCTAssertTrue(stream.has_channel(send_ch_idx));

    auto const &send_channel = stream.channel(send_ch_idx);
    auto const &send_vec = send_channel.events().cbegin()->second.get<signal_event>()->vector<int16_t>();

    XCTAssertEqual(send_vec.size(), 2);
    XCTAssertEqual(send_vec[0], 2);
    XCTAssertEqual(send_vec[1], 4);

    XCTAssertTrue(stream.has_channel(receive_ch_idx));

    auto const &receive_channel = stream.channel(receive_ch_idx);
    auto const &receive_vec = receive_channel.events().cbegin()->second.get<signal_event>()->vector<int16_t>();

    XCTAssertEqual(receive_vec.size(), 2);
    XCTAssertEqual(receive_vec[0], 1);
    XCTAssertEqual(receive_vec[1], 2);
}

@end
