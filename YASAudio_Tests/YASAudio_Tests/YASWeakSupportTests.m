//
//  YASWeakSupportTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASWeakSupport.h"
#import "YASMacros.h"

@interface YASWeakSupportTests : XCTestCase

@end

@implementation YASWeakSupportTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testWeakSupport
{
    YASWeakProvider *provider = [[YASWeakProvider alloc] init];
    YASWeakContainer *container = YASRetainAndAutorelease([provider weakContainer]);

    XCTAssertNotNil(container);

    id retainedObject = [container retainedObject];
    XCTAssertEqualObjects(retainedObject, provider);
    YASRelease(retainedObject);
    retainedObject = nil;

    YASRelease(provider);
    provider = nil;

    retainedObject = [container retainedObject];
    XCTAssertNil(retainedObject);
    YASRelease(retainedObject);
    retainedObject = nil;

    container = nil;

    @autoreleasepool
    {
        provider = [[YASWeakProvider alloc] init];
        container = YASRetain([provider weakContainer]);

        YASWeakProvider *autoreleasingProvider = [container autoreleasingObject];
        XCTAssertEqualObjects(autoreleasingProvider, provider);

        YASRelease(provider);
        provider = nil;

        provider = [container retainedObject];
        XCTAssertNotNil(provider);
        YASRelease(provider);
        provider = nil;
    }

    retainedObject = [container retainedObject];
    XCTAssertNil(retainedObject);
    YASRelease(retainedObject);
    retainedObject = nil;

    YASRelease(container);
}

- (void)testUnwrappedArray
{
    YASWeakProvider *provider0 = [[YASWeakProvider alloc] init];
    YASWeakProvider *provider1 = [[YASWeakProvider alloc] init];

    YASWeakContainer *container0 = [provider0 weakContainer];
    YASWeakContainer *container1 = [provider1 weakContainer];

    NSArray *containers = @[ container0, container1 ];

    NSArray *unwrappedArray = nil;

    @autoreleasepool
    {
        unwrappedArray = [containers yas_unwrappedArrayFromWeakContainers];

        XCTAssertEqual(unwrappedArray.count, 2);

        YASWeakProvider *unwrappedProvider0 = unwrappedArray[0];
        YASWeakProvider *unwrappedProvider1 = unwrappedArray[1];

        XCTAssertEqualObjects(unwrappedProvider0, provider0);
        XCTAssertEqualObjects(unwrappedProvider1, provider1);

        unwrappedArray = nil;
    }

    YASRelease(provider0);
    provider0 = nil;
    YASRelease(provider1);
    provider1 = nil;

    unwrappedArray = [containers yas_unwrappedArrayFromWeakContainers];

    XCTAssertEqual(unwrappedArray.count, 0);
}

- (void)testUnwrappedDictionary
{
    YASWeakProvider *provider0 = [[YASWeakProvider alloc] init];
    YASWeakProvider *provider1 = [[YASWeakProvider alloc] init];

    YASWeakContainer *container0 = [provider0 weakContainer];
    YASWeakContainer *container1 = [provider1 weakContainer];

    NSDictionary *containers = @{ @0 : container0, @1 : container1 };

    NSDictionary *unwrappedDictionary = nil;

    @autoreleasepool
    {
        unwrappedDictionary = [containers yas_unwrappedDictionaryFromWeakContainers];

        XCTAssertEqual(unwrappedDictionary.count, 2);

        YASWeakProvider *unwrappedProvider0 = unwrappedDictionary[@0];
        YASWeakProvider *unwrappedProvider1 = unwrappedDictionary[@1];

        XCTAssertEqualObjects(unwrappedProvider0, provider0);
        XCTAssertEqualObjects(unwrappedProvider1, provider1);

        unwrappedDictionary = nil;
    }

    YASRelease(provider0);
    provider0 = nil;
    YASRelease(provider1);
    provider1 = nil;

    unwrappedDictionary = [containers yas_unwrappedDictionaryFromWeakContainers];

    XCTAssertEqual(unwrappedDictionary.count, 0);
}

@end
