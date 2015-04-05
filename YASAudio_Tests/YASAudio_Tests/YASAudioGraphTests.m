//
//  YASAudioGraphTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

@interface YASAudioGraph (YASAudioGraphTests)

+ (void)_didBecomeActiveNotification:(NSNotification *)notification;
+ (void)_interruptionNotification:(NSNotification *)notification;

@end

@interface YASAudioGraphTests : XCTestCase

@property (nonatomic, strong) YASAudioGraph *audioGraph;

@end

@implementation YASAudioGraphTests

- (void)setUp
{
    [super setUp];

    YASAudioGraph *audioGraph = [[YASAudioGraph alloc] init];
    self.audioGraph = audioGraph;
    YASRelease(audioGraph);
}

- (void)tearDown
{
    self.audioGraph = nil;

    [super tearDown];
}

- (void)testRunning
{
    self.audioGraph.running = YES;

    XCTAssertTrue(self.audioGraph.isRunning);

    self.audioGraph.running = NO;

    XCTAssertFalse(self.audioGraph.isRunning);
}

- (void)testIORendering
{
    const Float64 outputSampleRate = 48000;
    const Float64 mixerSampleRate = 44100;
    const UInt32 channels = 2;
    const UInt32 frameLength = 1024;
    const UInt32 maximumFrameLength = 4096;

    YASAudioFormat *outputFormat =
        [[YASAudioFormat alloc] initStandardFormatWithSampleRate:outputSampleRate channels:channels];
    YASAudioFormat *mixerFormat =
        [[YASAudioFormat alloc] initStandardFormatWithSampleRate:mixerSampleRate channels:channels];

    YASAudioGraph *audioGraph = self.audioGraph;

    YASAudioUnit *ioUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_Output subType:kAudioUnitSubType_GenericOutput];
    [ioUnit setMaximumFramesPerSlice:maximumFrameLength];
    [audioGraph addAudioUnit:ioUnit];
    YASRelease(ioUnit);

    [ioUnit setRenderCallback:0];

    const UInt32 mixerInputCount = 16;

    YASAudioUnit *mixerUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer];
    [mixerUnit setMaximumFramesPerSlice:maximumFrameLength];
    [audioGraph addAudioUnit:mixerUnit];
    YASRelease(mixerUnit);

    [mixerUnit setOutputFormat:mixerFormat.streamDescription busNumber:0];

    AudioStreamBasicDescription outputASBD;
    [mixerUnit getOutputFormat:&outputASBD busNumber:0];
    XCTAssertEqual(outputASBD.mSampleRate, mixerSampleRate);

    [mixerUnit setElementCount:4 scope:kAudioUnitScope_Input];
    XCTAssertNotEqual([mixerUnit elementCountForScope:kAudioUnitScope_Input], 4);  // Under 8
    XCTAssertEqual([mixerUnit elementCountForScope:kAudioUnitScope_Input], 8);

    [mixerUnit setElementCount:mixerInputCount scope:kAudioUnitScope_Input];
    XCTAssertEqual([mixerUnit elementCountForScope:kAudioUnitScope_Input], mixerInputCount);

    for (UInt32 i = 0; i < mixerInputCount; i++) {
        AudioStreamBasicDescription inputASBD;

        [mixerUnit setRenderCallback:i];

        [mixerUnit setInputFormat:outputFormat.streamDescription busNumber:i];
        [mixerUnit getInputFormat:&inputASBD busNumber:i];
        XCTAssertEqual(inputASBD.mSampleRate, outputSampleRate);

        [mixerUnit setInputFormat:mixerFormat.streamDescription busNumber:i];
        [mixerUnit getInputFormat:&inputASBD busNumber:i];
        XCTAssertEqual(inputASBD.mSampleRate, mixerSampleRate);
    }

    XCTestExpectation *ioExpectation = [self expectationWithDescription:@"IOUnit Render"];

    ioUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        [ioExpectation fulfill];

        XCTAssertEqual(renderParameters->inNumberFrames, frameLength);
        XCTAssertEqual(renderParameters->inBusNumber, 0);
        XCTAssertEqual(renderParameters->inRenderType, YASAudioUnitRenderTypeNormal);
        XCTAssertEqual(*renderParameters->ioActionFlags, 0);
        const AudioBufferList *ioData = renderParameters->ioData;
        XCTAssertNotEqual(ioData, NULL);
        XCTAssertEqual(ioData->mNumberBuffers, outputFormat.bufferCount);
        for (UInt32 i = 0; i < outputFormat.bufferCount; i++) {
            XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, outputFormat.stride);
            XCTAssertEqual(ioData->mBuffers[i].mDataByteSize,
                           outputFormat.sampleByteCount * outputFormat.stride * renderParameters->inNumberFrames);
        }

        [mixerUnit audioUnitRender:renderParameters];
    };

    NSMutableArray *mixerExpectations = [NSMutableArray arrayWithCapacity:mixerInputCount];
    for (UInt32 i = 0; i < mixerInputCount; i++) {
        NSString *description = [NSString stringWithFormat:@"MixerUnit Render Bus=%@", @(i)];
        [mixerExpectations addObject:[self expectationWithDescription:description]];
    }

    mixerUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        const UInt32 bus = renderParameters->inBusNumber;
        if (bus < mixerExpectations.count) {
            XCTestExpectation *mixerExpectation = mixerExpectations[bus];
            [mixerExpectation fulfill];

            XCTAssertEqual(renderParameters->inNumberFrames, frameLength);
            XCTAssertEqual(renderParameters->inRenderType, YASAudioUnitRenderTypeNormal);
            XCTAssertEqual(*renderParameters->ioActionFlags, 0);
            const AudioBufferList *ioData = renderParameters->ioData;
            XCTAssertNotEqual(ioData, NULL);
            XCTAssertEqual(ioData->mNumberBuffers, outputFormat.bufferCount);
            for (UInt32 i = 0; i < outputFormat.bufferCount; i++) {
                XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, outputFormat.stride);
                XCTAssertEqual(ioData->mBuffers[i].mDataByteSize,
                               outputFormat.sampleByteCount * outputFormat.stride * renderParameters->inNumberFrames);
            }
        }
    };

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AudioUnitRenderActionFlags actionFlags = 0;
        YASAudioTime *audioTime = [YASAudioTime timeWithSampleTime:0 atRate:outputSampleRate];
        AudioTimeStamp timeStamp = audioTime.audioTimeStamp;

        YASAudioPCMBuffer *buffer =
            [[YASAudioPCMBuffer alloc] initWithPCMFormat:outputFormat frameCapacity:frameLength];

        YASAudioUnitRenderParameters parameters = {
            .inRenderType = YASAudioUnitRenderTypeNormal,
            .ioActionFlags = &actionFlags,
            .ioTimeStamp = &timeStamp,
            .inBusNumber = 0,
            .inNumberFrames = 1024,
            .ioData = buffer.mutableAudioBufferList,
        };

        [ioUnit audioUnitRender:&parameters];

        YASRelease(buffer);
    });

    [self waitForExpectationsWithTimeout:1.0
                                 handler:^(NSError *error){

                                 }];

    YASRelease(outputFormat);
}

#if TARGET_OS_IPHONE

- (void)testInterrupting
{
    XCTAssertFalse([YASAudioGraph isInterrupting]);

    NSDictionary *beganUserInfo = @{ AVAudioSessionInterruptionTypeKey: @(AVAudioSessionInterruptionTypeBegan) };
    NSNotification *beganNotification =
        [[NSNotification alloc] initWithName:AVAudioSessionInterruptionNotification object:nil userInfo:beganUserInfo];
    [YASAudioGraph _interruptionNotification:beganNotification];

    XCTAssertTrue([YASAudioGraph isInterrupting]);

    NSDictionary *endedUserInfo = @{ AVAudioSessionInterruptionTypeKey: @(AVAudioSessionInterruptionTypeEnded) };
    NSNotification *endedNotification =
        [[NSNotification alloc] initWithName:AVAudioSessionInterruptionNotification object:nil userInfo:endedUserInfo];

    [YASAudioGraph _interruptionNotification:endedNotification];

    XCTAssertFalse([YASAudioGraph isInterrupting]);
}

- (void)testBecomeActive
{
    NSDictionary *beganUserInfo = @{ AVAudioSessionInterruptionTypeKey: @(AVAudioSessionInterruptionTypeBegan) };
    NSNotification *beganNotification =
        [[NSNotification alloc] initWithName:AVAudioSessionInterruptionNotification object:nil userInfo:beganUserInfo];
    [YASAudioGraph _interruptionNotification:beganNotification];

    XCTAssertTrue([YASAudioGraph isInterrupting]);

    [YASAudioGraph _didBecomeActiveNotification:nil];

    XCTAssertFalse([YASAudioGraph isInterrupting]);
}

#endif

@end
