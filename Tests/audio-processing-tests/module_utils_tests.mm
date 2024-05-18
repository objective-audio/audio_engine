//
//  module_utils_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/module_utils.h>

using namespace yas;
using namespace yas::proc;

@interface module_utils_tests : XCTestCase

@end

@implementation module_utils_tests

- (void)test_module_frame {
    XCTAssertEqual(module_frame(0, 0), 0);
    XCTAssertEqual(module_frame(1, 0), 1);
    XCTAssertEqual(module_frame(0, 1), -1);
    XCTAssertEqual(module_frame(1, 1), 0);
}

- (void)test_module_file_range {
    XCTAssertEqual(module_file_range({-2, 2}, 0, 0, 2), std::nullopt);
    XCTAssertEqual(module_file_range({-1, 2}, 0, 0, 2).value().range, time::range(0, 1));
    XCTAssertEqual(module_file_range({-1, 2}, 0, 0, 2).value().offset, 1);
    XCTAssertEqual(module_file_range({0, 2}, 0, 0, 2).value().range, time::range(0, 2));
    XCTAssertEqual(module_file_range({0, 2}, 0, 0, 2).value().offset, 0);
    XCTAssertEqual(module_file_range({1, 2}, 0, 0, 2).value().range, time::range(1, 1));
    XCTAssertEqual(module_file_range({1, 2}, 0, 0, 2).value().offset, 0);
    XCTAssertEqual(module_file_range({2, 2}, 0, 0, 2), std::nullopt);

    XCTAssertEqual(module_file_range({8, 2}, 10, 0, 2), std::nullopt);
    XCTAssertEqual(module_file_range({9, 2}, 10, 0, 2).value().range, time::range(0, 1));
    XCTAssertEqual(module_file_range({9, 2}, 10, 0, 2).value().offset, 1);
    XCTAssertEqual(module_file_range({10, 2}, 10, 0, 2).value().range, time::range(0, 2));
    XCTAssertEqual(module_file_range({10, 2}, 10, 0, 2).value().offset, 0);
    XCTAssertEqual(module_file_range({11, 2}, 10, 0, 2).value().range, time::range(1, 1));
    XCTAssertEqual(module_file_range({11, 2}, 10, 0, 2).value().offset, 0);
    XCTAssertEqual(module_file_range({12, 2}, 10, 0, 2), std::nullopt);

    XCTAssertEqual(module_file_range({-12, 2}, -10, 0, 2), std::nullopt);
    XCTAssertEqual(module_file_range({-11, 2}, -10, 0, 2).value().range, time::range(0, 1));
    XCTAssertEqual(module_file_range({-11, 2}, -10, 0, 2).value().offset, 1);
    XCTAssertEqual(module_file_range({-10, 2}, -10, 0, 2).value().range, time::range(0, 2));
    XCTAssertEqual(module_file_range({-10, 2}, -10, 0, 2).value().offset, 0);
    XCTAssertEqual(module_file_range({-9, 2}, -10, 0, 2).value().range, time::range(1, 1));
    XCTAssertEqual(module_file_range({-9, 2}, -10, 0, 2).value().offset, 0);
    XCTAssertEqual(module_file_range({-8, 2}, -10, 0, 2), std::nullopt);

    XCTAssertEqual(module_file_range({-2, 2}, 0, 1, 2), std::nullopt);
    XCTAssertEqual(module_file_range({-1, 2}, 0, 1, 2).value().range, time::range(1, 1));
    XCTAssertEqual(module_file_range({-1, 2}, 0, 1, 2).value().offset, 1);
    XCTAssertEqual(module_file_range({0, 2}, 0, 1, 2).value().range, time::range(1, 1));
    XCTAssertEqual(module_file_range({0, 2}, 0, 1, 2).value().offset, 0);
    XCTAssertEqual(module_file_range({1, 2}, 0, 1, 2), std::nullopt);

    XCTAssertEqual(module_file_range({0, 2}, 0, -1, 2), std::nullopt);
    XCTAssertEqual(module_file_range({0, 2}, 0, 2, 2), std::nullopt);
    XCTAssertEqual(module_file_range({0, 2}, 0, 0, 0), std::nullopt);
}

- (void)test_pcm_format {
    XCTAssertEqual(proc::pcm_format<double>(), audio::pcm_format::float64);
    XCTAssertEqual(proc::pcm_format<float>(), audio::pcm_format::float32);
    XCTAssertEqual(proc::pcm_format<int32_t>(), audio::pcm_format::fixed824);
    XCTAssertEqual(proc::pcm_format<int16_t>(), audio::pcm_format::int16);
}

@end
