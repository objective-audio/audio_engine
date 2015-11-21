//
//  yas_property_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

enum class test_key {
    property1,
    property2,
};

struct test_class {
    yas::property<int, test_key> property1;
    yas::property<int, test_key> property2;

    yas::subject<yas::property<int, test_key>> properties_subject;
    yas::observer<yas::property<int, test_key>> dispatcher;

    test_class()
        : property1(test_key::property1, 1),
          property2(test_key::property2, 2),
          dispatcher(yas::make_subject_dispatcher(properties_subject, {&property1.subject(), &property2.subject()}))
    {
    }
};

@interface yas_property_tests : XCTestCase

@end

@implementation yas_property_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_create_property
{
    yas::property<float> float_property;

    float_property.set_value(1.0f);

    XCTAssertEqual(float_property.value(), 1.0f);
}

- (void)test_create_property_with_key
{
    int key = 1;
    float value1 = 1.5;

    yas::property<float, int> float_property(key, value1);

    XCTAssertEqual(key, float_property.key());
    XCTAssertEqual(float_property.value(), value1);

    float value2 = 3.2;

    float_property.set_value(value2);

    XCTAssertEqual(float_property.value(), value2);
    XCTAssertNotEqual(float_property.value(), value1);
}

- (void)test_change_value
{
    yas::property<int, int> property(1, 2);

    XCTAssertEqual(property.value(), 2);

    property.set_value(3);

    XCTAssertNotEqual(property.value(), 2);
    XCTAssertEqual(property.value(), 3);
}

- (void)test_observe_value
{
    yas::property<bool, int> property(1, false);
    yas::observer<yas::property<bool, int>> observer;

    bool will_change_called = false;

    observer.add_handler(property.subject(), yas::property_method::will_change,
                         [self, &will_change_called](const std::string &method, const yas::any &sender) {
                             XCTAssertEqual(method, yas::property_method::will_change);
                             auto &property = sender.get<yas::property<bool, int>>();
                             XCTAssertEqual(property.key(), 1);
                             XCTAssertEqual(property.value(), false);
                             will_change_called = true;
                         });

    bool did_change_called = false;

    observer.add_handler(property.subject(), yas::property_method::did_change,
                         [self, &did_change_called](const std::string &method, const yas::any &sender) {
                             XCTAssertEqual(method, yas::property_method::did_change);
                             auto &property = sender.get<yas::property<bool, int>>();
                             XCTAssertEqual(property.key(), 1);
                             XCTAssertEqual(property.value(), true);
                             did_change_called = true;
                         });

    int wildcard_called_count = 0;

    observer.add_wild_card_handler(property.subject(),
                                   [self, &wildcard_called_count](const std::string &method, const yas::any &sender) {
                                       auto &property = sender.get<yas::property<bool, int>>();
                                       if (method == yas::property_method::will_change) {
                                           XCTAssertEqual(property.key(), 1);
                                           XCTAssertEqual(property.value(), false);
                                       } else if (method == yas::property_method::did_change) {
                                           XCTAssertEqual(property.key(), 1);
                                           XCTAssertEqual(property.value(), true);
                                       }
                                       ++wildcard_called_count;
                                   });

    property.set_value(true);

    XCTAssertTrue(will_change_called);
    XCTAssertTrue(did_change_called);
    XCTAssertEqual(wildcard_called_count, 2);
}

- (void)test_dispatcher
{
    test_class test_object;
    yas::observer<yas::property<int, test_key>> observer;

    int receive_value1 = 0;
    int receive_value2 = 0;

    observer.add_wild_card_handler(test_object.properties_subject,
                                   [&receive_value1, &receive_value2](const std::string &method, const auto &property) {
                                       if (method == yas::property_method::did_change) {
                                           switch (property.key()) {
                                               case test_key::property1:
                                                   receive_value1 = property.value();
                                                   break;
                                               case test_key::property2:
                                                   receive_value2 = property.value();
                                                   break;
                                           }
                                       }
                                   });

    test_object.property1.set_value(1);

    XCTAssertEqual(receive_value1, 1);
    XCTAssertEqual(receive_value2, 0);

    test_object.property2.set_value(2);

    XCTAssertEqual(receive_value1, 1);
    XCTAssertEqual(receive_value2, 2);
}

- (void)test_recursive_guard
{
    test_class test_object;
    yas::observer<yas::property<int, test_key>> observer;

    observer.add_handler(test_object.properties_subject, yas::property_method::did_change,
                         [&test_object](const std::string &method, const auto &property) {
                             switch (property.key()) {
                                 case test_key::property1:
                                     test_object.property2.set_value(property.value());
                                     break;
                                 case test_key::property2:
                                     test_object.property1.set_value(property.value());
                                     break;
                                 default:
                                     break;
                             }
                         });

    test_object.property1.set_value(10);

    XCTAssertEqual(test_object.property1.value(), 10);
    XCTAssertEqual(test_object.property2.value(), 10);

    test_object.property2.set_value(20);

    XCTAssertEqual(test_object.property1.value(), 20);
    XCTAssertEqual(test_object.property2.value(), 20);
}

- (void)test_equal
{
    yas::property<float> property1;
    yas::property<float> property2;

    XCTAssertTrue(property1 == property1);
    XCTAssertFalse(property1 == property2);
}

- (void)test_not_equal
{
    yas::property<float> property1;
    yas::property<float> property2;

    XCTAssertFalse(property1 != property1);
    XCTAssertTrue(property1 != property2);
}

- (void)test_equal_to_value_true
{
    float value = 3.0f;

    yas::property<float, int> property1{1, value};
    yas::property<float, int> property2{2, value};

    XCTAssertTrue(property1 == value);
    XCTAssertTrue(value == property1);
}

- (void)test_equal_to_value_false
{
    float value1 = 3.0f;
    float value2 = 5.0f;

    yas::property<float, int> property1{1, value1};
    yas::property<float, int> property2{2, value2};

    XCTAssertFalse(property1 == value2);
    XCTAssertFalse(value1 == property2);
}

- (void)test_not_equal_to_value_true
{
    float value1 = 3.0f;
    float value2 = 5.0f;

    yas::property<float, int> property1{1, value1};
    yas::property<float, int> property2{2, value2};

    XCTAssertTrue(property1 != value2);
    XCTAssertTrue(value1 != property2);
}

- (void)test_not_equal_to_value_false
{
    float value = 3.0f;

    yas::property<float, int> property1{1, value};
    yas::property<float, int> property2{2, value};

    XCTAssertFalse(property1 != value);
    XCTAssertFalse(value != property1);
}

@end
