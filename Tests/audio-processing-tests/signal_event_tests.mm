//
//  signal_event_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/event/signal_event.h>
#import <cpp-utils/boolean.h>
#import <cpp-utils/each_index.h>
#import <string>

using namespace yas;
using namespace yas::proc;

@interface signal_event_tests : XCTestCase

@end

@implementation signal_event_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_signal_event {
    auto signal_event = proc::signal_event::make_shared<float>(16);

    XCTAssertEqual(signal_event->sample_byte_count(), 4);
    XCTAssertEqual(signal_event->size(), 16);
    XCTAssertEqual(signal_event->byte_size(), 64);

    XCTAssertEqual(signal_event->vector<float>().size(), 16);

    for (auto const &idx : make_each_index(16)) {
        signal_event->vector<float>()[idx] = static_cast<float>(idx);
    }

    for (auto const &idx : make_each_index(16)) {
        XCTAssertEqual(signal_event->vector<float>()[idx], static_cast<float>(idx));
    }
}

- (void)test_make_signal_event_with_reserve {
    auto signal_event = proc::signal_event::make_shared<float>(8, 16);

    XCTAssertEqual(signal_event->vector<float>().size(), 8);
    XCTAssertEqual(signal_event->vector<float>().capacity(), 16);
}

- (void)test_create_signal_event_with_moved_vector {
    auto signal_event = proc::signal_event::make_shared(std::vector<double>{0.0, 2.0, 4.0, 8.0});

    XCTAssertEqual(signal_event->sample_byte_count(), 8);
    XCTAssertEqual(signal_event->size(), 4);
    XCTAssertEqual(signal_event->byte_size(), 32);

    XCTAssertEqual(signal_event->vector<double>().size(), 4);

    XCTAssertEqual(signal_event->vector<double>()[0], 0.0);
    XCTAssertEqual(signal_event->vector<double>()[1], 2.0);
    XCTAssertEqual(signal_event->vector<double>()[2], 4.0);
    XCTAssertEqual(signal_event->vector<double>()[3], 8.0);
}

- (void)test_create_signal_event_with_reference_vector {
    std::vector<int32_t> vec(3);

    auto signal_event = proc::signal_event::make_shared(vec);

    vec[0] = 5;
    vec[1] = 6;
    vec[2] = 7;

    XCTAssertEqual(signal_event->sample_byte_count(), 4);
    XCTAssertEqual(signal_event->size(), 3);
    XCTAssertEqual(signal_event->byte_size(), 12);

    XCTAssertEqual(signal_event->vector<int32_t>().size(), 3);
    XCTAssertTrue(vec.data() == signal_event->vector<int32_t>().data());

    XCTAssertEqual(signal_event->vector<int32_t>()[0], 5);
    XCTAssertEqual(signal_event->vector<int32_t>()[1], 6);
    XCTAssertEqual(signal_event->vector<int32_t>()[2], 7);
}

- (void)test_create_signal_event_with_struct {
    struct element {
        std::string key;
        uint32_t value;
    };

    auto signal_event = signal_event::make_shared<element>(2);
    signal_event->vector<element>()[0].key = "zero";
    signal_event->vector<element>()[0].value = 100;
    signal_event->vector<element>()[1].key = "one";
    signal_event->vector<element>()[1].value = 200;

    XCTAssertEqual(signal_event->sample_byte_count(), sizeof(element));
    XCTAssertEqual(signal_event->size(), 2);
    XCTAssertEqual(signal_event->byte_size(), (2 * sizeof(element)));

    XCTAssertEqual(signal_event->vector<element>().size(), 2);

    XCTAssertEqual(signal_event->vector<element>()[0].key, "zero");
    XCTAssertEqual(signal_event->vector<element>()[0].value, 100);
    XCTAssertEqual(signal_event->vector<element>()[1].key, "one");
    XCTAssertEqual(signal_event->vector<element>()[1].value, 200);
}

- (void)test_get_data {
    auto signal_event = signal_event::make_shared<int16_t>(2);

    auto *data = signal_event->data<int16_t>();
    data[0] = 1000;
    data[1] = 1001;

    auto const *const_data = signal_event->data<int16_t>();
    XCTAssertEqual(const_data[0], 1000);
    XCTAssertEqual(const_data[1], 1001);
}

- (void)test_get_vector {
    auto signal_event = signal_event::make_shared<int16_t>(2);

    auto &vec = signal_event->vector<int16_t>();
    vec[0] = 200;
    vec[1] = 210;

    auto const &const_vec = signal_event->vector<int16_t>();
    XCTAssertEqual(const_vec[0], 200);
    XCTAssertEqual(const_vec[1], 210);
}

- (void)test_resize {
    auto signal_event = signal_event::make_shared<int16_t>(2);

    XCTAssertEqual(signal_event->size(), 2);

    signal_event->resize(16);

    XCTAssertEqual(signal_event->size(), 16);

    signal_event->resize(0);

    XCTAssertEqual(signal_event->size(), 0);
}

- (void)test_sample_byte_count {
    XCTAssertEqual(proc::signal_event::make_shared<int8_t>(1)->sample_byte_count(), 1);
    XCTAssertEqual(proc::signal_event::make_shared<double>(1)->sample_byte_count(), 8);
    XCTAssertEqual(proc::signal_event::make_shared<boolean>(1)->sample_byte_count(), 1);
}

- (void)test_sample_type {
    XCTAssertTrue(proc::signal_event::make_shared<int8_t>(1)->sample_type() == typeid(int8_t));
    XCTAssertTrue(proc::signal_event::make_shared<double>(0.0)->sample_type() == typeid(double));
    XCTAssertTrue(proc::signal_event::make_shared<boolean>(1)->sample_type() == typeid(boolean));
}

- (void)test_copy_from {
    auto signal_event = signal_event::make_shared<int16_t>(0);

    std::vector<int16_t> vec{100, 101};

    signal_event->copy_from(vec.data(), vec.size());

    XCTAssertEqual(signal_event->data<int16_t>()[0], 100);
    XCTAssertEqual(signal_event->data<int16_t>()[1], 101);
}

- (void)test_copy_to {
    auto signal_event = signal_event::make_shared<int16_t>(2);
    signal_event->data<int16_t>()[0] = 1000;
    signal_event->data<int16_t>()[1] = 1001;

    std::vector<int16_t> vec(2);

    signal_event->copy_to(vec.data(), vec.size());

    XCTAssertEqual(vec[0], 1000);
    XCTAssertEqual(vec[1], 1001);
}

- (void)test_boolean_signal_event {
    auto signal_event = signal_event::make_shared<boolean>(2);

    auto &vec = signal_event->vector<boolean>();
    vec[0] = true;
    vec[1] = false;

    auto const *data = signal_event->data<boolean>();

    XCTAssertTrue(data[0]);
    XCTAssertFalse(data[1]);
}

- (void)test_copy {
    auto src_signal_event = signal_event::make_shared<int8_t>(2);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 7;
    src_vec[1] = 8;

    auto const copied_signal_event = src_signal_event->copy();
    auto const &copied_vec = copied_signal_event->vector<int8_t>();

    XCTAssertEqual(copied_vec[0], 7);
    XCTAssertEqual(copied_vec[1], 8);
}

- (void)test_copy_and_src_change {
    auto src_signal_event = signal_event::make_shared<int8_t>(2);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 16;
    src_vec[1] = 32;

    auto const copied_signal_event = src_signal_event->copy();
    auto const &copied_vec = copied_signal_event->vector<int8_t>();

    src_vec[0] = 64;
    src_vec[1] = 96;

    XCTAssertEqual(copied_vec[0], 16);
    XCTAssertEqual(copied_vec[1], 32);
}

- (void)test_copy_in_range_top {
    auto src_signal_event = signal_event::make_shared<int8_t>(3);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 1;
    src_vec[1] = 2;
    src_vec[2] = 3;

    auto const copied_signal_event = src_signal_event->copy_in_range(time::range{0, 2});
    auto const &copied_vec = copied_signal_event->vector<int8_t>();

    XCTAssertEqual(copied_vec.size(), 2);
    XCTAssertEqual(copied_vec[0], 1);
    XCTAssertEqual(copied_vec[1], 2);
}

- (void)test_copy_in_range_middle {
    auto src_signal_event = signal_event::make_shared<int8_t>(3);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 11;
    src_vec[1] = 12;
    src_vec[2] = 13;

    auto const copied_signal_event = src_signal_event->copy_in_range(time::range{1, 1});
    auto const &copied_vec = copied_signal_event->vector<int8_t>();

    XCTAssertEqual(copied_vec.size(), 1);
    XCTAssertEqual(copied_vec[0], 12);
}

- (void)test_copy_in_range_tail {
    auto src_signal_event = signal_event::make_shared<int8_t>(3);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 21;
    src_vec[1] = 22;
    src_vec[2] = 23;

    auto const copied_signal_event = src_signal_event->copy_in_range(time::range{1, 2});
    auto const &copied_vec = copied_signal_event->vector<int8_t>();

    XCTAssertEqual(copied_vec.size(), 2);
    XCTAssertEqual(copied_vec[0], 22);
    XCTAssertEqual(copied_vec[1], 23);
}

- (void)test_copy_in_range_failed {
    auto src_signal_event = signal_event::make_shared<int8_t>(3);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 31;
    src_vec[1] = 32;
    src_vec[2] = 33;

    XCTAssertThrows(src_signal_event->copy_in_range(time::range{0, 4}));
    XCTAssertThrows(src_signal_event->copy_in_range(time::range{2, 2}));
    XCTAssertThrows(src_signal_event->copy_in_range(time::range{3, 1}));
}

- (void)test_cropped_top {
    auto src_signal_event = signal_event::make_shared<int8_t>(3);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 41;
    src_vec[1] = 42;
    src_vec[2] = 43;

    auto cropped_signal_events = src_signal_event->cropped(time::range{0, 2});

    XCTAssertEqual(cropped_signal_events.size(), 1);

    auto const &copied_pair = cropped_signal_events.at(0);

    XCTAssertEqual(copied_pair.first, time::range(2, 1));

    auto const &copied_sigal_event = copied_pair.second;
    auto const &copied_vec = copied_sigal_event->vector<int8_t>();

    XCTAssertEqual(copied_vec.size(), 1);
    XCTAssertEqual(copied_vec[0], 43);
}

- (void)test_cropped_middle {
    auto src_signal_event = signal_event::make_shared<int8_t>(3);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 51;
    src_vec[1] = 52;
    src_vec[2] = 53;

    auto cropped_signal_events = src_signal_event->cropped(time::range{1, 1});

    XCTAssertEqual(cropped_signal_events.size(), 2);

    {
        auto const &copied_pair = cropped_signal_events.at(0);

        XCTAssertEqual(copied_pair.first, time::range(0, 1));

        auto const &copied_sigal_event = copied_pair.second;
        auto const &copied_vec = copied_sigal_event->vector<int8_t>();

        XCTAssertEqual(copied_vec.size(), 1);
        XCTAssertEqual(copied_vec[0], 51);
    }

    {
        auto const &copied_pair = cropped_signal_events.at(1);

        XCTAssertEqual(copied_pair.first, time::range(2, 1));

        auto const &copied_sigal_event = copied_pair.second;
        auto const &copied_vec = copied_sigal_event->vector<int8_t>();

        XCTAssertEqual(copied_vec.size(), 1);
        XCTAssertEqual(copied_vec[0], 53);
    }
}

- (void)test_cropped_tail {
    auto src_signal_event = signal_event::make_shared<int8_t>(3);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 61;
    src_vec[1] = 62;
    src_vec[2] = 63;

    auto cropped_signal_events = src_signal_event->cropped(time::range{1, 2});

    XCTAssertEqual(cropped_signal_events.size(), 1);

    auto const &copied_pair = cropped_signal_events.at(0);

    XCTAssertEqual(copied_pair.first, time::range(0, 1));

    auto const &copied_sigal_event = copied_pair.second;
    auto const &copied_vec = copied_sigal_event->vector<int8_t>();

    XCTAssertEqual(copied_vec.size(), 1);
    XCTAssertEqual(copied_vec[0], 61);
}

- (void)test_cropped_failed {
    auto src_signal_event = signal_event::make_shared<int8_t>(3);
    auto &src_vec = src_signal_event->vector<int8_t>();
    src_vec[0] = 71;
    src_vec[1] = 72;
    src_vec[2] = 73;

    XCTAssertThrows(src_signal_event->cropped(time::range{0, 4}));
    XCTAssertThrows(src_signal_event->cropped(time::range{2, 2}));
    XCTAssertThrows(src_signal_event->cropped(time::range{3, 1}));
}

- (void)test_combined {
    auto main_signal_event = signal_event::make_shared<int8_t>(1);
    auto &main_vec = main_signal_event->vector<int8_t>();
    main_vec[0] = 12;

    auto sub_signal_event_0 = signal_event::make_shared<int8_t>(1);
    auto &sub_vec_0 = sub_signal_event_0->vector<int8_t>();
    sub_vec_0[0] = 11;

    auto sub_signal_event_1 = signal_event::make_shared<int8_t>(1);
    auto &sub_vec_1 = sub_signal_event_1->vector<int8_t>();
    sub_vec_1[0] = 13;

    auto const combined = main_signal_event->combined(
        time::range{1, 1}, {std::make_pair(time::range{0, 1}, std::move(sub_signal_event_0)),
                            std::make_pair(time::range{2, 1}, std::move(sub_signal_event_1))});

    XCTAssertEqual(combined.first, time::range(0, 3));

    auto const &combined_signal = combined.second;
    auto const &combined_vec = combined_signal->vector<int8_t>();

    XCTAssertEqual(combined_vec.size(), 3);
    XCTAssertEqual(combined_vec[0], 11);
    XCTAssertEqual(combined_vec[1], 12);
    XCTAssertEqual(combined_vec[2], 13);
}

@end
