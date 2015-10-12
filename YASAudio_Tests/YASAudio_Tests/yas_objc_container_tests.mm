//
//  yas_objc_container_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

static int _objc_object_count = 0;

@interface YASObjCContainerTest : NSObject

@end

@implementation YASObjCContainerTest

- (instancetype)init
{
    self = [super init];
    if (self) {
        _objc_object_count++;
    }
    return self;
}

- (void)dealloc
{
    _objc_object_count--;
    [super dealloc];
}

@end

@interface yas_objc_container_tests : XCTestCase

@end

@implementation yas_objc_container_tests

- (void)setUp
{
    [super setUp];

    _objc_object_count = 0;
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_retain_objc_object_on_strong_container
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual(_objc_object_count, 1);
    XCTAssertEqual([objc_object retainCount], 1);

    if (auto objc_strong_container = yas::objc::container<>(objc_object)) {
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 2);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_unretain_objc_object_on_weak_container
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual(_objc_object_count, 1);
    XCTAssertEqual([objc_object retainCount], 1);

    if (auto objc_weak_container = yas::objc::container<yas::objc::weak>(objc_object)) {
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_set_objc_object_on_weak_container
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    if (auto objc_weak_container = yas::objc::container<yas::objc::weak>(nil)) {
        XCTAssertNil(objc_weak_container.retained_object());
        XCTAssertNil(objc_weak_container.autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);

        objc_weak_container.set_object(objc_object);

        id retained_object = objc_weak_container.retained_object();

        XCTAssertNotNil(retained_object);
        XCTAssertEqual([objc_object retainCount], 2);

        [objc_object release];
        retained_object = nil;

        XCTAssertEqual([objc_object retainCount], 1);

        @autoreleasepool
        {
            id autoreleased_object = objc_weak_container.autoreleased_object();

            XCTAssertNotNil(autoreleased_object);
            XCTAssertEqual([objc_object retainCount], 2);
        }

        XCTAssertEqual([objc_object retainCount], 1);

        objc_weak_container.set_object(nil);

        XCTAssertNil(objc_weak_container.retained_object());
        XCTAssertNil(objc_weak_container.autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_set_objec_object_on_strong_container
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    if (auto objc_strong_container = yas::objc::container<>(nil)) {
        XCTAssertNil(objc_strong_container.retained_object());
        XCTAssertNil(objc_strong_container.autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);

        objc_strong_container.set_object(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        id retained_object = objc_strong_container.retained_object();

        XCTAssertNotNil(retained_object);
        XCTAssertEqual([objc_object retainCount], 3);

        [objc_object release];
        retained_object = nil;

        XCTAssertEqual([objc_object retainCount], 2);

        @autoreleasepool
        {
            id autoreleased_object = objc_strong_container.autoreleased_object();

            XCTAssertNotNil(autoreleased_object);
            XCTAssertEqual([objc_object retainCount], 3);
        }

        XCTAssertEqual([objc_object retainCount], 2);

        objc_strong_container.set_object(nil);

        XCTAssertNil(objc_strong_container.retained_object());
        XCTAssertNil(objc_strong_container.autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

#pragma mark - copy

- (void)test_copy_strong_to_strong
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc::container<> objc_strong_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc::container<> objc_strong_container2(objc_object);

        XCTAssertEqual([objc_object retainCount], 3);

        objc_strong_container1 = objc_strong_container2;

        XCTAssertEqual([objc_object retainCount], 3);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_copy_weak_to_strong
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc::container<> objc_strong_container(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc::container<yas::objc::weak> objc_weak_container(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        objc_strong_container = objc_weak_container.lock();

        XCTAssertEqual([objc_object retainCount], 2);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_copy_strong_to_weak
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc::container<yas::objc::weak> objc_weak_container(objc_object);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc::container<> objc_strong_container(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        objc_weak_container = yas::objc::container<yas::objc::weak>(objc_strong_container.object());

        XCTAssertEqual([objc_object retainCount], 2);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_copy_weak_to_weak
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc::container<yas::objc::weak> objc_weak_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc::container<yas::objc::weak> objc_weak_container2(objc_object);

        XCTAssertEqual([objc_object retainCount], 1);

        objc_weak_container1 = objc_weak_container2;

        XCTAssertEqual([objc_object retainCount], 1);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_copy_constructor_strong
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc::container<> objc_strong_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc::container<> objc_strong_container2(objc_strong_container1);

        XCTAssertEqual([objc_object retainCount], 3);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_copy_constructor_weak
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc::container<yas::objc::weak> objc_weak_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc::container<yas::objc::weak> objc_weak_container2(objc_weak_container1);

        XCTAssertEqual([objc_object retainCount], 1);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_copy_different_objc_objects
{
    YASObjCContainerTest *objc_object1 = [[YASObjCContainerTest alloc] init];
    YASObjCContainerTest *objc_object2 = [[YASObjCContainerTest alloc] init];

    {
        yas::objc::container<> objc_strong_container1(objc_object1);
        yas::objc::container<> objc_strong_container2(objc_object2);

        XCTAssertEqual([objc_object1 retainCount], 2);
        XCTAssertEqual([objc_object2 retainCount], 2);

        objc_strong_container1 = objc_strong_container2;

        XCTAssertEqual([objc_object1 retainCount], 1);
        XCTAssertEqual([objc_object2 retainCount], 3);
    }

    [objc_object1 release];
    objc_object1 = nil;
    [objc_object2 release];
    objc_object2 = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

#pragma mark - move

- (void)test_move
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    {
        yas::objc::container<> objc_strong_container1(objc_object);
        yas::objc::container<> objc_strong_container2;

        XCTAssertEqual([objc_object retainCount], 2);

        objc_strong_container2 = std::move(objc_strong_container1);

        XCTAssertEqual([objc_object retainCount], 2);

        XCTAssertNil(objc_strong_container1.retained_object());

        id retainedObject = objc_strong_container2.retained_object();
        XCTAssertNotNil(retainedObject);
        [retainedObject release];
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_move_constructor
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    {
        yas::objc::container<> objc_strong_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc::container<> objc_strong_container2(std::move(objc_strong_container1));

        XCTAssertEqual([objc_object retainCount], 2);

        XCTAssertNil(objc_strong_container1.retained_object());

        id retainedObject = objc_strong_container2.retained_object();
        XCTAssertNotNil(retainedObject);
        [retainedObject release];
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)test_direct_set
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    {
        yas::objc::container<> objc_strong_container;

        XCTAssertEqual([objc_object retainCount], 1);

        objc_strong_container = objc_object;

        XCTAssertEqual([objc_object retainCount], 2);

        id retainedObject = objc_strong_container.retained_object();
        XCTAssertNotNil(retainedObject);
        [retainedObject release];
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

@end
