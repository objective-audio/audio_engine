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

- (void)test_filter_vector
{
    std::vector<int> vec{1, 4, 5, 3, 2};
    auto filtered_vec = yas::filter(vec, [](const auto &val) { return (val % 2) != 0; });

    XCTAssertEqual(filtered_vec.size(), 3);
    XCTAssertEqual(filtered_vec[0], 1);
    XCTAssertEqual(filtered_vec[1], 5);
    XCTAssertEqual(filtered_vec[2], 3);
}

- (void)test_filter_map
{
    std::map<int, int> map{{0, 12}, {1, 11}, {2, 10}, {3, 9}, {4, 8}};
    auto filtered_map = yas::filter(map, [](const auto &pair) { return (pair.second % 2) != 0; });

    XCTAssertEqual(filtered_map.size(), 2);

    XCTAssertEqual(filtered_map.at(1), 11);
    XCTAssertEqual(filtered_map.at(3), 9);

    XCTAssertThrows(filtered_map.at(0));
    XCTAssertThrows(filtered_map.at(2));
    XCTAssertThrows(filtered_map.at(4));
}

- (void)test_erase_if
{
    std::unordered_set<int> set{0, 1, 2, 3, 4};
    yas::erase_if(set, [](const auto &val) { return (val % 2) != 0; });

    XCTAssertEqual(set.size(), 3);

    XCTAssertTrue(set.count(0));
    XCTAssertFalse(set.count(1));
    XCTAssertTrue(set.count(2));
    XCTAssertFalse(set.count(3));
    XCTAssertTrue(set.count(4));
}

- (void)test_enumerate
{
    int count = 0;
    int sum = 0;

    std::vector<int> vec{3, 6, 9};

    yas::enumerate(vec, [&count, &sum](auto &it) {
        ++count;
        sum += *it;
        return ++it;
    });

    XCTAssertEqual(count, 3);
    XCTAssertEqual(sum, (3 + 6 + 9));
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
