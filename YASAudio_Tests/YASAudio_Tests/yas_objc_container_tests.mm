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
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testUnretainedObjcObject
{
    _objc_object_count = 0;

    YASObjCContainerTest *objc_object = [[YASObjCContainerTest alloc] init];

    XCTAssertEqual(_objc_object_count, 1);
    XCTAssertEqual([objc_object retainCount], 1);

    if (auto objc_container = yas::objc_container::create(objc_object)) {
        XCTAssertEqual(_objc_object_count, 1);
        XCTAssertEqual([objc_object retainCount], 1);
    }

    [objc_object release];
    objc_object = nil;

    XCTAssertEqual(_objc_object_count, 0);
}

- (void)testSetObjcObject
{
    _objc_object_count = 0;

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
}

@end
