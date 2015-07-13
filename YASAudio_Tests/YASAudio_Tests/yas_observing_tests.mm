//
//  yas_observing_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_observing.h"

@interface yas_observing_tests : XCTestCase

@end

@implementation yas_observing_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testSingle
{
    int sender = 100;

    const std::string key("key");
    const std::string key2("key2");

    yas::subject<std::string, int> subject;
    auto observer = yas::make_observer(subject);

    bool called = false;

    observer->add_handler(subject, key, [&called](const auto &key, const auto &sender) {
        if (key == "key" && sender == 100) {
            called = true;
        }
    });

    subject.notify(key, sender);

    XCTAssertTrue(called);

    called = false;

    subject.notify(key2, sender);

    XCTAssertFalse(called);

    observer->remove_handler(subject, key);
    subject.notify(key, sender);

    XCTAssertFalse(called);

    observer->add_handler(subject, key, [&called](const auto &key, const auto &sender) {
        if (key == "key" && sender == 100) {
            called = true;
        }
    });
    observer = nullptr;
    subject.notify(key, sender);

    XCTAssertFalse(called);
}

- (void)testMultiKeys
{
    int sender = 100;

    const std::string key1("key1");
    const std::string key2("key2");
    const std::string key3("key3");

    yas::subject<std::string, int> subject;
    auto observer = yas::make_observer(subject);

    bool called1 = false;
    bool called2 = false;

    observer->add_handler(subject, key1, [&called1](const auto &key, const auto &sender) {
        if (key == "key1" && sender == 100) {
            called1 = true;
        }
    });
    observer->add_handler(subject, key2, [&called2](const auto &key, const auto &sender) {
        if (key == "key2" && sender == 100) {
            called2 = true;
        }
    });

    subject.notify(key1, sender);

    XCTAssertTrue(called1);
    XCTAssertFalse(called2);

    called1 = false;
    called2 = false;

    subject.notify(key2, sender);

    XCTAssertFalse(called1);
    XCTAssertTrue(called2);

    called1 = false;
    called2 = false;

    subject.notify(key3, sender);

    XCTAssertFalse(called1);
    XCTAssertFalse(called2);
}

- (void)testMultiObservers
{
    int sender = 100;

    const std::string key("key");

    yas::subject<std::string, int> subject;
    auto observer1 = yas::make_observer(subject);
    auto observer2 = yas::make_observer(subject);

    bool called1 = false;
    bool called2 = false;

    observer1->add_handler(subject, key, [&called1](const auto &key, const auto &sender) {
        if (key == "key" && sender == 100) {
            called1 = true;
        }
    });
    observer2->add_handler(subject, key, [&called2](const auto &key, const auto &sender) {
        if (key == "key" && sender == 100) {
            called2 = true;
        }
    });

    subject.notify(key, sender);

    XCTAssertTrue(called1);
    XCTAssertTrue(called2);
}

- (void)testMultiSubjects
{
    int sender = 100;

    const std::string key("key");

    yas::subject<std::string, int> subject1;
    yas::subject<std::string, int> subject2;
    auto observer = yas::make_observer(subject1);

    bool called1 = false;
    bool called2 = false;

    observer->add_handler(subject1, key, [&called1](const auto &key, const auto &sender) {
        if (key == "key" && sender == 100) {
            called1 = true;
        }
    });

    observer->add_handler(subject2, key, [&called2](const auto &key, const auto &sender) {
        if (key == "key" && sender == 100) {
            called2 = true;
        }
    });

    subject1.notify(key, sender);

    XCTAssertTrue(called1);
    XCTAssertFalse(called2);

    called1 = false;
    called2 = false;

    subject2.notify(key, sender);

    XCTAssertFalse(called1);
    XCTAssertTrue(called2);
}

- (void)testWildCard
{
    yas::subject<int, std::string> subject;
    auto observer = yas::make_observer(subject);

    int key00 = 30;
    int key10 = 10;
    int key20 = 20;
    std::string sender_00 = "sender_00";
    std::string sender_10 = "sender_10";
    std::string sender_20 = "sender_20";
    std::string receive_00 = "";
    std::string receive_10 = "";
    std::string receive_20 = "";

    observer->add_wild_card_handler(subject, [&receive_10, &receive_20](const auto &key, const auto &sender) {
        if (key == 10) {
            receive_10 = sender;
        } else if (key == 20) {
            receive_20 = sender;
        }
    });

    subject.notify(key00, sender_00);

    XCTAssertNotEqual(receive_00, sender_00);
    XCTAssertNotEqual(receive_10, sender_10);
    XCTAssertNotEqual(receive_20, sender_20);

    subject.notify(key10, sender_10);

    XCTAssertEqual(receive_10, sender_10);
    XCTAssertNotEqual(receive_20, sender_20);

    subject.notify(key20, sender_20);

    XCTAssertEqual(receive_20, sender_20);
}

- (void)testSubjectDispatcher
{
    struct test_class {
        enum class method : UInt32 {
            property1,
            property2,
        };

        yas::subject<method, std::string> property1;
        yas::subject<method, std::string> property2;

        yas::observer<method, std::string>::shared_ptr dispatcher;
        yas::subject<method, std::string> properties_subject;

        test_class() : dispatcher(yas::make_subject_dispatcher(properties_subject, {&property1, &property2}))
        {
        }

        ~test_class()
        {
        }
    };

    test_class test_object;

    std::string value1 = "";
    std::string value2 = "";

    auto observer = yas::make_observer(test_object.properties_subject);
    observer->add_wild_card_handler(test_object.properties_subject,
                                    [&value1, &value2](const auto &method, const auto &value) {
                                        switch (method) {
                                            case test_class::method::property1:
                                                value1 = value;
                                                break;
                                            case test_class::method::property2:
                                                value2 = value;
                                                break;
                                        }
                                    });

    test_object.property1.notify(test_class::method::property1, "property1");
    test_object.property2.notify(test_class::method::property2, "property2");

    XCTAssertEqual(value1, "property1");
    XCTAssertEqual(value2, "property2");
}

@end
