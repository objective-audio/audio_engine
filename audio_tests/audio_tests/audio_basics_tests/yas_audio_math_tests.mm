//
//  YASAudioMathTests.m
//

#import "yas_audio_test_utils.h"

using namespace yas;

@interface yas_audio_math_tests : XCTestCase

@end

@implementation yas_audio_math_tests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test_two_pi {
    XCTAssertEqual(2.0 * M_PI, audio::math::two_pi);
}

- (void)test_decibel_from_linear_float64 {
    XCTAssertEqualWithAccuracy(audio::math::decibel_from_linear((Float64)0.0), -HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::decibel_from_linear((Float64)1.0), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::decibel_from_linear((Float64)2.0), 6.0, 0.1);
    XCTAssertEqualWithAccuracy(audio::math::decibel_from_linear((Float64)0.5), -6.0, 0.1);
}

- (void)test_decibel_from_linear_float32 {
    XCTAssertEqualWithAccuracy(audio::math::decibel_from_linear((Float32)0.0f), -HUGE_VAL, 0.01f);
    XCTAssertEqualWithAccuracy(audio::math::decibel_from_linear((Float32)1.0f), 0.0f, 0.01f);
    XCTAssertEqualWithAccuracy(audio::math::decibel_from_linear((Float32)2.0f), 6.0f, 0.1f);
    XCTAssertEqualWithAccuracy(audio::math::decibel_from_linear((Float32)0.5f), -6.0f, 0.1f);
}

- (void)test_linear_from_decibel_float64 {
    XCTAssertEqualWithAccuracy(audio::math::linear_from_decibel((Float64)-HUGE_VAL), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::linear_from_decibel((Float64)0.0), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::linear_from_decibel((Float64)6.0), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::linear_from_decibel((Float64)-6.0), 0.5, 0.01);
}

- (void)test_linear_from_decibel_float32 {
    XCTAssertEqualWithAccuracy(audio::math::linear_from_decibel((Float32)-HUGE_VAL), 0.0f, 0.01f);
    XCTAssertEqualWithAccuracy(audio::math::linear_from_decibel((Float32)0.0f), 1.0f, 0.01f);
    XCTAssertEqualWithAccuracy(audio::math::linear_from_decibel((Float32)6.0f), 2.0f, 0.01f);
    XCTAssertEqualWithAccuracy(audio::math::linear_from_decibel((Float32)-6.0f), 0.5f, 0.01f);
}

- (void)test_tempo_from_seconds {
    XCTAssertEqualWithAccuracy(audio::math::tempo_from_seconds(0.0), HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::tempo_from_seconds(1.0), 60.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::tempo_from_seconds(2.0), 30.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::tempo_from_seconds(0.5), 120.0, 0.01);
}

- (void)test_seconds_from_tempo {
    XCTAssertEqualWithAccuracy(audio::math::seconds_from_tempo(0.0), HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::seconds_from_tempo(60.0), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::seconds_from_tempo(30.0), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::seconds_from_tempo(120.0), 0.5, 0.01);
}

- (void)test_frames_from_seconds {
    XCTAssertEqual(audio::math::frames_from_seconds(0.0, 1000), 0);
    XCTAssertEqual(audio::math::frames_from_seconds(1.0, 1000), 1000);
    XCTAssertEqual(audio::math::frames_from_seconds(2.0, 1000), 2000);
    XCTAssertEqual(audio::math::frames_from_seconds(1.0, 44100), 44100);
}

- (void)test_seconds_from_frames {
    XCTAssertEqualWithAccuracy(audio::math::seconds_from_frames(0, 1000), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::seconds_from_frames(1000, 1000), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::seconds_from_frames(2000, 1000), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(audio::math::seconds_from_frames(44100, 44100), 1.0, 0.01);
}

- (void)test_fill_sine {
    const UInt32 count = 8;
    const Float64 startPhase = 0.1;
    const Float64 phasePerFrame = 1.0 / (Float64)count * audio::math::two_pi;
    Float32 *data = static_cast<Float32 *>(calloc(count, sizeof(Float32)));

    audio::math::fill_sine(data, count, startPhase, phasePerFrame);

    Float64 phase = startPhase;
    for (UInt32 i = 0; i < count; i++) {
        Float32 value = sinf(phase);
        phase = fmod(phase + phasePerFrame, audio::math::two_pi);

        Float32 vecValue = data[i];

        XCTAssertEqualWithAccuracy(value, vecValue, 0.0001);
    }

    free(data);
}

- (void)test_level_init_float64 {
    audio::level<Float64> level;
    XCTAssertEqual(level.linear(), 0.0);
    XCTAssertEqualWithAccuracy(level.decibel(), -HUGE_VAL, 0.01f);
}

- (void)test_level_init_with_value_float64 {
    audio::level<Float64> level{1.0};
    XCTAssertEqual(level.linear(), 1.0);
    XCTAssertEqual(level.decibel(), 0.0);
}

- (void)test_level_equal_float64 {
    audio::level<Float64> level_a{1.0};
    audio::level<Float64> level_b{1.0};

    XCTAssertTrue(level_a == level_b);
    XCTAssertFalse(level_a != level_b);

    level_b.set_linear(0.5);

    XCTAssertTrue(level_a != level_b);
    XCTAssertFalse(level_a == level_b);
}

- (void)test_set_linear_float64 {
    audio::level<Float64> level;
    level.set_linear(1.0);

    XCTAssertEqual(level.linear(), 1.0);
    XCTAssertEqual(level.decibel(), 0.0);
}

- (void)test_set_decibel_float64 {
    audio::level<Float64> level;
    level.set_decibel(0.0);

    XCTAssertEqual(level.linear(), 1.0);
    XCTAssertEqual(level.decibel(), 0.0);
}

- (void)test_level_init_float32 {
    audio::level<Float32> level;
    XCTAssertEqual(level.linear(), 0.0);
    XCTAssertEqualWithAccuracy(level.decibel(), -HUGE_VAL, 0.01f);
}

- (void)test_level_init_with_value_float32 {
    audio::level<Float32> level{1.0};
    XCTAssertEqual(level.linear(), 1.0);
    XCTAssertEqual(level.decibel(), 0.0);
}

- (void)test_level_equal_float32 {
    audio::level<Float32> level_a{1.0};
    audio::level<Float32> level_b{1.0};

    XCTAssertTrue(level_a == level_b);
    XCTAssertFalse(level_a != level_b);

    level_b.set_linear(0.5);

    XCTAssertTrue(level_a != level_b);
    XCTAssertFalse(level_a == level_b);
}

- (void)test_set_linear_float32 {
    audio::level<Float32> level;
    level.set_linear(1.0);

    XCTAssertEqual(level.linear(), 1.0);
    XCTAssertEqual(level.decibel(), 0.0);
}

- (void)test_set_decibel_float32 {
    audio::level<Float32> level;
    level.set_decibel(0.0);

    XCTAssertEqual(level.linear(), 1.0);
    XCTAssertEqual(level.decibel(), 0.0);
}

- (void)test_duration_init {
    audio::duration duration;

    XCTAssertEqual(duration.seconds(), 0.0);
    XCTAssertEqualWithAccuracy(duration.tempo(), HUGE_VAL, 0.01);
}

- (void)test_duration_init_with_value {
    audio::duration duration{1.0};

    XCTAssertEqual(duration.seconds(), 1.0);
    XCTAssertEqual(duration.tempo(), 60.0);
}

- (void)test_duration_equal {
    audio::duration duration_a{1.0};
    audio::duration duration_b{1.0};

    XCTAssertTrue(duration_a == duration_b);
    XCTAssertFalse(duration_a != duration_b);

    duration_b.set_seconds(0.5);

    XCTAssertTrue(duration_a != duration_b);
    XCTAssertFalse(duration_a == duration_b);
}

- (void)test_set_seconds {
    audio::duration duration;

    duration.set_seconds(1.0);

    XCTAssertEqual(duration.seconds(), 1.0);
    XCTAssertEqual(duration.tempo(), 60.0);
}

- (void)test_set_tempo {
    audio::duration duration;

    duration.set_tempo(60.0);

    XCTAssertEqual(duration.seconds(), 1.0);
    XCTAssertEqual(duration.tempo(), 60.0);
}

@end
