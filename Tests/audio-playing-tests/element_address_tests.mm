//
//  yas_playing_element_address_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

@interface element_address_tests : XCTestCase

@end

@implementation element_address_tests

- (void)test_equal {
    element_address const address1a{.file_channel_index = 0, .fragment_range = {.index = 0, .length = 1}};
    element_address const address1b{.file_channel_index = 0, .fragment_range = {.index = 0, .length = 1}};
    element_address const address2a{.file_channel_index = std::nullopt, .fragment_range = {.index = 0, .length = 1}};
    element_address const address2b{.file_channel_index = std::nullopt, .fragment_range = {.index = 0, .length = 1}};
    element_address const address3{.file_channel_index = 1, .fragment_range = {.index = 0, .length = 1}};
    element_address const address4{.file_channel_index = 0, .fragment_range = {.index = 1, .length = 1}};

    XCTAssertTrue(address1a == address1b);
    XCTAssertTrue(address2a == address2b);

    XCTAssertFalse(address1a == address2a);
    XCTAssertFalse(address1a == address3);
    XCTAssertFalse(address1a == address4);

    XCTAssertFalse(address1a != address1b);
    XCTAssertFalse(address2a != address2b);

    XCTAssertTrue(address1a != address2a);
    XCTAssertTrue(address1a != address3);
    XCTAssertTrue(address1a != address4);
}

@end
