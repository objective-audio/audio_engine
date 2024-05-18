//
//  signal_file_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-engine/format/format.h>
#import <audio-engine/pcm_buffer/pcm_buffer.h>
#import <cpp-utils/file_manager.h>
#import <cpp-utils/file_path.h>
#import <cpp-utils/system_path_utils.h>
#import <audio-playing/umbrella.hpp>
#import <audio-processing/umbrella.hpp>
#import "test_utils.h"

using namespace yas;
using namespace yas::playing;

@interface signal_file_tests : XCTestCase

@end

@implementation signal_file_tests

- (void)setUp {
    file_manager::remove_content(test_utils::root_path());
}

- (void)tearDown {
    file_manager::remove_content(test_utils::root_path());
}

- (void)test_read_with_data_ptr {
    auto dir_result = file_manager::create_directory_if_not_exists(test_utils::root_path());

    XCTAssertTrue(dir_result);

    auto const path = file_path{test_utils::root_path()}.appending("signal").string();

    auto write_event = proc::signal_event::make_shared<int64_t>(2);
    write_event->data<int64_t>()[0] = 10;
    write_event->data<int64_t>()[1] = 11;

    auto const write_result = signal_file::write(path, *write_event);

    XCTAssertTrue(write_result);

    int64_t read_data[2];

    auto const read_result = signal_file::read(path, read_data, sizeof(int64_t) * 2);

    XCTAssertTrue(read_result);

    XCTAssertEqual(read_data[0], 10);
    XCTAssertEqual(read_data[1], 11);
}

- (void)test_read_with_buffer {
    auto dir_result = file_manager::create_directory_if_not_exists(test_utils::root_path());

    XCTAssertTrue(dir_result);

    auto const path = file_path{test_utils::root_path()}.appending("signal").string();
    signal_file_info const file_info{path, proc::time::range{0, 2}, typeid(double)};

    auto write_event = proc::signal_event::make_shared<double>(2);
    write_event->data<double>()[0] = 1.0;
    write_event->data<double>()[1] = 2.0;

    auto const write_result = signal_file::write(path, *write_event);

    XCTAssertTrue(write_result);

    audio::format const format{
        {.sample_rate = 2.0, .channel_count = 1, .pcm_format = audio::pcm_format::float64, .interleaved = false}};
    audio::pcm_buffer buffer{format, 2};

    auto const read_result = signal_file::read(file_info, buffer, 0);

    XCTAssertTrue(read_result);

    XCTAssertEqual(buffer.data_ptr_at_index<double>(0)[0], 1.0);
    XCTAssertEqual(buffer.data_ptr_at_index<double>(0)[1], 2.0);
}

- (void)test_write_error_to_string {
    XCTAssertEqual(to_string(signal_file::write_error::open_stream_failed), "open_stream_failed");
    XCTAssertEqual(to_string(signal_file::write_error::write_to_stream_failed), "write_to_stream_failed");
    XCTAssertEqual(to_string(signal_file::write_error::close_stream_failed), "close_stream_failed");
}

- (void)test_read_error_to_string {
    XCTAssertEqual(to_string(signal_file::read_error::invalid_sample_type), "invalid_sample_type");
    XCTAssertEqual(to_string(signal_file::read_error::out_of_range), "out_of_range");
    XCTAssertEqual(to_string(signal_file::read_error::open_stream_failed), "open_stream_failed");
    XCTAssertEqual(to_string(signal_file::read_error::read_from_stream_failed), "read_from_stream_failed");
    XCTAssertEqual(to_string(signal_file::read_error::read_count_not_match), "read_count_not_match");
    XCTAssertEqual(to_string(signal_file::read_error::close_stream_failed), "close_stream_failed");
}

- (void)test_write_error_ostream {
    auto const values = {signal_file::write_error::open_stream_failed, signal_file::write_error::write_to_stream_failed,
                         signal_file::write_error::close_stream_failed};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

- (void)test_read_error_ostream {
    auto const values = {
        signal_file::read_error::invalid_sample_type,  signal_file::read_error::out_of_range,
        signal_file::read_error::open_stream_failed,   signal_file::read_error::read_from_stream_failed,
        signal_file::read_error::read_count_not_match, signal_file::read_error::close_stream_failed};

    for (auto const &value : values) {
        std::ostringstream stream;
        stream << value;
        XCTAssertEqual(stream.str(), to_string(value));
    }
}

@end
