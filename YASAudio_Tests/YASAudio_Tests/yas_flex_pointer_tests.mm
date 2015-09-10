//
//  yas_flex_pointer_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_flex_pointer_tests : XCTestCase

@end

@implementation yas_flex_pointer_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_flex_pointer
{
    Float32 float32Value = 1.0;
    Float64 float64Value = 2.0;
    SInt16 int16Value = 3;
    SInt32 int32Value = 4;
    SInt8 int8Value = 5;
    UInt8 uint8Value = 6;

    yas::flex_pointer f32_pointer{&float32Value};
    yas::flex_pointer f64_pointer{&float64Value};
    yas::flex_pointer i16_pointer{&int16Value};
    yas::flex_pointer i32_pointer{&int32Value};
    yas::flex_pointer i8_pointer{&int8Value};
    yas::flex_pointer u8_pointer{&uint8Value};

    XCTAssertEqual(float32Value, *f32_pointer.f32);
    XCTAssertEqual(float64Value, *f64_pointer.f64);
    XCTAssertEqual(int16Value, *i16_pointer.i16);
    XCTAssertEqual(int32Value, *i32_pointer.i32);
    XCTAssertEqual(int8Value, *i8_pointer.i8);
    XCTAssertEqual(uint8Value, *u8_pointer.u8);
}

- (void)testAudioConstPointer
{
    Float32 float32Value = 1.0;
    Float64 float64Value = 2.0;
    SInt16 int16Value = 3;
    SInt32 int32Value = 4;
    SInt8 int8Value = 5;
    UInt8 uint8Value = 6;

    yas::flex_pointer f32_pointer{&float32Value};
    yas::flex_pointer f64_pointer{&float64Value};
    yas::flex_pointer i16_pointer{&int16Value};
    yas::flex_pointer i32_pointer{&int32Value};
    yas::flex_pointer i8_pointer{&int8Value};
    yas::flex_pointer u8_pointer{&uint8Value};

    XCTAssertEqual(float32Value, *f32_pointer.f32);
    XCTAssertEqual(float64Value, *f64_pointer.f64);
    XCTAssertEqual(int16Value, *i16_pointer.i16);
    XCTAssertEqual(int32Value, *i32_pointer.i32);
    XCTAssertEqual(int8Value, *i8_pointer.i8);
    XCTAssertEqual(uint8Value, *u8_pointer.u8);
}

@end
