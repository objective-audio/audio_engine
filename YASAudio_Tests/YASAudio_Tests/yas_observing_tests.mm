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
    auto observer = yas::observer<std::string, int>::create();

    bool called = false;

    observer->add_handler(subject, key, [&called](const int &sender) {
        if (sender == 100) {
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

    observer->add_handler(subject, key, [&called](const int &sender) {
        if (sender == 100) {
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
    auto observer = yas::observer<std::string, int>::create();

    bool called1 = false;
    bool called2 = false;

    observer->add_handler(subject, key1, [&called1](const int &sender) {
        if (sender == 100) {
            called1 = true;
        }
    });
    observer->add_handler(subject, key2, [&called2](const int &sender) {
        if (sender == 100) {
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
    auto observer1 = yas::observer<std::string, int>::create();
    auto observer2 = yas::observer<std::string, int>::create();

    bool called1 = false;
    bool called2 = false;

    observer1->add_handler(subject, key, [&called1](const int &sender) {
        if (sender == 100) {
            called1 = true;
        }
    });
    observer2->add_handler(subject, key, [&called2](const int &sender) {
        if (sender == 100) {
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
    auto observer = yas::observer<std::string, int>::create();

    bool called1 = false;
    bool called2 = false;

    observer->add_handler(subject1, key, [&called1](const int &sender) {
        if (sender == 100) {
            called1 = true;
        }
    });

    observer->add_handler(subject2, key, [&called2](const int &sender) {
        if (sender == 100) {
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

@end
