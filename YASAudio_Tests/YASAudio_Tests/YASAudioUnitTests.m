//
//  YASAudioUnitTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudioTestUtils.h"

@interface YASAudioUnit ()

@property (nonatomic, assign, getter=isInitialized) BOOL initialized;

@end

@interface YASAudioUnitTests : XCTestCase

@property (nonatomic, strong) YASAudioGraph *audioGraph;

@end

@implementation YASAudioUnitTests

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

- (void)testConverterUnit
{
    const Float64 outputSampleRate = 44100;
    const Float64 inputSampleRate = 48000;
    const UInt32 channels = 2;
    const UInt32 frameLength = 1024;
    const UInt32 maximumFrameLength = 4096;
    const OSType type = kAudioUnitType_FormatConverter;
    const OSType subType = kAudioUnitSubType_AUConverter;

    YASAudioFormat *outputFormat = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                                       sampleRate:outputSampleRate
                                                                         channels:channels
                                                                      interleaved:NO];
    YASAudioFormat *inputFormat = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatInt16
                                                                      sampleRate:inputSampleRate
                                                                        channels:channels
                                                                     interleaved:YES];

    YASAudioGraph *audioGraph = self.audioGraph;

    YASAudioUnit *converterUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_AUConverter];

    [converterUnit setMaximumFramesPerSlice:maximumFrameLength];
    [audioGraph addAudioUnit:converterUnit];

    XCTAssertTrue(converterUnit.isInitialized);

    XCTAssertEqual(converterUnit.type, type);
    XCTAssertEqual(converterUnit.subType, subType);
    XCTAssertFalse(converterUnit.isOutputUnit);
    XCTAssertTrue(converterUnit.audioUnitInstance != NULL);
    XCTAssertEqual([converterUnit maximumFramesPerSlice], maximumFrameLength);

    [converterUnit setRenderCallback:0];
    [converterUnit setOutputFormat:outputFormat.streamDescription busNumber:0];
    [converterUnit setInputFormat:inputFormat.streamDescription busNumber:0];

    AudioStreamBasicDescription outputASBD = {0};
    [converterUnit getOutputFormat:&outputASBD busNumber:0];
    XCTAssertTrue(YASAudioIsEqualASBD(outputFormat.streamDescription, &outputASBD));

    AudioStreamBasicDescription inputASBD = {0};
    [converterUnit getInputFormat:&inputASBD busNumber:0];
    XCTAssertTrue(YASAudioIsEqualASBD(inputFormat.streamDescription, &inputASBD));

    XCTestExpectation *expectation = [self expectationWithDescription:@"ConverterUnit Render"];

    converterUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        [expectation fulfill];

        const AudioBufferList *ioData = renderParameters->ioData;
        XCTAssertNotEqual(ioData, NULL);
        XCTAssertEqual(ioData->mNumberBuffers, inputFormat.bufferCount);
        for (UInt32 i = 0; i < inputFormat.bufferCount; i++) {
            XCTAssertEqual(ioData->mBuffers[i].mNumberChannels, inputFormat.stride);
            XCTAssertEqual(ioData->mBuffers[i].mDataByteSize,
                           inputFormat.sampleByteCount * inputFormat.stride * renderParameters->inNumberFrames);
        }
    };

    [YASAudioTestUtils audioUnitRenderOnSubThreadWithAudioUnit:converterUnit
                                                        format:outputFormat
                                                   frameLength:frameLength
                                                         count:1
                                                          wait:0];

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    YASRelease(outputFormat);
    YASRelease(inputFormat);

    [audioGraph removeAudioUnit:converterUnit];

    XCTAssertFalse(converterUnit.isInitialized);

    YASRelease(converterUnit);
}

- (void)testRenderCallback
{
    const Float64 sampleRate = 44100;
    const UInt32 channels = 2;
    const UInt32 frameLength = 1024;
    const UInt32 maximumFrameLength = 4096;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                                 sampleRate:sampleRate
                                                                   channels:channels
                                                                interleaved:NO];

    YASAudioGraph *audioGraph = self.audioGraph;

    YASAudioUnit *converterUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_AUConverter];

    [converterUnit setMaximumFramesPerSlice:maximumFrameLength];
    [audioGraph addAudioUnit:converterUnit];
    YASRelease(converterUnit);

    [converterUnit setRenderCallback:0];
    [converterUnit addRenderNotify];
    [converterUnit setOutputFormat:format.streamDescription busNumber:0];
    [converterUnit setInputFormat:format.streamDescription busNumber:0];

    XCTestExpectation *renderExpectation = [self expectationWithDescription:@"ConverterUnit Render"];
    XCTestExpectation *preRenderExpectation = [self expectationWithDescription:@"ConverterUnit PreRender"];
    XCTestExpectation *postRenderExpectation = [self expectationWithDescription:@"ConverterUnit PostRender"];

    converterUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        [renderExpectation fulfill];
    };

    converterUnit.notifyCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        AudioUnitRenderActionFlags flags = *renderParameters->ioActionFlags;
        if (flags & kAudioUnitRenderAction_PreRender) {
            [preRenderExpectation fulfill];
        } else if (flags & kAudioUnitRenderAction_PostRender) {
            [postRenderExpectation fulfill];
        }
    };

    [YASAudioTestUtils audioUnitRenderOnSubThreadWithAudioUnit:converterUnit
                                                        format:format
                                                   frameLength:frameLength
                                                         count:1
                                                          wait:0];

    [self waitForExpectationsWithTimeout:0.5
                                 handler:^(NSError *error){

                                 }];

    [converterUnit removeRenderNotify];
    [converterUnit removeRenderCallback:0];

    __block BOOL isRenderCallback = NO;
    __block BOOL isRenderNotifyCallback = NO;

    converterUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        isRenderCallback = YES;
    };

    converterUnit.notifyCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        isRenderNotifyCallback = YES;
    };

    [YASAudioTestUtils audioUnitRenderOnSubThreadWithAudioUnit:converterUnit
                                                        format:format
                                                   frameLength:frameLength
                                                         count:1
                                                          wait:0.2];

    XCTAssertFalse(isRenderCallback);
    XCTAssertFalse(isRenderNotifyCallback);

    YASRelease(format);
}

- (void)testParameter
{
    YASAudioUnit *delayUnit = [[YASAudioUnit alloc] initWithType:kAudioUnitType_Effect subType:kAudioUnitSubType_Delay];

    YASAudioUnitParameter *delayTimeParameter =
        [delayUnit parameter:kDelayParam_DelayTime scope:kAudioUnitScope_Global];

    const AudioUnitParameterValue min = delayTimeParameter.minValue;

    AudioUnitParameterValue value = min;
    AudioUnitScope scope = kAudioUnitScope_Global;

    [delayUnit setParameter:kDelayParam_DelayTime value:value scope:scope element:0];
    XCTAssertEqual([delayUnit getParameter:kDelayParam_DelayTime scope:scope element:0], value);

    delayTimeParameter = nil;
    XCTAssertThrows(delayTimeParameter = [delayUnit parameter:kDelayParam_DelayTime scope:kAudioUnitScope_Input]);
    XCTAssertNil(delayTimeParameter);

    delayTimeParameter = nil;
    XCTAssertThrows(delayTimeParameter = [delayUnit parameter:kDelayParam_DelayTime scope:kAudioUnitScope_Output]);
    XCTAssertNil(delayTimeParameter);

    YASRelease(delayUnit);
}

- (void)testParameters
{
    YASAudioUnit *delayUnit = [[YASAudioUnit alloc] initWithType:kAudioUnitType_Effect subType:kAudioUnitSubType_Delay];

    NSDictionary *parameters = [delayUnit getParametersWithScope:kAudioUnitScope_Global];

    XCTAssertEqual(parameters.count, 4);

    NSArray *parameterIDs =
        @[@(kDelayParam_DelayTime), @(kDelayParam_Feedback), @(kDelayParam_LopassCutoff), @(kDelayParam_WetDryMix)];

    for (YASAudioUnitParameter *parameter in parameters.allValues) {
        XCTAssertTrue([parameter isKindOfClass:[YASAudioUnitParameter class]]);
        [parameterIDs containsObject:@(parameter.parameterID)];
    }

    YASRelease(delayUnit);
}

- (void)testPropertyData
{
    const Float64 sampleRate = 44100;
    const UInt32 channels = 2;
    const AudioUnitPropertyID propertyID = kAudioUnitProperty_StreamFormat;
    const AudioUnitScope scope = kAudioUnitScope_Input;
    const AudioUnitElement element = 0;

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                                 sampleRate:sampleRate
                                                                   channels:channels
                                                                interleaved:NO];
    NSData *setData = [NSData dataWithBytes:format.streamDescription length:sizeof(AudioStreamBasicDescription)];
    YASRelease(format);

    YASAudioUnit *converterUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_FormatConverter subType:kAudioUnitSubType_AUConverter];

    XCTAssertNoThrow([converterUnit setPropertyData:setData propertyID:propertyID scope:scope element:element]);

    NSData *getData = nil;
    XCTAssertNoThrow(getData = [converterUnit propertyDataWithPropertyID:propertyID scope:scope element:element]);

    XCTAssertEqualObjects(setData, getData);

    YASRelease(converterUnit);
}

@end
