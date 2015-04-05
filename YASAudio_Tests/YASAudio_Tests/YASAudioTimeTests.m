//
//  YASAudioTimeTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"
#import <AVFoundation/AVFoundation.h>

static NSInteger testCount = 8;

@interface YASAudioTimeTest : XCTestCase

@end

@implementation YASAudioTimeTest

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (void)testCreateAudioTimeWithHostTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();

        YASAudioTime *avTime = [YASAudioTime timeWithHostTime:hostTime];
        YASAudioTime *yasTime = [YASAudioTime timeWithHostTime:hostTime];
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yasTime]);
        XCTAssertTrue(avTime.sampleRate == yasTime.sampleRate, @"");
    }
}

- (void)testCreateAudioTimeSampleTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        YASAudioTime *avTime = [YASAudioTime timeWithSampleTime:sampleTime atRate:rate];
        YASAudioTime *yasTime = [YASAudioTime timeWithSampleTime:sampleTime atRate:rate];
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yasTime]);
        XCTAssertTrue(YASAudioIsEqualDoubleWithAccuracy(avTime.sampleRate, yasTime.sampleRate, 0.00001), @"");
    }
}

- (void)testCreateAudioTimeWithHostTimeAndSampleTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        YASAudioTime *avTime = [YASAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        YASAudioTime *yasTime = [YASAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yasTime]);
        XCTAssertTrue(YASAudioIsEqualDoubleWithAccuracy(avTime.sampleRate, yasTime.sampleRate, 0.00001), @"");
    }
}

- (void)testConvert
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();

        NSTimeInterval avSec = [YASAudioTime secondsForHostTime:hostTime];
        NSTimeInterval yasSec = [YASAudioTime secondsForHostTime:hostTime];
        XCTAssertTrue(avSec == yasSec, @"");
        uint64_t avHostTime = [YASAudioTime hostTimeForSeconds:avSec];
        uint64_t yasHostTime = [YASAudioTime hostTimeForSeconds:yasSec];
        XCTAssertTrue(avHostTime == yasHostTime, @"");
    }
}

- (void)testExtrapolateTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        YASAudioTime *avTime = [YASAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        YASAudioTime *yasTime = [YASAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        int64_t sampleTime2 = sampleTime + arc4random();
        YASAudioTime *avTime2 = [YASAudioTime timeWithSampleTime:sampleTime2 atRate:rate];
        YASAudioTime *yasTime2 = [YASAudioTime timeWithSampleTime:sampleTime2 atRate:rate];
        YASAudioTime *avExtraplateTime = [avTime2 extrapolateTimeFromAnchor:avTime];
        YASAudioTime *yasExtraplateTime = [yasTime2 extrapolateTimeFromAnchor:yasTime];
        XCTAssertTrue([self compareAudioTimeStamp:avExtraplateTime to:yasExtraplateTime]);
        XCTAssertTrue(avTime2.sampleRate == yasTime2.sampleRate, @"");
    }
}

- (BOOL)compareAudioTimeStamp:(YASAudioTime *)avTime to:(YASAudioTime *)yasTime
{
    AudioTimeStamp avTimeStamp = avTime.audioTimeStamp;
    AudioTimeStamp yasTimeStamp = yasTime.audioTimeStamp;
    return YASAudioIsEqualAudioTimeStamp(&avTimeStamp, &yasTimeStamp);
}

@end
