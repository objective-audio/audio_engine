//
//  module_set_utils_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/module_set/module_set_utils.h>

using namespace yas;
using namespace yas::proc;

@interface module_set_utils_tests : XCTestCase

@end

@implementation module_set_utils_tests

- (void)test_to_module_set_event_type {
    XCTAssertEqual(to_module_set_event_type(observing::vector::event_type::any), module_set_event_type::any);
    XCTAssertEqual(to_module_set_event_type(observing::vector::event_type::inserted), module_set_event_type::inserted);
    XCTAssertEqual(to_module_set_event_type(observing::vector::event_type::replaced), module_set_event_type::replaced);
    XCTAssertEqual(to_module_set_event_type(observing::vector::event_type::erased), module_set_event_type::erased);
}

@end
