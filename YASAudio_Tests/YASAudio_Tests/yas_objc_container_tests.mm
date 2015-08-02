//
//  yas_objc_container_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_objc_container.h"

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

- (void)testUnretainObjcObjectOnWeakContainer
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual(_objc_object_count, 1);
    XCTAssertEqual([objc_object retainCount], 1);

    if (auto objc_weak_container = yas::objc_weak_container::create(objc_object)) {
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testRetainObjcObjectOnStrongContainer
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual(_objc_object_count, 1);
    XCTAssertEqual([objc_object retainCount], 1);

    if (auto objc_strong_container = yas::objc_strong_container::create(objc_object)) {
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 2);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testSetObjcObjectOnWeakContainer
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    if (auto objc_weak_container = yas::objc_weak_container::create()) {
        XCTAssertNil(objc_weak_container->retained_object());
        XCTAssertNil(objc_weak_container->autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);

        objc_weak_container->set_object(objc_object);

        id retained_object = objc_weak_container->retained_object();

        XCTAssertNotNil(retained_object);
        XCTAssertEqual([objc_object retainCount], 2);

        [objc_object release];
        retained_object = nil;

        XCTAssertEqual([objc_object retainCount], 1);

        @autoreleasepool
        {
            id autoreleased_object = objc_weak_container->autoreleased_object();

            XCTAssertNotNil(autoreleased_object);
            XCTAssertEqual([objc_object retainCount], 2);
        }

        XCTAssertEqual([objc_object retainCount], 1);

        objc_weak_container->set_object(nil);

        XCTAssertNil(objc_weak_container->retained_object());
        XCTAssertNil(objc_weak_container->autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testSetObjcObjectOnStrongContainer
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    if (auto objc_strong_container = yas::objc_strong_container::create(nil)) {
        XCTAssertNil(objc_strong_container->retained_object());
        XCTAssertNil(objc_strong_container->autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);

        objc_strong_container->set_object(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        id retained_object = objc_strong_container->retained_object();

        XCTAssertNotNil(retained_object);
        XCTAssertEqual([objc_object retainCount], 3);

        [objc_object release];
        retained_object = nil;

        XCTAssertEqual([objc_object retainCount], 2);

        @autoreleasepool
        {
            id autoreleased_object = objc_strong_container->autoreleased_object();

            XCTAssertNotNil(autoreleased_object);
            XCTAssertEqual([objc_object retainCount], 3);
        }

        XCTAssertEqual([objc_object retainCount], 2);

        objc_strong_container->set_object(nil);

        XCTAssertNil(objc_strong_container->retained_object());
        XCTAssertNil(objc_strong_container->autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

#pragma mark - copy

- (void)testCopyStrongToStrong
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc_strong_container objc_strong_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc_strong_container objc_strong_container2(objc_object);

        XCTAssertEqual([objc_object retainCount], 3);

        objc_strong_container1 = objc_strong_container2;

        XCTAssertEqual([objc_object retainCount], 3);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testCopyWeakToStrong
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc_strong_container objc_strong_container(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc_weak_container objc_weak_container(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        objc_strong_container = objc_weak_container;

        XCTAssertEqual([objc_object retainCount], 2);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testCopyStrongToWeak
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc_weak_container objc_weak_container(objc_object);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc_strong_container objc_strong_container(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        objc_weak_container = objc_strong_container;

        XCTAssertEqual([objc_object retainCount], 2);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testCopyWeakToWeak
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc_weak_container objc_weak_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc_weak_container objc_weak_container2(objc_object);

        XCTAssertEqual([objc_object retainCount], 1);

        objc_weak_container1 = objc_weak_container2;

        XCTAssertEqual([objc_object retainCount], 1);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testCopyConstructorStrong
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc_strong_container objc_strong_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc_strong_container objc_strong_container2(objc_strong_container1);

        XCTAssertEqual([objc_object retainCount], 3);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testCopyConstructorWeak
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual([objc_object retainCount], 1);

    {
        yas::objc_weak_container objc_weak_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc_weak_container objc_weak_container2(objc_weak_container1);

        XCTAssertEqual([objc_object retainCount], 1);
    }

    XCTAssertEqual([objc_object retainCount], 1);

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testCopyDifferentObjcObjects
{
    YASObjCContainerTest *objc_object1 = [[YASObjCContainerTest alloc] init];
    YASObjCContainerTest *objc_object2 = [[YASObjCContainerTest alloc] init];

    {
        yas::objc_strong_container objc_strong_container1(objc_object1);
        yas::objc_strong_container objc_strong_container2(objc_object2);

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

- (void)testMove
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    {
        yas::objc_strong_container objc_strong_container1(objc_object);
        yas::objc_strong_container objc_strong_container2;

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

- (void)testMoveConstructor
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    {
        yas::objc_strong_container objc_strong_container1(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc_strong_container objc_strong_container2(std::move(objc_strong_container1));

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

- (void)testDirectSet
{
    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    {
        yas::objc_strong_container objc_strong_container(nil);

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
