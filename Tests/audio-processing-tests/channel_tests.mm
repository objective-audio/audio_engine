//
//  channel_tests.mm
//

#import <XCTest/XCTest.h>
#include <audio-processing/channel/channel.h>

using namespace yas;
using namespace yas::proc;

@interface channel_tests : XCTestCase

@end

@implementation channel_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_channel {
    proc::channel channel;

    XCTAssertEqual(channel.events().size(), 0);
}

- (void)test_create_channel_from_events {
    proc::channel::events_map_t events;
    events.emplace(std::make_pair(make_frame_time(10), number_event::make_shared(int8_t(100))));

    proc::channel channel{std::move(events)};

    XCTAssertEqual(channel.events().size(), 1);

    auto const pair = *channel.events().cbegin();

    XCTAssertEqual(pair.first, make_frame_time(10));
    XCTAssertTrue(pair.second.is_equal(number_event::make_shared(int8_t(100))));
}

- (void)test_insert_event {
    proc::channel channel;

    auto uint_signal = signal_event::make_shared<uint32_t>(4);
    auto &uint_vec = uint_signal->vector<uint32_t>();
    uint_vec[0] = 10;
    uint_vec[1] = 11;
    uint_vec[2] = 12;
    uint_vec[3] = 13;

    auto float_signal = signal_event::make_shared<float>(2);
    auto &float_vec = float_signal->vector<float>();
    float_vec[0] = 2.0f;
    float_vec[1] = 4.0f;

    proc::time uint_range_time{16, 4};
    proc::time float_range_time{8, 2};

    channel.insert_event(std::move(uint_range_time), signal_event::make_shared(std::move(uint_vec)));
    channel.insert_event(std::move(float_range_time), signal_event::make_shared(std::move(float_vec)));

    std::size_t idx = 0;
    for (auto &pair : channel.events()) {
        auto const &time = pair.first;
        auto const &event = pair.second;
        if (idx == 0) {
            XCTAssertTrue((time == proc::time{8, 2}));
            auto const signal = event.get<signal_event>();
            XCTAssertTrue(signal->sample_type() == typeid(float));
            auto const &vec = signal->vector<float>();
            XCTAssertEqual(vec.size(), 2);
            XCTAssertEqual(vec[0], 2.0f);
            XCTAssertEqual(vec[1], 4.0f);
        } else if (idx == 1) {
            XCTAssertTrue((time == proc::time{16, 4}));
            auto const signal = event.get<signal_event>();
            XCTAssertTrue(signal->sample_type() == typeid(uint32_t));
            auto const &vec = signal->vector<uint32_t>();
            XCTAssertEqual(vec.size(), 4);
            XCTAssertEqual(vec[0], 10);
            XCTAssertEqual(vec[1], 11);
            XCTAssertEqual(vec[2], 12);
            XCTAssertEqual(vec[3], 13);
        }

        ++idx;
    }
}

- (void)test_insert_events {
    proc::channel src_channel;
    proc::channel dst_channel;

    src_channel.insert_event(make_frame_time(0), number_event::make_shared(int8_t(10)));
    src_channel.insert_event(make_frame_time(1), number_event::make_shared(int8_t(11)));

    dst_channel.insert_events(std::move(src_channel.events()));

    auto iterator = dst_channel.events().cbegin();

    XCTAssertEqual(iterator->first.get<time::frame>(), 0);
    XCTAssertEqual(iterator->second.get<number_event>()->get<int8_t>(), 10);

    ++iterator;

    XCTAssertEqual(iterator->first.get<time::frame>(), 1);
    XCTAssertEqual(iterator->second.get<number_event>()->get<int8_t>(), 11);
}

- (void)test_insert_same_time_range_signal_event {
    proc::channel channel;

    auto uint_signal = signal_event::make_shared<uint32_t>(2);
    proc::time uint_range_time{1, 2};

    auto float_signal = signal_event::make_shared<float>(2);
    proc::time float_range_time{1, 2};

    channel.insert_event(uint_range_time, uint_signal);
    channel.insert_event(float_range_time, float_signal);

    XCTAssertEqual(channel.events().size(), 2);
}

- (void)test_const_signal_event {
    proc::channel channel;

    auto signal = signal_event::make_shared<float>(1);
    signal->vector<float>()[0] = 1.0f;

    channel.insert_event(proc::time{10, 1}, std::move(signal));

    proc::channel const &const_channel = channel;

    XCTAssertEqual(const_channel.events().size(), 1);

    for (auto const &pair : const_channel.events()) {
        auto const &const_time = pair.first;
        auto const &const_signal = pair.second.get<signal_event>();

        XCTAssertTrue((const_time == proc::time{10, 1}));
        XCTAssertEqual(const_signal->vector<float>()[0], 1.0f);
    }
}

- (void)test_invalid_insert_event {
    proc::channel channel;

    auto signal_event = signal_event::make_shared<float>(2);

    XCTAssertThrows(channel.insert_event(proc::time{0, 1}, std::move(signal_event)));
}

- (void)test_typed_erase_event {
    proc::channel channel;

    auto float_signal_0 = signal_event::make_shared<float>(1);
    float_signal_0->data<float>()[0] = 0.0;
    channel.insert_event(make_range_time(0, 1), float_signal_0);

    auto float_signal_1 = signal_event::make_shared<float>(1);
    float_signal_1->data<float>()[0] = 1.0;
    channel.insert_event(make_range_time(0, 1), float_signal_1);

    auto float_signal_2 = signal_event::make_shared<float>(1);
    float_signal_2->data<float>()[0] = 2.0;
    channel.insert_event(make_range_time(1, 1), float_signal_2);

    channel.insert_event(make_range_time(0, 1), signal_event::make_shared<double>(1));
    channel.insert_event(make_frame_time(0), number_event::make_shared<int8_t>(1));

    channel.erase_event<float, signal_event>([](auto const &pair) {
        time::range const &time_range = pair.first;
        signal_event_ptr const &signal = pair.second;
        if (time_range.frame != 0 || signal->data<float>()[0] > 0.0f) {
            return true;
        }
        return false;
    });

    XCTAssertEqual(channel.events().size(), 3);

    auto const float_signal_events = channel.filtered_events<float, signal_event>();
    XCTAssertEqual(float_signal_events.size(), 1);
    signal_event_ptr const &float_event = float_signal_events.cbegin()->second;
    XCTAssertEqual(float_event->data<float>()[0], 0.0f);

    auto const double_signal_events = channel.filtered_events<double, signal_event>();
    XCTAssertEqual(double_signal_events.size(), 1);

    auto const int8_number_events = channel.filtered_events<int8_t, number_event>();
    XCTAssertEqual(int8_number_events.size(), 1);
}

- (void)test_copied_events_number {
    proc::channel channel;

    channel.insert_event(make_frame_time(0), number_event::make_shared(int8_t(0)));
    channel.insert_event(make_frame_time(1), number_event::make_shared(int8_t(1)));
    channel.insert_event(make_frame_time(2), number_event::make_shared(int8_t(2)));

    auto const copied_events = channel.copied_events(time::range{2, 3}, 0);

    XCTAssertEqual(copied_events.size(), 1);

    auto const &pair = *copied_events.cbegin();

    XCTAssertEqual(pair.first, make_frame_time(2));
    XCTAssertTrue(pair.second.is_equal(number_event::make_shared(int8_t(2))));
}

- (void)test_copied_events_number_offset {
    proc::channel channel;

    channel.insert_event(make_frame_time(0), number_event::make_shared(int8_t(0)));
    channel.insert_event(make_frame_time(1), number_event::make_shared(int8_t(1)));
    channel.insert_event(make_frame_time(2), number_event::make_shared(int8_t(2)));

    auto const copied_events = channel.copied_events(time::range{2, 3}, 10);

    XCTAssertEqual(copied_events.size(), 1);

    auto const &pair = *copied_events.cbegin();

    XCTAssertEqual(pair.first, make_frame_time(12));
    XCTAssertTrue(pair.second.is_equal(number_event::make_shared(int8_t(2))));
}

- (void)test_copied_events_signal {
    proc::channel channel;

    auto src_signal_event1 = signal_event::make_shared<int8_t>(3);
    auto &src_vec1 = src_signal_event1->vector<int8_t>();
    src_vec1[0] = 10;
    src_vec1[1] = 11;
    src_vec1[2] = 12;

    channel.insert_event(make_range_time(0, 3), std::move(src_signal_event1));

    auto src_signal_event2 = signal_event::make_shared<int8_t>(3);
    auto &src_vec2 = src_signal_event2->vector<int8_t>();
    src_vec2[0] = 20;
    src_vec2[1] = 21;
    src_vec2[2] = 22;

    channel.insert_event(make_range_time(4, 3), std::move(src_signal_event2));

    auto const copied_events = channel.copied_events(time::range{2, 4}, 0);

    XCTAssertEqual(copied_events.size(), 2);

    auto iterator = copied_events.cbegin();

    auto const &first_pair = *iterator;
    auto const first_signal = first_pair.second.get<signal_event>();
    auto const &first_vec = first_signal->vector<int8_t>();

    XCTAssertEqual(first_pair.first, make_range_time(2, 1));
    XCTAssertEqual(first_vec.size(), 1);
    XCTAssertEqual(first_vec[0], 12);

    ++iterator;

    auto const &second_pair = *iterator;
    auto const second_signal = second_pair.second.get<signal_event>();
    auto const &second_vec = second_signal->vector<int8_t>();

    XCTAssertEqual(second_pair.first, make_range_time(4, 2));
    XCTAssertEqual(second_vec.size(), 2);
    XCTAssertEqual(second_vec[0], 20);
    XCTAssertEqual(second_vec[1], 21);
}

- (void)test_copied_events_signal_offset {
    proc::channel channel;

    auto src_signal_event1 = signal_event::make_shared<int8_t>(3);
    auto &src_vec1 = src_signal_event1->vector<int8_t>();
    src_vec1[0] = 10;
    src_vec1[1] = 11;
    src_vec1[2] = 12;

    channel.insert_event(make_range_time(0, 3), std::move(src_signal_event1));

    auto src_signal_event2 = signal_event::make_shared<int8_t>(3);
    auto &src_vec2 = src_signal_event2->vector<int8_t>();
    src_vec2[0] = 20;
    src_vec2[1] = 21;
    src_vec2[2] = 22;

    channel.insert_event(make_range_time(4, 3), std::move(src_signal_event2));

    auto const copied_events = channel.copied_events(time::range{2, 4}, -10);

    XCTAssertEqual(copied_events.size(), 2);

    auto iterator = copied_events.cbegin();

    auto const &first_pair = *iterator;
    auto const first_signal = first_pair.second.get<signal_event>();
    auto const &first_vec = first_signal->vector<int8_t>();

    XCTAssertEqual(first_pair.first, make_range_time(-8, 1));
    XCTAssertEqual(first_vec.size(), 1);
    XCTAssertEqual(first_vec[0], 12);

    ++iterator;

    auto const &second_pair = *iterator;
    auto const second_signal = second_pair.second.get<signal_event>();
    auto const &second_vec = second_signal->vector<int8_t>();

    XCTAssertEqual(second_pair.first, make_range_time(-6, 2));
    XCTAssertEqual(second_vec.size(), 2);
    XCTAssertEqual(second_vec[0], 20);
    XCTAssertEqual(second_vec[1], 21);
}

- (void)test_erase_events_with_time_range {
    proc::channel channel;

    channel.insert_event(make_frame_time(0), number_event::make_shared(int16_t(1000)));
    channel.insert_event(make_frame_time(2), number_event::make_shared(int16_t(1002)));
    channel.insert_event(make_frame_time(4), number_event::make_shared(int16_t(1004)));
    channel.insert_event(make_frame_time(6), number_event::make_shared(int16_t(1006)));
    channel.insert_event(make_frame_time(8), number_event::make_shared(int16_t(1008)));

    auto src_signal_event1 = signal_event::make_shared<int16_t>(3);
    auto &src_vec1 = src_signal_event1->vector<int16_t>();
    src_vec1[0] = 100;
    src_vec1[1] = 101;
    src_vec1[2] = 102;

    channel.insert_event(make_range_time(1, 3), std::move(src_signal_event1));

    auto src_signal_event2 = signal_event::make_shared<int16_t>(3);
    auto &src_vec2 = src_signal_event2->vector<int16_t>();
    src_vec2[0] = 200;
    src_vec2[1] = 201;
    src_vec2[2] = 202;

    channel.insert_event(make_range_time(5, 3), std::move(src_signal_event2));

    channel.erase_events(time::range{3, 3});

    XCTAssertEqual(channel.events().size(), 6);

    auto const number_events = channel.filtered_events<int16_t, number_event>();

    XCTAssertEqual(number_events.size(), 4);

    auto number_iterator = number_events.cbegin();
    XCTAssertEqual(number_iterator->first, 0);
    XCTAssertEqual(number_iterator->second->get<int16_t>(), 1000);
    ++number_iterator;
    XCTAssertEqual(number_iterator->first, 2);
    XCTAssertEqual(number_iterator->second->get<int16_t>(), 1002);
    ++number_iterator;
    XCTAssertEqual(number_iterator->first, 6);
    XCTAssertEqual(number_iterator->second->get<int16_t>(), 1006);
    ++number_iterator;
    XCTAssertEqual(number_iterator->first, 8);
    XCTAssertEqual(number_iterator->second->get<int16_t>(), 1008);

    auto const signal_events = channel.filtered_events<int16_t, signal_event>();

    XCTAssertEqual(signal_events.size(), 2);

    auto signal_iterator = signal_events.cbegin();
    XCTAssertEqual(signal_iterator->first, time::range(1, 2));
    ++signal_iterator;
    XCTAssertEqual(signal_iterator->first, time::range(6, 2));
}

- (void)test_combine_signal_event {
    proc::channel channel;

    auto signal_1 = signal_event::make_shared<int8_t>(2);
    auto &vec1 = signal_1->vector<int8_t>();
    vec1[0] = 5;
    vec1[1] = 6;

    channel.insert_event(make_range_time(0, 2), std::move(signal_1));

    auto signal_2 = signal_event::make_shared<int8_t>(2);
    auto &vec2 = signal_2->vector<int8_t>();
    vec2[0] = 9;
    vec2[1] = 10;

    channel.insert_event(make_range_time(4, 2), std::move(signal_2));

    auto signal_3 = signal_event::make_shared<int8_t>(2);
    auto &vec3 = signal_3->vector<int8_t>();
    vec3[0] = 13;
    vec3[1] = 14;

    channel.insert_event(make_range_time(8, 2), std::move(signal_3));

    auto insert_signal = signal_event::make_shared<int8_t>(2);
    auto &insert_vec = insert_signal->vector<int8_t>();
    insert_vec[0] = 7;
    insert_vec[1] = 8;

    auto combined_pair = channel.combine_signal_event(time::range{2, 2}, std::move(insert_signal));

    {
        XCTAssertEqual(combined_pair.first, time::range(0, 6));

        auto const &combined_signal = combined_pair.second;
        auto const &combined_vec = combined_signal->vector<int8_t>();

        XCTAssertEqual(combined_vec.size(), 6);
        XCTAssertEqual(combined_vec[0], 5);
        XCTAssertEqual(combined_vec[1], 6);
        XCTAssertEqual(combined_vec[2], 7);
        XCTAssertEqual(combined_vec[3], 8);
        XCTAssertEqual(combined_vec[4], 9);
        XCTAssertEqual(combined_vec[5], 10);
    }

    XCTAssertEqual(channel.events().size(), 2);

    auto iterator = channel.events().cbegin();

    {
        XCTAssertEqual(iterator->first, make_range_time(0, 6));

        auto const &combined_signal = iterator->second.get<signal_event>();
        auto const &combined_vec = combined_signal->vector<int8_t>();

        XCTAssertEqual(combined_vec.size(), 6);
        XCTAssertEqual(combined_vec[0], 5);
        XCTAssertEqual(combined_vec[1], 6);
        XCTAssertEqual(combined_vec[2], 7);
        XCTAssertEqual(combined_vec[3], 8);
        XCTAssertEqual(combined_vec[4], 9);
        XCTAssertEqual(combined_vec[5], 10);
    }

    ++iterator;

    {
        XCTAssertEqual(iterator->first, make_range_time(8, 2));

        auto const &remained_signal = iterator->second.get<signal_event>();
        auto const &remained_vec = remained_signal->vector<int8_t>();

        XCTAssertEqual(remained_vec.size(), 2);
        XCTAssertEqual(remained_vec[0], 13);
        XCTAssertEqual(remained_vec[1], 14);
    }
}

- (void)test_filtered_events_by_event {
    proc::channel channel;

    channel.insert_event(make_frame_time(0), number_event::make_shared(int16_t(100)));
    channel.insert_event(make_frame_time(1), number_event::make_shared(int32_t(101)));
    channel.insert_event(make_range_time(0, 1), signal_event::make_shared<int16_t>(1));
    channel.insert_event(make_range_time(1, 1), signal_event::make_shared<int8_t>(1));

    auto number_events = channel.filtered_events<number_event>();

    XCTAssertEqual(number_events.size(), 2);

    auto number_iterator = number_events.begin();
    XCTAssertEqual((*number_iterator).first, 0);
    XCTAssertTrue((*number_iterator).second->sample_type() == typeid(int16_t));
    ++number_iterator;
    XCTAssertEqual((*number_iterator).first, 1);
    XCTAssertTrue((*number_iterator).second->sample_type() == typeid(int32_t));

    auto signal_events = channel.filtered_events<signal_event>();

    XCTAssertEqual(signal_events.size(), 2);

    auto signal_iterator = signal_events.begin();
    XCTAssertEqual((*signal_iterator).first, time::range(0, 1));
    XCTAssertTrue((*signal_iterator).second->sample_type() == typeid(int16_t));
    ++signal_iterator;
    XCTAssertEqual((*signal_iterator).first, time::range(1, 1));
    XCTAssertTrue((*signal_iterator).second->sample_type() == typeid(int8_t));
}

@end
