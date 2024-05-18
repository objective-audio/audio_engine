//
//  constant_signal_module_tests.mm
//

#import <XCTest/XCTest.h>
#import <cpp-utils/boolean.h>
#import <audio-processing/module/maker/constant_module.h>

using namespace yas;
using namespace yas::proc;

@interface constant_signal_module_tests : XCTestCase

@end

@implementation constant_signal_module_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_signal_module {
    XCTAssertTrue(make_signal_module(double(1.0)));
    XCTAssertTrue(make_signal_module(float(1.0)));
    XCTAssertTrue(make_signal_module(int64_t(1)));
    XCTAssertTrue(make_signal_module(int32_t(1)));
    XCTAssertTrue(make_signal_module(int16_t(1)));
    XCTAssertTrue(make_signal_module(int8_t(1)));
    XCTAssertTrue(make_signal_module(uint64_t(1)));
    XCTAssertTrue(make_signal_module(uint32_t(1)));
    XCTAssertTrue(make_signal_module(uint16_t(1)));
    XCTAssertTrue(make_signal_module(uint8_t(1)));
    XCTAssertTrue(make_signal_module(boolean(true)));
}

- (void)test_process {
    int64_t const value = 5;

    auto module = make_signal_module(value);
    module->connect_output(to_connector_index(constant::output::value), 0);

    proc::stream stream{sync_source{1, 2}};

    module->process({0, 2}, stream);

    XCTAssertTrue(stream.has_channel(0));

    auto const &channel = stream.channel(0);

    XCTAssertEqual(channel.events().size(), 1);

    auto const &event_pair = *channel.events().cbegin();
    auto const &time = event_pair.first;
    auto const signal = event_pair.second.get<signal_event>();

    XCTAssertTrue(time.type() == typeid(time::range));

    auto const &time_range = time.get<time::range>();

    XCTAssertEqual(time_range.frame, 0);
    XCTAssertEqual(time_range.length, 2);
    XCTAssertEqual(signal->size(), 2);

    auto const &vec = signal->vector<int64_t>();

    XCTAssertEqual(vec[0], 5);
    XCTAssertEqual(vec[1], 5);
}

@end
