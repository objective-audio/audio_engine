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

    if (auto objc_container = yas::objc_container::create(objc_object, yas::weak)) {
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

    if (auto objc_container = yas::objc_container::create(objc_object, yas::strong)) {
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

    if (auto objc_container = yas::objc_container::create()) {
        XCTAssertNil(objc_container->retained_object());
        XCTAssertNil(objc_container->autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);

        objc_container->set_object(objc_object);

        id retained_object = objc_container->retained_object();

        XCTAssertNotNil(retained_object);
        XCTAssertEqual([objc_object retainCount], 2);

        [objc_object release];
        retained_object = nil;

        XCTAssertEqual([objc_object retainCount], 1);

        @autoreleasepool
        {
            id autoreleased_object = objc_container->autoreleased_object();

            XCTAssertNotNil(autoreleased_object);
            XCTAssertEqual([objc_object retainCount], 2);
        }

        XCTAssertEqual([objc_object retainCount], 1);

        objc_container->set_object(nil);

        XCTAssertNil(objc_container->retained_object());
        XCTAssertNil(objc_container->autoreleased_object());
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

    if (auto objc_container = yas::objc_container::create(nil, yas::strong)) {
        XCTAssertNil(objc_container->retained_object());
        XCTAssertNil(objc_container->autoreleased_object());
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);

        objc_container->set_object(objc_object);

        XCTAssertEqual([objc_object retainCount], 2);

        id retained_object = objc_container->retained_object();

        XCTAssertNotNil(retained_object);
        XCTAssertEqual([objc_object retainCount], 3);

        [objc_object release];
        retained_object = nil;

        XCTAssertEqual([objc_object retainCount], 2);

        @autoreleasepool
        {
            id autoreleased_object = objc_container->autoreleased_object();

            XCTAssertNotNil(autoreleased_object);
            XCTAssertEqual([objc_object retainCount], 3);
        }

        XCTAssertEqual([objc_object retainCount], 2);

        objc_container->set_object(nil);

        XCTAssertNil(objc_container->retained_object());
        XCTAssertNil(objc_container->autoreleased_object());
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
        yas::objc_container objc_container1(objc_object, yas::strong);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc_container objc_container2(objc_object, yas::strong);

        XCTAssertEqual([objc_object retainCount], 3);

        objc_container1 = objc_container2;

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
        yas::objc_container objc_container1(objc_object, yas::strong);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc_container objc_container2(objc_object, yas::weak);

        XCTAssertEqual([objc_object retainCount], 2);

        objc_container1 = objc_container2;

        XCTAssertEqual([objc_object retainCount], 1);
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
        yas::objc_container objc_container1(objc_object, yas::weak);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc_container objc_container2(objc_object, yas::strong);

        XCTAssertEqual([objc_object retainCount], 2);

        objc_container1 = objc_container2;

        XCTAssertEqual([objc_object retainCount], 3);
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
        yas::objc_container objc_container1(objc_object, yas::weak);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc_container objc_container2(objc_object, yas::weak);

        XCTAssertEqual([objc_object retainCount], 1);

        objc_container1 = objc_container2;

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
        yas::objc_container objc_container1(objc_object, yas::strong);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc_container objc_container2(objc_container1);

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
        yas::objc_container objc_container1(objc_object, yas::weak);

        XCTAssertEqual([objc_object retainCount], 1);

        yas::objc_container objc_container2(objc_container1);

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
        yas::objc_container objc_container1(objc_object1, yas::strong);
        yas::objc_container objc_container2(objc_object2, yas::strong);

        XCTAssertEqual([objc_object1 retainCount], 2);
        XCTAssertEqual([objc_object2 retainCount], 2);

        objc_container1 = objc_container2;

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
        yas::objc_container objc_container1(objc_object, yas::strong);
        yas::objc_container objc_container2;

        XCTAssertEqual([objc_object retainCount], 2);

        objc_container2 = std::move(objc_container1);

        XCTAssertEqual([objc_object retainCount], 2);

        XCTAssertNil(objc_container1.retained_object());

        id retainedObject = objc_container2.retained_object();
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
        yas::objc_container objc_container1(objc_object, yas::strong);

        XCTAssertEqual([objc_object retainCount], 2);

        yas::objc_container objc_container2(std::move(objc_container1));

        XCTAssertEqual([objc_object retainCount], 2);

        XCTAssertNil(objc_container1.retained_object());

        id retainedObject = objc_container2.retained_object();
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
        yas::objc_container objc_container(nil, yas::strong);

        XCTAssertEqual([objc_object retainCount], 1);

        objc_container = objc_object;

        XCTAssertEqual([objc_object retainCount], 2);

        id retainedObject = objc_container.retained_object();
        XCTAssertNotNil(retainedObject);
        [retainedObject release];
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

@end
