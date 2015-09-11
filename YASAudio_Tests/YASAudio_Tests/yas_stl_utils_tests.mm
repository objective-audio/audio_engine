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

@end
