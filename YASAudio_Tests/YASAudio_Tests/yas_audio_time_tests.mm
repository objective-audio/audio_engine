//
//  yas_audio_time_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import <AVFoundation/AVFoundation.h>
#import "yas_audio_time.h"
#import "YASAudioUtility.h"

static NSInteger testCount = 8;

@interface yas_audio_time_tests : XCTestCase

@end

@implementation yas_audio_time_tests

- (void)setUp
{
    [super setUp];
}

- (void)tearDown
{
    [super tearDown];
}

- (BOOL)compareAudioTimeStamp:(AVAudioTime *)avTime to:(yas::audio_time &)yasTime
{
    AudioTimeStamp avTimeStamp = avTime.audioTimeStamp;
    const AudioTimeStamp &yasTimeStamp = yasTime.audio_time_stamp();
    return YASAudioIsEqualAudioTimeStamp(&avTimeStamp, &yasTimeStamp);
}

- (void)testCreateAudioTimeWithHostTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime];
        auto yas_time = yas::audio_time(hostTime);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(avTime.sampleRate == yas_time.sample_rate(), @"");
    }
}

- (void)testCreateAudioTimeSampleTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithSampleTime:sampleTime atRate:rate];
        auto yas_time = yas::audio_time(sampleTime, rate);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(YASAudioIsEqualDoubleWithAccuracy(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)testCreateAudioTimeWithHostTimeAndSampleTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        auto yas_time = yas::audio_time(hostTime, sampleTime, rate);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(YASAudioIsEqualDoubleWithAccuracy(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)testConvert
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();

        NSTimeInterval avSec = [AVAudioTime secondsForHostTime:hostTime];
        NSTimeInterval yasSec = yas::seconds_for_host_time(hostTime);
        XCTAssertTrue(avSec == yasSec, @"");
        uint64_t avHostTime = [AVAudioTime hostTimeForSeconds:avSec];
        uint64_t yasHostTime = yas::host_time_for_seconds(yasSec);
        XCTAssertTrue(avHostTime == yasHostTime, @"");
    }
}

- (void)testExtrapolateTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        uint64_t hostTime = arc4random();
        int64_t sampleTime = arc4random();
        double rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        auto yas_time = yas::audio_time(hostTime, sampleTime, rate);
        int64_t sampleTime2 = sampleTime + arc4random();
        AVAudioTime *avTime2 = [AVAudioTime timeWithSampleTime:sampleTime2 atRate:rate];
        auto yas_time2 = yas::audio_time(sampleTime2, rate);
        AVAudioTime *avExtraplateTime = [avTime2 extrapolateTimeFromAnchor:avTime];
        auto yas_extraplate_time = yas_time2.extrapolate_time_from_anchor(yas_time);

        XCTAssertTrue([self compareAudioTimeStamp:avExtraplateTime to:yas_extraplate_time]);
        XCTAssertTrue(avTime2.sampleRate == yas_time2.sample_rate());
    }
}

@end
