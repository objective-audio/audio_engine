//
//  yas_flex_pointer_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_flex_pointer_tests : XCTestCase

@end

@implementation yas_flex_pointer_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_flex_ptr {
    Float32 float32_value = 1.0f;
    Float64 float64_value = 2.0;
    SInt32 int32_value = 3;
    UInt32 uint32_value = 4;
    SInt16 int16_value = 5;
    UInt16 uint16_value = 6;
    SInt8 int8_value = 7;
    UInt8 uint8_value = 8;

    // create

    yas::flex_ptr f32_ptr(&float32_value);
    yas::flex_ptr f64_ptr(&float64_value);
    yas::flex_ptr i32_ptr(&int32_value);
    yas::flex_ptr u32_ptr(&uint32_value);
    yas::flex_ptr i16_ptr(&int16_value);
    yas::flex_ptr u16_ptr(&uint16_value);
    yas::flex_ptr i8_ptr(&int8_value);
    yas::flex_ptr u8_ptr(&uint8_value);

    XCTAssertEqual(*f32_ptr.f32, 1.0f);
    XCTAssertEqual(*f64_ptr.f64, 2.0);
    XCTAssertEqual(*i32_ptr.i32, 3);
    XCTAssertEqual(*u32_ptr.u32, 4);
    XCTAssertEqual(*i16_ptr.i16, 5);
    XCTAssertEqual(*u16_ptr.u16, 6);
    XCTAssertEqual(*i8_ptr.i8, 7);
    XCTAssertEqual(*u8_ptr.u8, 8);

    // replace

    *f32_ptr.f32 = 10.0f;
    *f64_ptr.f64 = 11.0;
    *i32_ptr.i32 = 12;
    *u32_ptr.u32 = 13;
    *i16_ptr.i16 = 14;
    *u16_ptr.u16 = 15;
    *i8_ptr.i8 = 16;
    *u8_ptr.u8 = 17;

    XCTAssertEqual(*f32_ptr.f32, 10.0f);
    XCTAssertEqual(*f64_ptr.f64, 11.0);
    XCTAssertEqual(*i32_ptr.i32, 12);
    XCTAssertEqual(*u32_ptr.u32, 13);
    XCTAssertEqual(*i16_ptr.i16, 14);
    XCTAssertEqual(*u16_ptr.u16, 15);
    XCTAssertEqual(*i8_ptr.i8, 16);
    XCTAssertEqual(*u8_ptr.u8, 17);
}

- (void)test_copy {
    Float32 value = 20.0f;

    yas::flex_ptr flex_ptr(&value);
    const yas::flex_ptr const_flex_ptr = flex_ptr;

    XCTAssertEqual(*flex_ptr.f32, 20.0f);
    XCTAssertEqual(*const_flex_ptr.f32, 20.0f);

    *flex_ptr.f32 = -30.0f;

    XCTAssertEqual(*flex_ptr.f32, -30.0f);
    XCTAssertEqual(*const_flex_ptr.f32, -30.0f);
}

@end
