//
//  sync_source_tests.mm
//

#import <XCTest/XCTest.h>
#include <audio-processing/sync_source/sync_source.h>

using namespace yas;
using namespace yas::proc;

@interface sync_source_tests : XCTestCase

@end

@implementation sync_source_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create {
    sync_source sync_source{1, 2};

    XCTAssertEqual(sync_source.sample_rate, 1);
    XCTAssertEqual(sync_source.slice_length, 2);
}

- (void)test_fail_to_create_with_zero {
    XCTAssertThrows((sync_source{0, 1}));
    XCTAssertThrows((sync_source{1, 0}));
    XCTAssertThrows((sync_source{0, 0}));
}

- (void)test_is_equal {
    sync_source sync_source_1a{44100, 16};
    sync_source sync_source_1b{44100, 16};
    sync_source sync_source_2{48000, 16};
    sync_source sync_source_3{44100, 32};

    XCTAssertTrue(sync_source_1a == sync_source_1a);
    XCTAssertTrue(sync_source_1a == sync_source_1b);
    XCTAssertFalse(sync_source_1a == sync_source_2);
    XCTAssertFalse(sync_source_1a == sync_source_3);
}

- (void)test_is_not_equal {
    sync_source sync_source_1a{44100, 16};
    sync_source sync_source_1b{44100, 16};
    sync_source sync_source_2{48000, 16};
    sync_source sync_source_3{44100, 32};

    XCTAssertFalse(sync_source_1a != sync_source_1a);
    XCTAssertFalse(sync_source_1a != sync_source_1b);
    XCTAssertTrue(sync_source_1a != sync_source_2);
    XCTAssertTrue(sync_source_1a != sync_source_3);
}

@end
