//
//  yas_any_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_any_tests : XCTestCase

@end

@implementation yas_any_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_types
{
    int int_value = 1;
    float float_value = 2.0;
    std::string string_value = "3";

    std::vector<yas::any> vector = {yas::any(int_value), yas::any(float_value), yas::any(string_value)};

    XCTAssertTrue(vector.at(0));
    XCTAssertTrue(vector.at(1));
    XCTAssertTrue(vector.at(2));

    XCTAssertTrue(vector.at(0).type() == typeid(int));
    XCTAssertTrue(vector.at(1).type() == typeid(float));
    XCTAssertTrue(vector.at(2).type() == typeid(std::string));

    XCTAssertEqual(vector.at(0).get<int>(), 1);
    XCTAssertEqual(vector.at(1).get<float>(), 2.0);
    XCTAssertEqual(vector.at(2).get<std::string>(), "3");
}

- (void)test_empty_to_set
{
    yas::any any;

    XCTAssertFalse(any);
    XCTAssertTrue(any.type() == typeid(void));

    int int_value = 1;
    any = int_value;

    XCTAssertTrue(any);
    XCTAssertTrue(any.type() == typeid(int));
    XCTAssertEqual(any.get<int>(), 1);
}

- (void)test_assign
{
    int int_value1 = 1;
    yas::any any1(int_value1);

    XCTAssertEqual(any1.get<int>(), 1);

    int int_value2 = 2;
    yas::any any2(int_value2);

    any1 = any2;

    XCTAssertEqual(any1.get<int>(), 2);
}

@end
