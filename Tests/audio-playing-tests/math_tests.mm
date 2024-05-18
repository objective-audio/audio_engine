//
//  yas_math_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

@interface yas_math_tests : XCTestCase

@end

@implementation yas_math_tests

- (void)setUp {
}

- (void)tearDown {
}

- (void)test_mod_int {
    XCTAssertEqual(math::mod_int(0, 10), 0);
    XCTAssertEqual(math::mod_int(1, 10), 1);
    XCTAssertEqual(math::mod_int(9, 10), 9);
    XCTAssertEqual(math::mod_int(10, 10), 0);
    XCTAssertEqual(math::mod_int(11, 10), 1);
    XCTAssertEqual(math::mod_int(-1, 10), 9);
    XCTAssertEqual(math::mod_int(-9, 10), 1);
    XCTAssertEqual(math::mod_int(-10, 10), 0);
    XCTAssertEqual(math::mod_int(-11, 10), 9);
}

- (void)test_floor_int {
    XCTAssertEqual(math::floor_int(0, 10), 0);
    XCTAssertEqual(math::floor_int(1, 10), 0);
    XCTAssertEqual(math::floor_int(9, 10), 0);
    XCTAssertEqual(math::floor_int(10, 10), 10);
    XCTAssertEqual(math::floor_int(11, 10), 10);
    XCTAssertEqual(math::floor_int(-1, 10), -10);
    XCTAssertEqual(math::floor_int(-9, 10), -10);
    XCTAssertEqual(math::floor_int(-10, 10), -10);
    XCTAssertEqual(math::floor_int(-11, 10), -20);
}

- (void)test_ceil_int {
    XCTAssertEqual(math::ceil_int(0, 10), 0);
    XCTAssertEqual(math::ceil_int(1, 10), 10);
    XCTAssertEqual(math::ceil_int(9, 10), 10);
    XCTAssertEqual(math::ceil_int(10, 10), 10);
    XCTAssertEqual(math::ceil_int(11, 10), 20);
    XCTAssertEqual(math::ceil_int(-1, 10), 0);
    XCTAssertEqual(math::ceil_int(-9, 10), 0);
    XCTAssertEqual(math::ceil_int(-10, 10), -10);
    XCTAssertEqual(math::ceil_int(-11, 10), -10);
}

@end
