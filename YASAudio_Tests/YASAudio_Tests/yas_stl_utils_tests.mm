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

- (void)test_lock_values
{
    auto shared_1 = std::make_shared<float>(1.0f);
    auto shared_2 = std::make_shared<float>(2.0f);
    std::weak_ptr<float> weak_1 = shared_1;
    std::weak_ptr<float> weak_2 = shared_2;

    std::map<int, std::weak_ptr<float>> map;
    map.insert(std::make_pair(1, weak_1));
    map.insert(std::make_pair(2, weak_2));

    auto shared_map = yas::lock_values(map);

    XCTAssertEqual(shared_map.size(), 2);

    for (auto &pair : shared_map) {
        switch (pair.first) {
            case 1:
                XCTAssertEqual(*pair.second, 1.0f);
                break;
            case 2:
                XCTAssertEqual(*pair.second, 2.0f);
                break;
            default:
                break;
        }
    }
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

@end
