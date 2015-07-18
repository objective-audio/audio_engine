//
//  yas_cf_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "yas_cf_utils.h"

@interface yas_cf_tests : XCTestCase

@end

@implementation yas_cf_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testRetaining
{
    CFMutableArrayRef _property_array = nullptr;
    CFMutableArrayRef array = CFArrayCreateMutable(nullptr, 1, nullptr);

    XCTAssertEqual(CFGetRetainCount(array), 1);

    yas::set_cf_property(_property_array, array);

    XCTAssertEqual(_property_array, array);
    XCTAssertEqual(CFGetRetainCount(array), 2);

    CFRelease(array);

    XCTAssertEqual(CFGetRetainCount(array), 1);

    @autoreleasepool
    {
        CFMutableArrayRef array2 = yas::get_cf_property(_property_array);

        XCTAssertEqual(_property_array, array2);
        XCTAssertEqual(CFGetRetainCount(array), 2);
    }

    XCTAssertEqual(CFGetRetainCount(array), 1);

    CFRelease(array);
}

- (void)testStringToCFString
{
    std::string string("test_string");

    CFStringRef cf_string = yas::to_cf_object(string);

    CFComparisonResult result = CFStringCompare(cf_string, CFSTR("test_string"), kNilOptions);

    XCTAssertEqual(result, kCFCompareEqualTo);
}

- (void)testCFStringToString
{
    CFStringRef cf_string = CFSTR("test_cf_string");

    std::string string = yas::to_string(cf_string);

    XCTAssertTrue(string == std::string("test_cf_string"));

    CFRelease(cf_string);
}

- (void)testFloat32ToCFNumber
{
    Float32 value = 1.5;

    CFNumberRef cf_number = yas::to_cf_object(value);

    XCTAssertEqual(CFNumberCompare(cf_number, (CFNumberRef)(@1.5), nullptr), kCFCompareEqualTo);
}

- (void)testFloat64ToCFNumber
{
    Float64 value = 2.6;

    CFNumberRef cf_number = yas::to_cf_object(value);

    XCTAssertEqual(CFNumberCompare(cf_number, (CFNumberRef)(@2.6), nullptr), kCFCompareEqualTo);
}

- (void)testSInt32ToCFNumber
{
    SInt32 value = 3;

    CFNumberRef cf_number = yas::to_cf_object(value);

    XCTAssertEqual(CFNumberCompare(cf_number, (CFNumberRef)(@3), nullptr), kCFCompareEqualTo);
}

- (void)testSInt16ToCFNumber
{
    SInt16 value = 123;

    CFNumberRef cf_number = yas::to_cf_object(value);

    XCTAssertEqual(CFNumberCompare(cf_number, (CFNumberRef)(@123), nullptr), kCFCompareEqualTo);
}

@end
