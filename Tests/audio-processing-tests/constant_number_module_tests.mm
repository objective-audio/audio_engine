//
//  yas_processin_constant_number_module_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module/maker/constant_module.h>
#import <cpp-utils/boolean.h>

using namespace yas;
using namespace yas::proc;

@interface constant_number_module_tests : XCTestCase

@end

@implementation constant_number_module_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_make_number_module {
    XCTAssertTrue(make_number_module(double(1.0)));
    XCTAssertTrue(make_number_module(float(1.0)));
    XCTAssertTrue(make_number_module(int64_t(1)));
    XCTAssertTrue(make_number_module(int32_t(1)));
    XCTAssertTrue(make_number_module(int16_t(1)));
    XCTAssertTrue(make_number_module(int8_t(1)));
    XCTAssertTrue(make_number_module(uint64_t(1)));
    XCTAssertTrue(make_number_module(uint32_t(1)));
    XCTAssertTrue(make_number_module(uint16_t(1)));
    XCTAssertTrue(make_number_module(uint8_t(1)));
    XCTAssertTrue(make_number_module(boolean(true)));
}

- (void)test_process {
    int16_t const value = 55;

    auto module = make_number_module(value);
    module->connect_output(to_connector_index(constant::output::value), 0);

    stream stream{sync_source{1, 2}};

    module->process(time::range{3, 2}, stream);

    XCTAssertTrue(stream.has_channel(0));

    auto const &channel = stream.channel(0);

    XCTAssertEqual(channel.events().size(), 1);

    auto const &event_pair = *channel.events().cbegin();
    auto const &time = event_pair.first;
    auto const number = event_pair.second.get<number_event>();

    XCTAssertTrue(time.type() == typeid(time::frame));

    auto const &frame = time.get<time::frame>();

    XCTAssertEqual(frame, 3);
    XCTAssertEqual(number->get<int16_t>(), 55);
}

@end
