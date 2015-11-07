//
//  yas_operation_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_operation_tests : XCTestCase

@end

@implementation yas_operation_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_call_one_operation
{
    XCTestExpectation *exe_ex = [self expectationWithDescription:@"call execution"];

    yas::operation_queue queue;
    yas::operation operation([exe_ex](const yas::operation &ope) { [exe_ex fulfill]; });
    queue.add_operation(operation);

    [self waitForExpectationsWithTimeout:1.0 handler:nil];
}

- (void)test_call_many_operation
{
    XCTestExpectation *exe_ex = [self expectationWithDescription:@"call execution"];

    std::atomic<int> count;
    count = 0;

    yas::operation_queue queue;

    yas::operation operation_1([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 0);
        ++count;
    });
    yas::operation operation_2([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 1);
        ++count;
    });
    yas::operation operation_3([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 2);
        ++count;
        [exe_ex fulfill];
    });

    queue.add_operation(operation_1);
    queue.add_operation(operation_2);
    queue.add_operation(operation_3);

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertEqual(count.load(), 3);
}

- (void)test_suspend
{
    XCTestExpectation *exe_ex = [self expectationWithDescription:@"call execution"];

    yas::operation_queue queue;

    queue.suspend();

    bool called = false;

    yas::operation operation([&called, exe_ex](const yas::operation &ope) {
        called = true;
        [exe_ex fulfill];
    });

    queue.add_operation(operation);

    [NSThread sleepForTimeInterval:0.1];

    XCTAssertFalse(called);

    queue.resume();

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertTrue(called);
}

- (void)test_insert_to_top
{
    XCTestExpectation *exe_ex = [self expectationWithDescription:@"call execution"];

    std::atomic<int> count;
    count = 0;

    yas::operation_queue queue;

    queue.suspend();

    yas::operation operation_1([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 0);
        ++count;
    });
    yas::operation operation_2([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 1);
        ++count;
    });
    yas::operation operation_3([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 2);
        ++count;
        [exe_ex fulfill];
    });

    queue.add_operation(operation_3);
    queue.insert_operation_to_top(operation_2);
    queue.insert_operation_to_top(operation_1);

    queue.resume();

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertEqual(count.load(), 3);
}

- (void)test_cancel
{
    yas::operation_queue queue;

    queue.suspend();

    bool called = false;

    yas::operation operation([self, &called](const yas::operation &op) { called = true; });

    queue.add_operation(operation);

    operation.cancel();

    queue.resume();

    [NSThread sleepForTimeInterval:0.1];

    XCTAssertFalse(called);
}

- (void)test_null_created
{
    yas::operation_queue queue{nullptr};
    yas::operation operation{nullptr};

    XCTAssertFalse(queue);
    XCTAssertFalse(operation);
}

- (void)test_priority
{
    XCTestExpectation *exe_ex = [self expectationWithDescription:@"call execution"];

    std::atomic<int> count;
    count = 0;

    yas::operation_queue queue{3};

    queue.suspend();

    yas::operation operation_1a([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 0);
        ++count;
    });
    yas::operation operation_1b([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 1);
        ++count;
    });
    yas::operation operation_2a([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 2);
        ++count;
    });
    yas::operation operation_2b([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 3);
        ++count;
    });
    yas::operation operation_3a([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 4);
        ++count;
    });
    yas::operation operation_3b([self, &count, exe_ex](const yas::operation &op) {
        XCTAssertEqual(count.load(), 5);
        ++count;
        [exe_ex fulfill];
    });

    queue.add_operation(operation_3a, 2);
    queue.add_operation(operation_2a, 1);
    queue.add_operation(operation_1a, 0);
    queue.add_operation(operation_3b, 2);
    queue.add_operation(operation_2b, 1);
    queue.add_operation(operation_1b, 0);

    queue.resume();

    [self waitForExpectationsWithTimeout:1.0 handler:nil];

    XCTAssertEqual(count.load(), 6);
}

@end
