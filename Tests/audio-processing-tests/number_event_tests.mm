//
//  number_event_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/event/number_event.h>
#import <cpp-utils/boolean.h>

using namespace yas;
using namespace yas::proc;

@interface number_event_tests : XCTestCase

@end

@implementation number_event_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_get {
    int16_t const value = 3;
    auto event = proc::number_event::make_shared(value);

    XCTAssertEqual(event->get<int16_t>(), 3);
}

- (void)test_sample_byte_count {
    XCTAssertEqual(proc::number_event::make_shared(int8_t(0))->sample_byte_count(), 1);
    XCTAssertEqual(proc::number_event::make_shared(double(0.0))->sample_byte_count(), 8);
    XCTAssertEqual(proc::number_event::make_shared(boolean{false})->sample_byte_count(), 1);
}

- (void)test_sample_type {
    XCTAssertTrue(proc::number_event::make_shared(int8_t(0))->sample_type() == typeid(int8_t));
    XCTAssertTrue(proc::number_event::make_shared(double(0.0))->sample_type() == typeid(double));
    XCTAssertTrue(proc::number_event::make_shared(boolean{false})->sample_type() == typeid(boolean));
}

- (void)test_copy {
    auto src_event = number_event::make_shared(uint32_t(11));
    auto copied_event = src_event->copy();

    XCTAssertTrue(src_event->is_equal(copied_event));
    XCTAssertEqual(copied_event->get<uint32_t>(), 11);
}

@end
