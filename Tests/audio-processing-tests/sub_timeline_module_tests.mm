//
//  sub_timeline_module_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/each_index.h>
#import <audio-processing/module/maker/sub_timeline_module.h>

using namespace yas;
using namespace yas::proc;

@interface sub_timeline_module_tests : XCTestCase

@end

@implementation sub_timeline_module_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_module {
    XCTAssertTrue(make_module(timeline::make_shared()));
}

- (void)test_process_signal {
    auto main_timeline = timeline::make_shared();
    auto sub_timeline = timeline::make_shared();

    {
        auto plus_module = make_signal_module<int8_t>(math2::kind::plus);
        plus_module->connect_input(to_connector_index(math2::input::left), 10);
        plus_module->connect_input(to_connector_index(math2::input::right), 11);
        plus_module->connect_output(to_connector_index(math2::output::result), 12);

        auto sub_track = proc::track::make_shared();
        sub_track->push_back_module(std::move(plus_module), time::range{1, 2});
        sub_timeline->insert_track(0, sub_track);
    }

    {
        auto left_module = make_signal_module(int8_t(7));
        left_module->connect_output(to_connector_index(constant::output::value), 0);

        auto right_module = make_signal_module(int8_t(8));
        right_module->connect_output(to_connector_index(constant::output::value), 1);

        auto main_track_0 = proc::track::make_shared();
        main_track_0->push_back_module(std::move(left_module), time::range{0, 4});
        main_timeline->insert_track(0, main_track_0);

        auto main_track_1 = proc::track::make_shared();
        main_track_1->push_back_module(std::move(right_module), time::range{0, 4});
        main_timeline->insert_track(1, main_track_1);
    }

    {
        auto sub_timeline_module = make_module(std::move(sub_timeline));
        sub_timeline_module->connect_input(10, 0);
        sub_timeline_module->connect_input(11, 1);
        sub_timeline_module->connect_output(12, 20);

        auto main_track_2 = proc::track::make_shared();
        main_track_2->push_back_module(std::move(sub_timeline_module), time::range{0, 4});
        main_timeline->insert_track(2, main_track_2);
    }

    stream stream{sync_source{1, 4}};

    main_timeline->process(time::range{0, 4}, stream);

    XCTAssertEqual(stream.channel_count(), 3);
    XCTAssertTrue(stream.has_channel(0));
    XCTAssertTrue(stream.has_channel(1));
    XCTAssertTrue(stream.has_channel(20));

    {
        auto const &channel = stream.channel(0);
        XCTAssertEqual(channel.events().size(), 1);
        XCTAssertEqual(channel.events().cbegin()->first, make_range_time(0, 4));

        auto const signal = channel.events().cbegin()->second.get<signal_event>();
        auto const &vec = signal->vector<int8_t>();
        XCTAssertEqual(vec.size(), 4);
        for (auto const &value : vec) {
            XCTAssertEqual(value, 7);
        }
    }

    {
        auto const &channel = stream.channel(1);
        XCTAssertEqual(channel.events().size(), 1);
        XCTAssertEqual(channel.events().cbegin()->first, make_range_time(0, 4));

        auto const signal = channel.events().cbegin()->second.get<signal_event>();
        auto const &vec = signal->vector<int8_t>();
        XCTAssertEqual(vec.size(), 4);
        for (auto const &value : vec) {
            XCTAssertEqual(value, 8);
        }
    }

    {
        auto const &channel = stream.channel(20);
        XCTAssertEqual(channel.events().size(), 1);
        XCTAssertEqual(channel.events().cbegin()->first, make_range_time(1, 2));

        auto const signal = channel.events().cbegin()->second.get<signal_event>();
        auto const &vec = signal->vector<int8_t>();
        XCTAssertEqual(vec.size(), 2);
        for (auto const &value : vec) {
            XCTAssertEqual(value, 15);
        }
    }
}

- (void)test_process_overwrite_signal {
    auto main_timeline = timeline::make_shared();
    auto sub_timeline = timeline::make_shared();

    {
        auto main_module = make_signal_module(int8_t(1));
        main_module->connect_output(to_connector_index(constant::output::value), 0);

        auto main_track = proc::track::make_shared();
        main_track->push_back_module(std::move(main_module), time::range{0, 4});
        main_timeline->insert_track(0, main_track);
    }

    {
        auto sub_module = make_signal_module(int8_t(2));
        sub_module->connect_output(to_connector_index(constant::output::value), 0);

        auto sub_track = proc::track::make_shared();
        sub_track->push_back_module(std::move(sub_module), time::range{1, 2});
        sub_timeline->insert_track(0, sub_track);
    }

    {
        auto sub_timeline_module = make_module(std::move(sub_timeline));
        sub_timeline_module->connect_output(0, 0);

        auto main_track_2 = proc::track::make_shared();
        main_track_2->push_back_module(std::move(sub_timeline_module), time::range{1, 2});
        main_timeline->insert_track(1, main_track_2);
    }

    stream stream{sync_source{1, 4}};

    main_timeline->process(time::range{0, 4}, stream);

    XCTAssertEqual(stream.channel_count(), 1);
    XCTAssertTrue(stream.has_channel(0));

    {
        auto const &channel = stream.channel(0);
        XCTAssertEqual(channel.events().size(), 1);
        XCTAssertEqual(channel.events().cbegin()->first, make_range_time(0, 4));

        auto const signal = channel.events().cbegin()->second.get<signal_event>();
        auto const &vec = signal->vector<int8_t>();
        XCTAssertEqual(vec.size(), 4);
        XCTAssertEqual(vec[0], 1);
        XCTAssertEqual(vec[1], 2);
        XCTAssertEqual(vec[2], 2);
        XCTAssertEqual(vec[3], 1);
    }
}

- (void)test_process_signal_offset {
    auto main_timeline = timeline::make_shared();
    auto sub_timeline = timeline::make_shared();

    {
        auto plus_module = make_signal_module<int8_t>(math2::kind::plus);
        plus_module->connect_input(to_connector_index(math2::input::left), 10);
        plus_module->connect_input(to_connector_index(math2::input::right), 11);
        plus_module->connect_output(to_connector_index(math2::output::result), 12);

        auto sub_track = proc::track::make_shared();
        sub_track->push_back_module(std::move(plus_module), time::range{0, 2});
        sub_timeline->insert_track(0, sub_track);
    }

    {
        auto left_module = make_signal_module(int8_t(7));
        left_module->connect_output(to_connector_index(constant::output::value), 0);

        auto right_module = make_signal_module(int8_t(8));
        right_module->connect_output(to_connector_index(constant::output::value), 1);

        auto main_track_0 = proc::track::make_shared();
        main_track_0->push_back_module(std::move(left_module), time::range{0, 4});
        main_timeline->insert_track(0, main_track_0);

        auto main_track_1 = proc::track::make_shared();
        main_track_1->push_back_module(std::move(right_module), time::range{0, 4});
        main_timeline->insert_track(1, main_track_1);
    }

    {
        auto sub_timeline_module = make_module(std::move(sub_timeline), 1);
        sub_timeline_module->connect_input(10, 0);
        sub_timeline_module->connect_input(11, 1);
        sub_timeline_module->connect_output(12, 20);

        auto main_track_2 = proc::track::make_shared();
        main_track_2->push_back_module(std::move(sub_timeline_module), time::range{1, 2});
        main_timeline->insert_track(2, main_track_2);
    }

    stream stream{sync_source{1, 4}};

    main_timeline->process(time::range{0, 4}, stream);

    XCTAssertEqual(stream.channel_count(), 3);
    XCTAssertTrue(stream.has_channel(0));
    XCTAssertTrue(stream.has_channel(1));
    XCTAssertTrue(stream.has_channel(20));

    {
        auto const &channel = stream.channel(0);
        XCTAssertEqual(channel.events().size(), 1);
        XCTAssertEqual(channel.events().cbegin()->first, make_range_time(0, 4));

        auto const signal = channel.events().cbegin()->second.get<signal_event>();
        auto const &vec = signal->vector<int8_t>();
        XCTAssertEqual(vec.size(), 4);
        for (auto const &value : vec) {
            XCTAssertEqual(value, 7);
        }
    }

    {
        auto const &channel = stream.channel(1);
        XCTAssertEqual(channel.events().size(), 1);
        XCTAssertEqual(channel.events().cbegin()->first, make_range_time(0, 4));

        auto const signal = channel.events().cbegin()->second.get<signal_event>();
        auto const &vec = signal->vector<int8_t>();
        XCTAssertEqual(vec.size(), 4);
        for (auto const &value : vec) {
            XCTAssertEqual(value, 8);
        }
    }

    {
        auto const &channel = stream.channel(20);
        XCTAssertEqual(channel.events().size(), 1);
        XCTAssertEqual(channel.events().cbegin()->first, make_range_time(1, 2));

        auto const signal = channel.events().cbegin()->second.get<signal_event>();
        auto const &vec = signal->vector<int8_t>();
        XCTAssertEqual(vec.size(), 2);
        for (auto const &value : vec) {
            XCTAssertEqual(value, 15);
        }
    }
}

- (void)test_process_number {
    auto main_timeline = timeline::make_shared();
    auto sub_timeline = timeline::make_shared();

    {
        auto plus_module = make_number_module<int8_t>(math2::kind::plus);
        plus_module->connect_input(to_connector_index(math2::input::left), 10);
        plus_module->connect_input(to_connector_index(math2::input::right), 11);
        plus_module->connect_output(to_connector_index(math2::output::result), 12);

        auto sub_track = proc::track::make_shared();
        sub_track->push_back_module(std::move(plus_module), time::range{1, 1});
        sub_timeline->insert_track(0, sub_track);
    }

    {
        main_timeline->insert_track(0, proc::track::make_shared());
        main_timeline->insert_track(1, proc::track::make_shared());

        auto each = make_fast_each(3);
        while (yas_each_next(each)) {
            auto const &idx = yas_each_index(each);

            auto left_module = make_number_module(int8_t(7));
            left_module->connect_output(to_connector_index(constant::output::value), 0);

            auto right_module = make_number_module(int8_t(8));
            right_module->connect_output(to_connector_index(constant::output::value), 1);

            auto &main_track_0 = main_timeline->track(0);
            main_track_0->push_back_module(std::move(left_module), time::range{idx, 1});

            auto &main_track_1 = main_timeline->track(1);
            main_track_1->push_back_module(std::move(right_module), time::range{idx, 1});
        }
    }

    {
        auto sub_timeline_module = make_module(std::move(sub_timeline));
        sub_timeline_module->connect_input(10, 0);
        sub_timeline_module->connect_input(11, 1);
        sub_timeline_module->connect_output(12, 20);

        auto main_track_2 = proc::track::make_shared();
        main_track_2->push_back_module(std::move(sub_timeline_module), time::range{1, 1});
        main_timeline->insert_track(2, main_track_2);
    }

    stream stream{sync_source{1, 3}};

    main_timeline->process(time::range{0, 3}, stream);

    XCTAssertEqual(stream.channel_count(), 3);
    XCTAssertTrue(stream.has_channel(0));
    XCTAssertTrue(stream.has_channel(1));
    XCTAssertTrue(stream.has_channel(20));

    {
        auto const &left_channel = stream.channel(0);
        auto const &right_channel = stream.channel(1);
        XCTAssertEqual(left_channel.events().size(), 3);
        XCTAssertEqual(right_channel.events().size(), 3);

        auto const left_events = left_channel.filtered_events<int8_t, number_event>();
        auto const right_events = right_channel.filtered_events<int8_t, number_event>();
        auto left_iterator = left_events.cbegin();
        auto right_iterator = right_events.cbegin();

        auto each = make_fast_each(3);
        while (yas_each_next(each)) {
            XCTAssertEqual(left_iterator->first, yas_each_index(each));
            XCTAssertEqual(right_iterator->first, yas_each_index(each));
            XCTAssertEqual(left_iterator->second->get<int8_t>(), 7);
            XCTAssertEqual(right_iterator->second->get<int8_t>(), 8);

            ++left_iterator;
            ++right_iterator;
        }
    }

    {
        auto const &channel = stream.channel(20);
        XCTAssertEqual(channel.events().size(), 1);
        XCTAssertEqual(channel.events().cbegin()->first, make_frame_time(1));
        XCTAssertEqual(channel.events().cbegin()->second.get<number_event>()->get<int8_t>(), 15);
    }
}

- (void)test_process_overwrite_number {
    auto main_timeline = timeline::make_shared();
    auto sub_timeline = timeline::make_shared();

    {
        main_timeline->insert_track(0, proc::track::make_shared());

        auto each = make_fast_each(4);
        while (yas_each_next(each)) {
            auto main_module = make_number_module(int8_t(1));
            main_module->connect_output(to_connector_index(constant::output::value), 0);

            auto &main_track = main_timeline->track(0);
            main_track->push_back_module(std::move(main_module), time::range{yas_each_index(each), 1});
        }
    }

    {
        sub_timeline->insert_track(0, proc::track::make_shared());

        auto each = make_fast_each(2);
        while (yas_each_next(each)) {
            auto sub_module = make_number_module(int8_t(2));
            sub_module->connect_output(to_connector_index(constant::output::value), 0);

            auto &sub_track = sub_timeline->track(0);
            sub_track->push_back_module(std::move(sub_module), time::range{1 + yas_each_index(each), 2});
        }
    }

    {
        auto sub_timeline_module = make_module(std::move(sub_timeline));
        sub_timeline_module->connect_output(0, 0);

        auto main_track_2 = proc::track::make_shared();
        main_track_2->push_back_module(std::move(sub_timeline_module), time::range{1, 2});
        main_timeline->insert_track(1, main_track_2);
    }

    stream stream{sync_source{1, 4}};

    main_timeline->process(time::range{0, 4}, stream);

    XCTAssertEqual(stream.channel_count(), 1);
    XCTAssertTrue(stream.has_channel(0));

    {
        auto const &channel = stream.channel(0);
        XCTAssertEqual(channel.events().size(), 4);

        auto const events = channel.filtered_events<int8_t, number_event>();
        auto event_iterator = events.cbegin();

        XCTAssertEqual(event_iterator->first, 0);
        XCTAssertEqual(event_iterator->second->get<int8_t>(), 1);
        ++event_iterator;
        XCTAssertEqual(event_iterator->first, 1);
        XCTAssertEqual(event_iterator->second->get<int8_t>(), 2);
        ++event_iterator;
        XCTAssertEqual(event_iterator->first, 2);
        XCTAssertEqual(event_iterator->second->get<int8_t>(), 2);
        ++event_iterator;
        XCTAssertEqual(event_iterator->first, 3);
        XCTAssertEqual(event_iterator->second->get<int8_t>(), 1);
    }
}

- (void)test_process_number_offset {
    auto main_timeline = timeline::make_shared();
    auto sub_timeline = timeline::make_shared();

    {
        auto plus_module = make_number_module<int8_t>(math2::kind::plus);
        plus_module->connect_input(to_connector_index(math2::input::left), 10);
        plus_module->connect_input(to_connector_index(math2::input::right), 11);
        plus_module->connect_output(to_connector_index(math2::output::result), 12);

        auto sub_track = proc::track::make_shared();
        sub_track->push_back_module(std::move(plus_module), time::range{0, 2});
        sub_timeline->insert_track(0, sub_track);
    }

    {
        main_timeline->insert_track(0, proc::track::make_shared());
        main_timeline->insert_track(1, proc::track::make_shared());

        auto each = make_fast_each(4);
        while (yas_each_next(each)) {
            auto const &idx = yas_each_index(each);

            auto left_module = make_number_module(int8_t(7));
            left_module->connect_output(to_connector_index(constant::output::value), 0);

            auto right_module = make_number_module(int8_t(8));
            right_module->connect_output(to_connector_index(constant::output::value), 1);

            auto &main_track_0 = main_timeline->track(0);
            main_track_0->push_back_module(std::move(left_module), time::range{idx, 4});

            auto &main_track_1 = main_timeline->track(1);
            main_track_1->push_back_module(std::move(right_module), time::range{idx, 4});
        }
    }

    {
        auto sub_timeline_module = make_module(std::move(sub_timeline), 1);
        sub_timeline_module->connect_input(10, 0);
        sub_timeline_module->connect_input(11, 1);
        sub_timeline_module->connect_output(12, 20);

        auto main_track_2 = proc::track::make_shared();
        main_track_2->push_back_module(std::move(sub_timeline_module), time::range{1, 2});
        main_timeline->insert_track(2, main_track_2);
    }

    stream stream{sync_source{1, 4}};

    main_timeline->process(time::range{0, 4}, stream);

    XCTAssertEqual(stream.channel_count(), 3);
    XCTAssertTrue(stream.has_channel(0));
    XCTAssertTrue(stream.has_channel(1));
    XCTAssertTrue(stream.has_channel(20));

    {
        auto const &channel = stream.channel(20);
        auto const events = channel.filtered_events<int8_t, number_event>();

        XCTAssertEqual(events.size(), 2);

        auto event_iterator = events.cbegin();

        XCTAssertEqual(event_iterator->first, 1);
        XCTAssertEqual(event_iterator->second->get<int8_t>(), 15);

        ++event_iterator;

        XCTAssertEqual(event_iterator->first, 2);
        XCTAssertEqual(event_iterator->second->get<int8_t>(), 15);
    }
}

- (void)test_copy {
    auto module = make_number_module<double>(math1::kind::abs);
    module->connect_input(to_connector_index(math1::input::parameter), 1);
    module->connect_output(to_connector_index(math1::output::result), 2);

    auto copied = module->copy();

    XCTAssertEqual(copied->processors().size(), 3);
    XCTAssertEqual(copied->input_connectors().size(), 1);
    XCTAssertEqual(copied->input_connectors().at(to_connector_index(math1::input::parameter)).channel_index, 1);
    XCTAssertEqual(copied->output_connectors().size(), 1);
    XCTAssertEqual(copied->output_connectors().at(to_connector_index(math1::output::result)).channel_index, 2);
}

@end
