//
//  timeline_utils_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/boolean.h>
#import <audio-playing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

@interface timeline_utils_tests : XCTestCase

@end

@implementation timeline_utils_tests

- (void)test_fragments_range {
    XCTAssertEqual(timeline_utils::fragments_range({0, 1}, 2), proc::time::range(0, 2));
    XCTAssertEqual(timeline_utils::fragments_range({0, 2}, 2), proc::time::range(0, 2));
    XCTAssertEqual(timeline_utils::fragments_range({1, 1}, 2), proc::time::range(0, 2));

    XCTAssertEqual(timeline_utils::fragments_range({1, 2}, 2), proc::time::range(0, 4));
    XCTAssertEqual(timeline_utils::fragments_range({-1, 2}, 2), proc::time::range(-2, 4));

    XCTAssertEqual(timeline_utils::fragments_range({1, 4}, 2), proc::time::range(0, 6));
}

- (void)test_char_data_from_signal_event {
    {
        auto const event = proc::signal_event::make_shared(std::vector<double>{1.0, 2.0});
        double const *data = (double *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 1.0);
        XCTAssertEqual(data[1], 2.0);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<float>{4.0, 8.0});
        float const *data = (float *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 4.0);
        XCTAssertEqual(data[1], 8.0);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<int64_t>{1, 2});
        int64_t const *data = (int64_t *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 1);
        XCTAssertEqual(data[1], 2);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<uint64_t>{3, 4});
        uint64_t const *data = (uint64_t *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 3);
        XCTAssertEqual(data[1], 4);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<int32_t>{5, 6});
        int32_t const *data = (int32_t *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 5);
        XCTAssertEqual(data[1], 6);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<uint32_t>{7, 8});
        uint32_t const *data = (uint32_t *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 7);
        XCTAssertEqual(data[1], 8);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<int16_t>{9, 10});
        int16_t const *data = (int16_t *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 9);
        XCTAssertEqual(data[1], 10);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<uint16_t>{11, 12});
        uint16_t const *data = (uint16_t *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 11);
        XCTAssertEqual(data[1], 12);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<int8_t>{13, 14});
        int8_t const *data = (int8_t *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 13);
        XCTAssertEqual(data[1], 14);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<uint8_t>{15, 16});
        uint8_t const *data = (uint8_t *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], 15);
        XCTAssertEqual(data[1], 16);
    }
    {
        auto const event = proc::signal_event::make_shared(std::vector<boolean>{false, true});
        boolean const *data = (boolean *)timeline_utils::char_data(*event);
        XCTAssertEqual(data[0], false);
        XCTAssertEqual(data[1], true);
    }
}

- (void)test_char_data_from_time_frame_type {
    proc::time::frame::type const frame{123};
    XCTAssertEqual(*(proc::time::frame::type *)timeline_utils::char_data(frame), 123);
}

- (void)test_char_data_from_sample_store_type {
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::float64)), 1);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::float32)), 2);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::int64)), 3);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::uint64)), 4);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::int32)), 5);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::uint32)), 6);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::int16)), 7);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::uint16)), 8);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::int8)), 9);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::uint8)), 10);
    XCTAssertEqual((*timeline_utils::char_data(sample_store_type::boolean)), 11);
}

- (void)test_char_data_from_number_event {
    {
        auto const event = proc::number_event::make_shared<double>(2.0);
        XCTAssertEqual(*(double *)timeline_utils::char_data(*event), 2.0);
    }
    {
        auto const event = proc::number_event::make_shared<float>(4.0);
        XCTAssertEqual(*(float *)timeline_utils::char_data(*event), 4.0);
    }
    {
        auto const event = proc::number_event::make_shared<int64_t>(100);
        XCTAssertEqual(*(int64_t *)timeline_utils::char_data(*event), 100);
    }
    {
        auto const event = proc::number_event::make_shared<uint64_t>(101);
        XCTAssertEqual(*(uint64_t *)timeline_utils::char_data(*event), 101);
    }
    {
        auto const event = proc::number_event::make_shared<int32_t>(102);
        XCTAssertEqual(*(int32_t *)timeline_utils::char_data(*event), 102);
    }
    {
        auto const event = proc::number_event::make_shared<uint32_t>(103);
        XCTAssertEqual(*(uint32_t *)timeline_utils::char_data(*event), 103);
    }
    {
        auto const event = proc::number_event::make_shared<int16_t>(104);
        XCTAssertEqual(*(int16_t *)timeline_utils::char_data(*event), 104);
    }
    {
        auto const event = proc::number_event::make_shared<uint16_t>(105);
        XCTAssertEqual(*(uint16_t *)timeline_utils::char_data(*event), 105);
    }
    {
        auto const event = proc::number_event::make_shared<int8_t>(106);
        XCTAssertEqual(*(int8_t *)timeline_utils::char_data(*event), 106);
    }
    {
        auto const event = proc::number_event::make_shared<uint8_t>(107);
        XCTAssertEqual(*(uint8_t *)timeline_utils::char_data(*event), 107);
    }
    {
        auto const event = proc::number_event::make_shared<boolean>(true);
        XCTAssertEqual(*(boolean *)timeline_utils::char_data(*event), true);
    }
}

- (void)test_char_data_from_pcm_buffer {
    {
        audio::format const format{{.pcm_format = audio::pcm_format::float64, .sample_rate = 1, .channel_count = 1}};
        audio::pcm_buffer buffer{format, 1};
        XCTAssertEqual((void *)(timeline_utils::char_data(buffer)), (void *)(buffer.data_ptr_at_index<double>(0)));
    }
    {
        audio::format const format{{.pcm_format = audio::pcm_format::float32, .sample_rate = 1, .channel_count = 1}};
        audio::pcm_buffer buffer{format, 1};
        XCTAssertEqual((void *)(timeline_utils::char_data(buffer)), (void *)(buffer.data_ptr_at_index<float>(0)));
    }
    {
        audio::format const format{{.pcm_format = audio::pcm_format::int16, .sample_rate = 1, .channel_count = 1}};
        audio::pcm_buffer buffer{format, 1};
        XCTAssertEqual((void *)(timeline_utils::char_data(buffer)), (void *)(buffer.data_ptr_at_index<int16_t>(0)));
    }
    {
        audio::format const format{{.pcm_format = audio::pcm_format::fixed824, .sample_rate = 1, .channel_count = 1}};
        audio::pcm_buffer buffer{format, 1};
        XCTAssertEqual((void *)(timeline_utils::char_data(buffer)), (void *)(buffer.data_ptr_at_index<int32_t>(0)));
    }
}

- (void)test_to_sample_store_type {
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(double)) == sample_store_type::float64);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(float)) == sample_store_type::float32);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(int64_t)) == sample_store_type::int64);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(uint64_t)) == sample_store_type::uint64);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(int32_t)) == sample_store_type::int32);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(uint32_t)) == sample_store_type::uint32);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(int16_t)) == sample_store_type::int16);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(uint16_t)) == sample_store_type::uint16);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(int8_t)) == sample_store_type::int8);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(uint8_t)) == sample_store_type::uint8);
    XCTAssertTrue(timeline_utils::to_sample_store_type(typeid(boolean)) == sample_store_type::boolean);
}

- (void)test_to_sample_type {
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::float64) == typeid(double));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::float32) == typeid(float));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::int64) == typeid(int64_t));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::uint64) == typeid(uint64_t));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::int32) == typeid(int32_t));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::uint32) == typeid(uint32_t));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::int16) == typeid(int16_t));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::uint16) == typeid(uint16_t));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::int8) == typeid(int8_t));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::uint8) == typeid(uint8_t));
    XCTAssertTrue(timeline_utils::to_sample_type(sample_store_type::boolean) == typeid(boolean));
}

@end
