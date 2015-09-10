//
//  YASAudioMathTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

@interface yas_audio_math_tests : XCTestCase

@end

@implementation yas_audio_math_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)test_two_pi
{
    XCTAssertEqual(2.0 * M_PI, yas::audio_math::two_pi);
}

- (void)test_decibel_from_linear_float64
{
    XCTAssertEqualWithAccuracy(yas::audio_math::decibel_from_linear((Float64)0.0), -HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::decibel_from_linear((Float64)1.0), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::decibel_from_linear((Float64)2.0), 6.0, 0.1);
    XCTAssertEqualWithAccuracy(yas::audio_math::decibel_from_linear((Float64)0.5), -6.0, 0.1);
}

- (void)test_decibel_from_linear_float32
{
    XCTAssertEqualWithAccuracy(yas::audio_math::decibel_from_linear((Float32)0.0f), -HUGE_VAL, 0.01f);
    XCTAssertEqualWithAccuracy(yas::audio_math::decibel_from_linear((Float32)1.0f), 0.0f, 0.01f);
    XCTAssertEqualWithAccuracy(yas::audio_math::decibel_from_linear((Float32)2.0f), 6.0f, 0.1f);
    XCTAssertEqualWithAccuracy(yas::audio_math::decibel_from_linear((Float32)0.5f), -6.0f, 0.1f);
}

- (void)test_linear_from_decibel_float64
{
    XCTAssertEqualWithAccuracy(yas::audio_math::linear_from_decibel((Float64)-HUGE_VAL), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::linear_from_decibel((Float64)0.0), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::linear_from_decibel((Float64)6.0), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::linear_from_decibel((Float64)-6.0), 0.5, 0.01);
}

- (void)test_linear_from_decibel_float32
{
    XCTAssertEqualWithAccuracy(yas::audio_math::linear_from_decibel((Float32)-HUGE_VAL), 0.0f, 0.01f);
    XCTAssertEqualWithAccuracy(yas::audio_math::linear_from_decibel((Float32)0.0f), 1.0f, 0.01f);
    XCTAssertEqualWithAccuracy(yas::audio_math::linear_from_decibel((Float32)6.0f), 2.0f, 0.01f);
    XCTAssertEqualWithAccuracy(yas::audio_math::linear_from_decibel((Float32)-6.0f), 0.5f, 0.01f);
}

- (void)test_tempo_from_seconds
{
    XCTAssertEqualWithAccuracy(yas::audio_math::tempo_from_seconds(0.0), HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::tempo_from_seconds(1.0), 60.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::tempo_from_seconds(2.0), 30.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::tempo_from_seconds(0.5), 120.0, 0.01);
}

- (void)test_seconds_from_tempo
{
    XCTAssertEqualWithAccuracy(yas::audio_math::seconds_from_tempo(0.0), HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::seconds_from_tempo(60.0), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::seconds_from_tempo(30.0), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::seconds_from_tempo(120.0), 0.5, 0.01);
}

- (void)test_frames_from_seconds
{
    XCTAssertEqual(yas::audio_math::frames_from_seconds(0.0, 1000), 0);
    XCTAssertEqual(yas::audio_math::frames_from_seconds(1.0, 1000), 1000);
    XCTAssertEqual(yas::audio_math::frames_from_seconds(2.0, 1000), 2000);
    XCTAssertEqual(yas::audio_math::frames_from_seconds(1.0, 44100), 44100);
}

- (void)test_seconds_from_frames
{
    XCTAssertEqualWithAccuracy(yas::audio_math::seconds_from_frames(0, 1000), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::seconds_from_frames(1000, 1000), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::seconds_from_frames(2000, 1000), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(yas::audio_math::seconds_from_frames(44100, 44100), 1.0, 0.01);
}

- (void)test_fill_sine
{
    const UInt32 count = 8;
    const Float64 startPhase = 0.1;
    const Float64 phasePerFrame = 1.0 / (Float64)count * yas::audio_math::two_pi;
    Float32 *data = static_cast<Float32 *>(calloc(count, sizeof(Float32)));

    yas::audio_math::fill_sine(data, count, startPhase, phasePerFrame);

    Float64 phase = startPhase;
    for (UInt32 i = 0; i < count; i++) {
        Float32 value = sinf(phase);
        phase = fmod(phase + phasePerFrame, yas::audio_math::two_pi);

        Float32 vecValue = data[i];

        XCTAssertEqualWithAccuracy(value, vecValue, 0.0001);
    }

    free(data);
}

@end
