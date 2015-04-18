//
//  YASAudioPointerTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTypes.h"

@interface YASAudioPointerTests : XCTestCase

@end

@implementation YASAudioPointerTests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testAudioPointer
{
    Float32 float32Value = 1.0;
    Float64 float64Value = 2.0;
    SInt16 int16Value = 3;
    SInt32 int32Value = 4;
    SInt8 int8Value = 5;
    UInt8 uint8Value = 6;

    YASAudioMutablePointer f32Pointer = {&float32Value};
    YASAudioMutablePointer f64Pointer = {&float64Value};
    YASAudioMutablePointer i16Pointer = {&int16Value};
    YASAudioMutablePointer i32Pointer = {&int32Value};
    YASAudioMutablePointer i8Pointer = {&int8Value};
    YASAudioMutablePointer u8Pointer = {&uint8Value};

    XCTAssertEqual(float32Value, *f32Pointer.f32);
    XCTAssertEqual(float64Value, *f64Pointer.f64);
    XCTAssertEqual(int16Value, *i16Pointer.i16);
    XCTAssertEqual(int32Value, *i32Pointer.i32);
    XCTAssertEqual(int8Value, *i8Pointer.i8);
    XCTAssertEqual(uint8Value, *u8Pointer.u8);
}

- (void)testAudioConstPointer
{
    Float32 float32Value = 1.0;
    Float64 float64Value = 2.0;
    SInt16 int16Value = 3;
    SInt32 int32Value = 4;
    SInt8 int8Value = 5;
    UInt8 uint8Value = 6;

    YASAudioConstPointer f32Pointer = {&float32Value};
    YASAudioConstPointer f64Pointer = {&float64Value};
    YASAudioConstPointer i16Pointer = {&int16Value};
    YASAudioConstPointer i32Pointer = {&int32Value};
    YASAudioConstPointer i8Pointer = {&int8Value};
    YASAudioConstPointer u8Pointer = {&uint8Value};

    XCTAssertEqual(float32Value, *f32Pointer.f32);
    XCTAssertEqual(float64Value, *f64Pointer.f64);
    XCTAssertEqual(int16Value, *i16Pointer.i16);
    XCTAssertEqual(int32Value, *i32Pointer.i32);
    XCTAssertEqual(int8Value, *i8Pointer.i8);
    XCTAssertEqual(uint8Value, *u8Pointer.u8);
}

@end
