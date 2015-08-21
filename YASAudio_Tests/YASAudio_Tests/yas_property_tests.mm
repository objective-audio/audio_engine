//
//  yas_property_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_property.h"
#import "YASMacros.h"

enum class test_key {
    property1,
    property2,
};

struct test_class {
    yas::property<test_key, int>::shared_ptr property1;
    yas::property<test_key, int>::shared_ptr property2;

    yas::property<test_key, int>::dispatched_subject properties_subject;
    yas::property<test_key, int>::dispatcher_ptr dispatcher;

    test_class()
        : property1(yas::make_property(test_key::property1, 1)),
          property2(yas::make_property(test_key::property2, 2)),
          dispatcher(yas::make_subject_dispatcher(properties_subject, {&property1->subject(), &property2->subject()}))
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

- (void)testCreateProperty
{
    int key = 1;
    float value1 = 1.5;

    auto float_property = yas::property<int, float>::create(key, value1);

    XCTAssertEqual(key, float_property->key());
    XCTAssertEqual(float_property->value(), value1);

    float value2 = 3.2;

    float_property->set_value(value2);

    XCTAssertEqual(float_property->value(), value2);
    XCTAssertNotEqual(float_property->value(), value1);
}

- (void)testMakeProperty
{
    int key = 1;
    float value1 = 1.5;

    auto float_property = yas::make_property(key, value1);

    XCTAssertEqual(key, float_property->key());
    XCTAssertEqual(float_property->value(), value1);
}

- (void)testChangeValue
{
    auto property = yas::property<int, int>::create(1, 2);

    XCTAssertEqual(property->value(), 2);

    property->set_value(3);

    XCTAssertNotEqual(property->value(), 2);
    XCTAssertEqual(property->value(), 3);
}

- (void)testObserveValue
{
    auto property = yas::property<int, bool>::create(1, false);
    yas::observer<yas::property_method, yas::property<int, bool>::shared_ptr>::shared_ptr observer =
        yas::make_observer(property->subject());

    bool will_change_called = false;

    observer->add_handler(property->subject(), yas::property_method::will_change,
                          [self, &will_change_called](const auto &method, const auto &sender) {
                              XCTAssertEqual(method, yas::property_method::will_change);
                              XCTAssertEqual(sender->key(), 1);
                              XCTAssertEqual(sender->value(), false);
                              will_change_called = true;
                          });

    bool did_change_called = false;

    observer->add_handler(property->subject(), yas::property_method::did_change,
                          [self, &did_change_called](const auto &method, const auto &sender) {
                              XCTAssertEqual(method, yas::property_method::did_change);
                              XCTAssertEqual(sender->key(), 1);
                              XCTAssertEqual(sender->value(), true);
                              did_change_called = true;
                          });

    int wildcard_called_count = 0;

    observer->add_wild_card_handler(property->subject(),
                                    [self, &wildcard_called_count](const auto &method, const auto &sender) {
                                        switch (method) {
                                            case yas::property_method::will_change:
                                                XCTAssertEqual(sender->key(), 1);
                                                XCTAssertEqual(sender->value(), false);
                                                break;
                                            case yas::property_method::did_change:
                                                XCTAssertEqual(sender->key(), 1);
                                                XCTAssertEqual(sender->value(), true);
                                                break;
                                        }
                                        ++wildcard_called_count;
                                    });

    property->set_value(true);

    XCTAssertTrue(will_change_called);
    XCTAssertTrue(did_change_called);
    XCTAssertEqual(wildcard_called_count, 2);
}

- (void)testDispatcher
{
    test_class test_object;
    auto observer = yas::make_observer(test_object.properties_subject);

    int receive_value1 = 0;
    int receive_value2 = 0;

    observer->add_wild_card_handler(test_object.properties_subject,
                                    [&receive_value1, &receive_value2](const auto &method, const auto &sender) {
                                        if (method == yas::property_method::did_change) {
                                            switch (sender->key()) {
                                                case test_key::property1:
                                                    receive_value1 = sender->value();
                                                    break;
                                                case test_key::property2:
                                                    receive_value2 = sender->value();
                                                    break;
                                            }
                                        }
                                    });

    test_object.property1->set_value(1);

    XCTAssertEqual(receive_value1, 1);
    XCTAssertEqual(receive_value2, 0);

    test_object.property2->set_value(2);

    XCTAssertEqual(receive_value1, 1);
    XCTAssertEqual(receive_value2, 2);
}

- (void)testRecursiveGuard
{
    test_class test_object;
    auto observer = yas::make_observer(test_object.properties_subject);

    observer->add_handler(test_object.properties_subject, yas::property_method::did_change,
                          [&test_object](const auto &key, const auto &sender) {
                              switch (sender->key()) {
                                  case test_key::property1:
                                      test_object.property2->set_value(sender->value());
                                      break;
                                  case test_key::property2:
                                      test_object.property1->set_value(sender->value());
                                      break;
                                  default:
                                      break;
                              }
                          });

    test_object.property1->set_value(10);

    XCTAssertEqual(test_object.property1->value(), 10);
    XCTAssertEqual(test_object.property2->value(), 10);

    test_object.property2->set_value(20);

    XCTAssertEqual(test_object.property1->value(), 20);
    XCTAssertEqual(test_object.property2->value(), 20);
}

@end
