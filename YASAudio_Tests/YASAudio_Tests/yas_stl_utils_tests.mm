//
//  yas_stl_utils_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_stl_utils_tests : XCTestCase

@end

@implementation yas_stl_utils_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_min_empty_key_insert
{
    std::map<UInt8, UInt8> map;

    auto key = yas::min_empty_key(map);
    XCTAssertTrue(key);
    XCTAssertEqual(*key, 0);

    map.insert(std::make_pair(0, 0));

    key = yas::min_empty_key(map);
    XCTAssertTrue(key);
    XCTAssertEqual(*key, 1);
}

- (void)test_min_empty_key_insert_gappy
{
    std::map<UInt8, UInt8> map;

    map.insert(std::make_pair(1, 1));

    auto key = yas::min_empty_key(map);
    XCTAssertTrue(key);
    XCTAssertEqual(*key, 0);
}

- (void)test_min_empty_key_filled
{
    std::map<UInt8, UInt8> map;

    for (UInt16 i = 0; i < std::numeric_limits<UInt8>::max(); ++i) {
        map.insert(std::make_pair(i, i));
    }

    auto key = yas::min_empty_key(map);
    XCTAssertFalse(key);
}

- (void)test_to_vector
{
    std::unordered_set<int> set{1, 3, 5};
    auto vec = yas::to_vector(set);

    XCTAssertEqual(set.size(), 3);
    XCTAssertEqual(vec.size(), 3);

    XCTAssertEqual(*set.begin(), vec[0]);
    XCTAssertEqual(*(++set.begin()), vec[1]);
}

@end
