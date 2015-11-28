//
//  yas_audio_time_tests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "yas_audio_test_utils.h"

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

- (void)testCreateAudioTimeWithHostTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        UInt64 hostTime = arc4random();

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime];
        auto yas_time = yas::audio_time(hostTime);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(avTime.sampleRate == yas_time.sample_rate(), @"");
    }
}

- (void)testCreateAudioTimeSampleTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        SInt64 sampleTime = arc4random();
        Float64 rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithSampleTime:sampleTime atRate:rate];
        auto yas_time = yas::audio_time(sampleTime, rate);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(yas::test::is_equal(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)testCreateAudioTimeWithHostTimeAndSampleTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        UInt64 hostTime = arc4random();
        SInt64 sampleTime = arc4random();
        Float64 rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        auto yas_time = yas::audio_time(hostTime, sampleTime, rate);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(yas::test::is_equal(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)testConvert
{
    for (NSInteger i = 0; i < testCount; i++) {
        UInt64 hostTime = arc4random();

        NSTimeInterval avSec = [AVAudioTime secondsForHostTime:hostTime];
        NSTimeInterval yasSec = yas::seconds_for_host_time(hostTime);
        XCTAssertTrue(avSec == yasSec, @"");
        UInt64 avHostTime = [AVAudioTime hostTimeForSeconds:avSec];
        UInt64 yasHostTime = yas::host_time_for_seconds(yasSec);
        XCTAssertTrue(avHostTime == yasHostTime, @"");
    }
}

- (void)testExtrapolateTime
{
    for (NSInteger i = 0; i < testCount; i++) {
        UInt64 hostTime = arc4random();
        SInt64 sampleTime = arc4random();
        Float64 rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithHostTime:hostTime sampleTime:sampleTime atRate:rate];
        auto yas_time = yas::audio_time(hostTime, sampleTime, rate);
        SInt64 sampleTime2 = sampleTime + arc4random();
        AVAudioTime *avTime2 = [AVAudioTime timeWithSampleTime:sampleTime2 atRate:rate];
        auto yas_time2 = yas::audio_time(sampleTime2, rate);
        AVAudioTime *avExtraplateTime = [avTime2 extrapolateTimeFromAnchor:avTime];
        auto yas_extraplate_time = yas_time2.extrapolate_time_from_anchor(yas_time);

        XCTAssertTrue([self compareAudioTimeStamp:avExtraplateTime to:yas_extraplate_time]);
        XCTAssertTrue(avTime2.sampleRate == yas_time2.sample_rate());
    }
}

- (void)test_compare_objc_to_cpp
{
    for (NSInteger i = 0; i < testCount; i++) {
        SInt64 sampleTime = arc4random();
        Float64 rate = arc4random_uniform(378000 - 4000) + 4000;

        AVAudioTime *avTime = [AVAudioTime timeWithSampleTime:sampleTime atRate:rate];
        auto yas_time = yas::to_audio_time(avTime);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(yas::test::is_equal(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)test_compare_cpp_to_objc
{
    for (NSInteger i = 0; i < testCount; i++) {
        SInt64 sampleTime = arc4random();
        Float64 rate = arc4random_uniform(378000 - 4000) + 4000;

        auto yas_time = yas::audio_time(sampleTime, rate);
        AVAudioTime *avTime = yas::to_objc_object(yas_time);
        XCTAssertTrue([self compareAudioTimeStamp:avTime to:yas_time]);
        XCTAssertTrue(yas::test::is_equal(avTime.sampleRate, yas_time.sample_rate(), 0.00001), @"");
    }
}

- (void)test_bool
{
    yas::audio_time time{100};

    XCTAssertTrue(time);

    yas::audio_time null_time{nullptr};

    XCTAssertFalse(null_time);
}

- (void)test_host_time
{
    const UInt64 host_time = 1000;
    yas::audio_time time{host_time};

    XCTAssertTrue(time.is_host_time_valid());
    XCTAssertTrue(time.host_time() == 1000);
}

- (void)test_sample_time
{
    const SInt64 sample_time = 2000;
    const Float64 sample_rate = 48000.0;
    yas::audio_time time{sample_time, sample_rate};

    XCTAssertTrue(time.is_sample_time_valid());
    XCTAssertTrue(time.sample_time() == 2000);
}

- (void)test_equal_null_false
{
    const yas::audio_time time1{4000, 48000.0};
    const yas::audio_time time2{nullptr};
    const yas::audio_time time3{nullptr};

    XCTAssertFalse(time1 == time2);
    XCTAssertFalse(time2 == time1);
    XCTAssertFalse(time2 == time2);
}

#pragma mark -

- (BOOL)compareAudioTimeStamp:(AVAudioTime *)avTime to:(yas::audio_time &)yasTime
{
    AudioTimeStamp avTimeStamp = avTime.audioTimeStamp;
    const AudioTimeStamp &yasTimeStamp = yasTime.audio_time_stamp();
    return yas::test::is_equal(&avTimeStamp, &yasTimeStamp);
}

@end
