//
//  yas_playing_channel_mapping_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-playing/umbrella.hpp>

using namespace yas;
using namespace yas::playing;

@interface channel_mapping_tests : XCTestCase

@end

@implementation channel_mapping_tests

- (void)test_make_empty {
    channel_mapping const mapping{};

    XCTAssertEqual(mapping.indices.size(), 0);
}

- (void)test_make_with_indices {
    channel_mapping const mapping{.indices = {3, 2, 1}};

    XCTAssertEqual(mapping.indices, (std::vector<channel_index_t>{3, 2, 1}));
}

- (void)test_mapped {
    channel_mapping const mapping{.indices = {3, 2, 1}};

    XCTAssertEqual(mapping.file_index(-1, 3), std::nullopt);
    XCTAssertEqual(mapping.file_index(0, 3), 3);
    XCTAssertEqual(mapping.file_index(1, 3), 2);
    XCTAssertEqual(mapping.file_index(2, 3), 1);
    XCTAssertEqual(mapping.file_index(4, 3), std::nullopt);

    XCTAssertEqual(mapping.file_index(-1, 2), std::nullopt);
    XCTAssertEqual(mapping.file_index(0, 2), 3);
    XCTAssertEqual(mapping.file_index(1, 2), 2);
    XCTAssertEqual(mapping.file_index(2, 2), std::nullopt);
}

- (void)test_unmapped {
    channel_mapping const mapping{.indices = {3, 2, 1}};

    XCTAssertEqual(mapping.out_index(-1, 3), std::nullopt);
    XCTAssertEqual(mapping.out_index(0, 3), std::nullopt);
    XCTAssertEqual(mapping.out_index(1, 3), 2);
    XCTAssertEqual(mapping.out_index(2, 3), 1);
    XCTAssertEqual(mapping.out_index(3, 3), 0);
    XCTAssertEqual(mapping.out_index(4, 3), std::nullopt);

    XCTAssertEqual(mapping.out_index(-1, 2), std::nullopt);
    XCTAssertEqual(mapping.out_index(0, 2), std::nullopt);
    XCTAssertEqual(mapping.out_index(1, 2), std::nullopt);
    XCTAssertEqual(mapping.out_index(2, 2), 1);
    XCTAssertEqual(mapping.out_index(3, 2), 0);
    XCTAssertEqual(mapping.out_index(4, 2), std::nullopt);
}

@end
