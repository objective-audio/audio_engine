//
//  numbers_file_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/boolean.h>
#import <cpp-utils/file_manager.h>
#import <cpp-utils/file_path.h>
#import <cpp-utils/system_path_utils.h>
#import <audio-playing/umbrella.hpp>
#import "test_utils.h"

using namespace yas;
using namespace yas::playing;

namespace yas::playing::numbers_file_test {
struct cpp {
    std::string const root_path = test_utils::root_path();
};
}  // namespace yas::playing::numbers_file_test

@interface numbers_file_tests : XCTestCase

@end

@implementation numbers_file_tests {
    numbers_file_test::cpp _cpp;
}

- (void)setUp {
    file_manager::remove_content(self->_cpp.root_path);
}

- (void)tearDown {
    file_manager::remove_content(self->_cpp.root_path);
}

- (void)test_numbers_file {
    auto dir_result = file_manager::create_directory_if_not_exists(self->_cpp.root_path);

    XCTAssertTrue(dir_result);

    auto const path = file_path{self->_cpp.root_path}.appending("numbers").string();

    numbers_file::event_map_t write_events{
        {0, proc::number_event::make_shared(double(0.0))},   {1, proc::number_event::make_shared(float(1.0))},
        {2, proc::number_event::make_shared(int64_t(2))},    {3, proc::number_event::make_shared(uint64_t(3))},
        {4, proc::number_event::make_shared(int32_t(4))},    {5, proc::number_event::make_shared(uint32_t(5))},
        {6, proc::number_event::make_shared(int16_t(6))},    {7, proc::number_event::make_shared(uint16_t(7))},
        {8, proc::number_event::make_shared(int8_t(8))},     {9, proc::number_event::make_shared(uint8_t(9))},
        {10, proc::number_event::make_shared(boolean(true))}};

    auto write_result = numbers_file::write(path, write_events);

    XCTAssertTrue(write_result);

    auto read_result = numbers_file::read(path);

    XCTAssertTrue(read_result);

    numbers_file::event_map_t const &read_events = read_result.value();

    XCTAssertEqual(read_events.size(), 11);

    XCTAssertTrue(read_events.find(0)->second->is_equal(proc::number_event::make_shared(double(0.0))));
    XCTAssertTrue(read_events.find(1)->second->is_equal(proc::number_event::make_shared(float(1.0))));
    XCTAssertTrue(read_events.find(2)->second->is_equal(proc::number_event::make_shared(int64_t(2))));
    XCTAssertTrue(read_events.find(3)->second->is_equal(proc::number_event::make_shared(uint64_t(3))));
    XCTAssertTrue(read_events.find(4)->second->is_equal(proc::number_event::make_shared(int32_t(4))));
    XCTAssertTrue(read_events.find(5)->second->is_equal(proc::number_event::make_shared(uint32_t(5))));
    XCTAssertTrue(read_events.find(6)->second->is_equal(proc::number_event::make_shared(int16_t(6))));
    XCTAssertTrue(read_events.find(7)->second->is_equal(proc::number_event::make_shared(uint16_t(7))));
    XCTAssertTrue(read_events.find(8)->second->is_equal(proc::number_event::make_shared(int8_t(8))));
    XCTAssertTrue(read_events.find(9)->second->is_equal(proc::number_event::make_shared(uint8_t(9))));
    XCTAssertTrue(read_events.find(10)->second->is_equal(proc::number_event::make_shared(boolean(true))));
}

- (void)test_write_error_to_string {
    XCTAssertEqual(to_string(numbers_file::write_error::open_stream_failed), "open_stream_failed");
    XCTAssertEqual(to_string(numbers_file::write_error::write_to_stream_failed), "write_to_stream_failed");
    XCTAssertEqual(to_string(numbers_file::write_error::close_stream_failed), "close_stream_failed");
}

- (void)test_read_error_to_string {
    XCTAssertEqual(to_string(numbers_file::read_error::open_stream_failed), "open_stream_failed");
    XCTAssertEqual(to_string(numbers_file::read_error::read_frame_failed), "read_frame_failed");
    XCTAssertEqual(to_string(numbers_file::read_error::read_sample_store_type_failed), "read_sample_store_type_failed");
    XCTAssertEqual(to_string(numbers_file::read_error::read_value_failed), "read_value_failed");
    XCTAssertEqual(to_string(numbers_file::read_error::sample_store_type_not_found), "sample_store_type_not_found");
}

@end
