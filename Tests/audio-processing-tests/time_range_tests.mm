//
//  time_tests.mm
//

#import <XCTest/XCTest.h>
#import <audio-processing/time/time.h>

using namespace yas;
using namespace yas::proc;

@interface time_range_tests : XCTestCase

@end

@implementation time_range_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_create_time_range {
    auto range = time::range{100, 200};

    XCTAssertEqual(range.frame, 100);
    XCTAssertEqual(range.length, 200);
    XCTAssertEqual(range.next_frame(), 300);
}

- (void)test_create_length_zero_time_range {
    XCTAssertThrows((time::range{0, 0}));
}

- (void)test_equal_time_range {
    auto range1a = time::range{12, 345};
    auto range1b = time::range{12, 345};
    auto range2 = time::range{12, 678};
    auto range3 = time::range{67, 345};
    auto range4 = time::range{98, 765};

    XCTAssertTrue(range1a == range1b);
    XCTAssertFalse(range1a == range2);
    XCTAssertFalse(range1a == range3);
    XCTAssertFalse(range1a == range4);
}

- (void)test_not_equal_time_range {
    auto range1a = time::range{12, 345};
    auto range1b = time::range{12, 345};
    auto range2 = time::range{12, 678};
    auto range3 = time::range{67, 345};
    auto range4 = time::range{98, 765};

    XCTAssertFalse(range1a != range1b);
    XCTAssertTrue(range1a != range2);
    XCTAssertTrue(range1a != range3);
    XCTAssertTrue(range1a != range4);
}

- (void)test_less_than_time_range {
    auto range1a = time::range{12, 345};
    auto range1b = time::range{12, 345};
    auto range2 = time::range{12, 344};
    auto range3 = time::range{12, 346};
    auto range4 = time::range{11, 400};
    auto range5 = time::range{13, 300};

    XCTAssertFalse(range1a < range1b);
    XCTAssertFalse(range1a < range2);
    XCTAssertTrue(range1a < range3);
    XCTAssertFalse(range1a < range4);
    XCTAssertTrue(range1a < range5);
}

- (void)test_can_combine_time_range {
    auto range1 = time::range{0, 2};
    auto range2 = time::range{2, 2};
    auto range3 = time::range{3, 2};
    auto range4 = time::range{1, 2};
    auto range5 = time::range{-1, 4};

    XCTAssertTrue(range1.can_combine({0, 2}));

    XCTAssertTrue(range1.can_combine(range2));
    XCTAssertFalse(range1.can_combine(range3));
    XCTAssertTrue(range1.can_combine(range4));
    XCTAssertTrue(range1.can_combine(range5));

    XCTAssertTrue(range2.can_combine(range1));
    XCTAssertFalse(range3.can_combine(range1));
    XCTAssertTrue(range4.can_combine(range1));
    XCTAssertTrue(range5.can_combine(range1));
}

- (void)test_combine_time_range {
    auto range1 = time::range{0, 2};
    auto range2 = time::range{2, 2};
    auto range3 = time::range{3, 2};
    auto range4 = time::range{1, 2};
    auto range5 = time::range{-1, 4};

    XCTAssertTrue((range1.combined(range2) == time::range{0, 4}));
    XCTAssertFalse(range1.combined(range3));
    XCTAssertTrue((range1.combined(range4) == time::range{0, 3}));
    XCTAssertTrue((range1.combined(range5) == time::range{-1, 4}));

    XCTAssertTrue((range2.combined(range1) == time::range{0, 4}));
    XCTAssertFalse(range3.combined(range1));
    XCTAssertTrue((range4.combined(range1) == time::range{0, 3}));
    XCTAssertTrue((range5.combined(range1) == time::range{-1, 4}));
}

- (void)test_is_contain_time_range {
    auto range = time::range{5, 2};

    XCTAssertTrue(range.is_contain({5, 2}));
    XCTAssertFalse(range.is_contain({4, 4}));
    XCTAssertFalse(range.is_contain({4, 3}));
    XCTAssertFalse(range.is_contain({6, 3}));
    XCTAssertFalse(range.is_contain({3, 1}));
    XCTAssertFalse(range.is_contain({4, 1}));
    XCTAssertTrue(range.is_contain({5, 1}));
    XCTAssertFalse(range.is_contain({7, 1}));
}

- (void)test_is_contain_frame {
    auto range = time::range{0, 2};

    XCTAssertTrue(range.is_contain(time::frame::type{0}));
    XCTAssertTrue(range.is_contain(time::frame::type{1}));
    XCTAssertFalse(range.is_contain(time::frame::type{2}));
}

- (void)test_is_contain_any {
    auto range = time::range{0, 2};

    XCTAssertTrue(range.is_contain(time::any::type{}));
}

- (void)test_is_overlap_time_range {
    auto range1 = time::range{7, 2};

    XCTAssertTrue(range1.is_overlap({7, 2}));
    XCTAssertTrue(range1.is_overlap({6, 2}));
    XCTAssertTrue(range1.is_overlap({8, 2}));
    XCTAssertTrue(range1.is_overlap({6, 3}));
    XCTAssertTrue(range1.is_overlap({7, 3}));
    XCTAssertTrue(range1.is_overlap({7, 1}));
    XCTAssertTrue(range1.is_overlap({8, 1}));
    XCTAssertFalse(range1.is_overlap({6, 1}));
    XCTAssertFalse(range1.is_overlap({9, 1}));
}

- (void)test_intersect_overlapped {
    XCTAssertEqual((time::range{0, 1}.intersected(time::range{0, 1})), (time::range{0, 1}));
    XCTAssertEqual((time::range{0, 2}.intersected(time::range{1, 2})), (time::range{1, 1}));
    XCTAssertEqual((time::range{0, 2}.intersected(time::range{1, 1})), (time::range{1, 1}));
    XCTAssertEqual((time::range{0, 1}.intersected(time::range{0, 2})), (time::range{0, 1}));
}

- (void)test_intersect_not_overlapped {
    XCTAssertFalse((time::range{0, 1}.intersected(time::range{1, 1})));
    XCTAssertFalse((time::range{0, 1}.intersected(time::range{2, 1})));
    XCTAssertFalse((time::range{0, 1}.intersected(time::range{-1, 1})));
    XCTAssertFalse((time::range{0, 1}.intersected(time::range{-2, 1})));
}

@end
