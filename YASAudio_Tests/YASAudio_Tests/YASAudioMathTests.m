//
//  YASAudioMathTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioMath.h"

@interface YASAudioMathTests : XCTestCase

@end

@implementation YASAudioMathTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)test2pi
{
    XCTAssertEqual(2.0 * M_PI, YAS_2_PI);
}

- (void)testDecibelFromLinear
{
    XCTAssertEqualWithAccuracy(YASAudioDecibelFromLinear(0.0), -HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioDecibelFromLinear(1.0), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioDecibelFromLinear(2.0), 6.0, 0.1);
    XCTAssertEqualWithAccuracy(YASAudioDecibelFromLinear(0.5), -6.0, 0.1);
}

- (void)testDecibelFromLinearFloat
{
    XCTAssertEqualWithAccuracy(YASAudioDecibelFromLinearf(0.0f), -HUGE_VAL, 0.01f);
    XCTAssertEqualWithAccuracy(YASAudioDecibelFromLinearf(1.0f), 0.0f, 0.01f);
    XCTAssertEqualWithAccuracy(YASAudioDecibelFromLinearf(2.0f), 6.0f, 0.1f);
    XCTAssertEqualWithAccuracy(YASAudioDecibelFromLinearf(0.5f), -6.0f, 0.1f);
}

- (void)testLinearFromDecibel
{
    XCTAssertEqualWithAccuracy(YASAudioLinearFromDecibel(-HUGE_VAL), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioLinearFromDecibel(0.0), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioLinearFromDecibel(6.0), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioLinearFromDecibel(-6.0), 0.5, 0.01);
}

- (void)testLinearFromDecibelFloat
{
    XCTAssertEqualWithAccuracy(YASAudioLinearFromDecibelf(-HUGE_VAL), 0.0f, 0.01f);
    XCTAssertEqualWithAccuracy(YASAudioLinearFromDecibelf(0.0f), 1.0f, 0.01f);
    XCTAssertEqualWithAccuracy(YASAudioLinearFromDecibelf(6.0f), 2.0f, 0.01f);
    XCTAssertEqualWithAccuracy(YASAudioLinearFromDecibelf(-6.0f), 0.5f, 0.01f);
}

- (void)testTempoFromSeconds
{
    XCTAssertEqualWithAccuracy(YASAudioTempoFromSeconds(0.0), HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioTempoFromSeconds(1.0), 60.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioTempoFromSeconds(2.0), 30.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioTempoFromSeconds(0.5), 120.0, 0.01);
}

- (void)testSecondsFromTempo
{
    XCTAssertEqualWithAccuracy(YASAudioSecondsFromTempo(0.0), HUGE_VAL, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioSecondsFromTempo(60.0), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioSecondsFromTempo(30.0), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioSecondsFromTempo(120.0), 0.5, 0.01);
}

- (void)testFramesFromSeconds
{
    XCTAssertEqual(YASAudioFramesFromSeconds(0.0, 1000), 0);
    XCTAssertEqual(YASAudioFramesFromSeconds(1.0, 1000), 1000);
    XCTAssertEqual(YASAudioFramesFromSeconds(2.0, 1000), 2000);
    XCTAssertEqual(YASAudioFramesFromSeconds(1.0, 44100), 44100);
}

- (void)testSecondsFromFrames
{
    XCTAssertEqualWithAccuracy(YASAudioSecondsFromFrames(0, 1000), 0.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioSecondsFromFrames(1000, 1000), 1.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioSecondsFromFrames(2000, 1000), 2.0, 0.01);
    XCTAssertEqualWithAccuracy(YASAudioSecondsFromFrames(44100, 44100), 1.0, 0.01);
}

- (void)testVectorSinef
{
    const UInt32 count = 8;
    const Float64 startPhase = 0.1;
    const Float64 phasePerFrame = 1.0 / (Float64)count * 2.0 * M_PI;
    Float32 *data = calloc(count, sizeof(Float32));
    
    YASAudioVectorSinef(data, count, startPhase, phasePerFrame);
    
    Float64 phase = startPhase;
    for (UInt32 i = 0; i < count; i++) {
        Float32 value = sinf(phase);
        phase = fmod(phase + phasePerFrame, 2.0 * M_PI);
        
        Float32 vecValue =  data[i];
        
        XCTAssertEqualWithAccuracy(value, vecValue, 0.0001);
    }
    
    free(data);
}

@end
