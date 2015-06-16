//
//  YASAudioTimeTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"
#import <AVFoundation/AVFoundation.h>

// static NSInteger testCount = 8;

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
/*
- (void)testCreateAudioTimeWithHostTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime];
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

        AVAudioTime *avTime = [AVAudioTime timeWithSampleTime:sampleTime atRate:rate];
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

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        YASAudioTime *yasTime = [YASAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yasTime]);
        XCTAssertTrue(YASAudioIsEqualDoubleWithAccuracy(avTime.sampleRate, yasTime.sampleRate, 0.00001), @"");
    }
}

- (void)testConvert
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();

        NSTimeInterval avSec = [AVAudioTime secondsForHostTime:hostTime];
        NSTimeInterval yasSec = [YASAudioTime secondsForHostTime:hostTime];
        XCTAssertTrue(avSec == yasSec, @"");
        uint64_t avHostTime = [AVAudioTime hostTimeForSeconds:avSec];
        uint64_t yasHostTime = [YASAudioTime hostTimeForSeconds:yasSec];
        XCTAssertTrue(avHostTime == yasHostTime, @"");
    }
}

- (void)testExtrapolateTime
{
    NSInteger successCount = 0;
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        YASAudioTime *yasTime = [YASAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        int64_t sampleTime2 = sampleTime + arc4random();
        AVAudioTime *avTime2 = [AVAudioTime timeWithSampleTime:sampleTime2 atRate:rate];
        YASAudioTime *yasTime2 = [YASAudioTime timeWithSampleTime:sampleTime2 atRate:rate];
        AVAudioTime *avExtraplateTime = [avTime2 extrapolateTimeFromAnchor:avTime];
        YASAudioTime *yasExtraplateTime = [yasTime2 extrapolateTimeFromAnchor:yasTime];

        if ([self compareAudioTimeStamp:avExtraplateTime to:yasExtraplateTime] &&
            avTime2.sampleRate == yasTime2.sampleRate) {
            successCount++;
        }
    }
    XCTAssertNotEqual(successCount, 0);
    XCTAssertGreaterThanOrEqual(successCount, testCount / 2);
}

- (BOOL)compareAudioTimeStamp:(AVAudioTime *)avTime to:(YASAudioTime *)yasTime
{
    AudioTimeStamp avTimeStamp = avTime.audioTimeStamp;
    AudioTimeStamp yasTimeStamp = yasTime.audioTimeStamp;
    return YASAudioIsEqualAudioTimeStamp(&avTimeStamp, &yasTimeStamp);
}
*/
@end
