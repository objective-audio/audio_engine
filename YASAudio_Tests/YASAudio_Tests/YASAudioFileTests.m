//
//  YASAudioFileTests.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <XCTest/XCTest.h>
#import "YASAudio.h"

@interface YASAudioFile (YASAudioFileTests)

+ (AudioFileTypeID)_audioFileTypeIDFromFileType:(NSString *)fileType;
+ (NSString *)_fileTypeFromAudioFileTypeID:(AudioFileTypeID)fileTypeID;

@end

@interface YASAudioFileTestData : NSObject

@property (nonatomic) Float64 fileSampleRate;
@property (nonatomic) Float64 processingSampleRate;
@property (nonatomic) UInt32 channels;
@property (nonatomic) UInt32 fileBitDepth;
@property (nonatomic, copy) NSString *fileType;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic) UInt32 frameLength;
@property (nonatomic) UInt32 loopCount;
@property (nonatomic) YASAudioBitDepthFormat bitDepthFormat;
@property (nonatomic) BOOL interleaved;
@property (nonatomic, readonly) NSDictionary *settings;
@property (nonatomic) BOOL standard;

@end

@implementation YASAudioFileTestData

- (NSDictionary *)settings
{
    if ([_fileType isEqualToString:YASAudioFileTypeWAVE]) {
        return [NSDictionary yas_waveFileSettingsWithSampleRate:_fileSampleRate
                                               numberOfChannels:_channels
                                                       bitDepth:_fileBitDepth];
    } else if ([_fileType isEqualToString:YASAudioFileTypeAIFF]) {
        return [NSDictionary yas_aiffFileSettingsWithSampleRate:_fileSampleRate
                                               numberOfChannels:_channels
                                                       bitDepth:_fileBitDepth];
    }
    return nil;
}

- (void)dealloc
{
    YASRelease(_fileType);
    YASRelease(_fileName);
    YASSuperDealloc;
}

@end

@interface YASAudioFileTests : XCTestCase

@end

@implementation YASAudioFileTests

- (NSString *)temporaryTestDirectory
{
    return [NSTemporaryDirectory() stringByAppendingPathComponent:@"yas_audio_test_files"];
}

- (void)setupDirectory
{
    [self removeAllFiles];

    NSString *path = [self temporaryTestDirectory];

    NSFileManager *fileManager = [[NSFileManager alloc] init];

    [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];

    YASRelease(fileManager);
}

- (void)removeAllFiles
{
    NSString *path = [self temporaryTestDirectory];

    NSFileManager *fileManager = [[NSFileManager alloc] init];

    for (NSString *fileName in [fileManager contentsOfDirectoryAtPath:path error:nil]) {
        NSString *fullPath = [path stringByAppendingPathComponent:fileName];
        [fileManager removeItemAtPath:fullPath error:nil];
    }

    [fileManager removeItemAtPath:path error:nil];

    YASRelease(fileManager);
}

- (void)setUp
{
    [super setUp];
    [self setupDirectory];
}

- (void)tearDown
{
    [self removeAllFiles];
    [super tearDown];
}

- (void)testWAVEFile
{
#if WAVEFILE_LIGHT_TEST
    NSArray *sampleRates = @[@(44100.0), @(382000.0)];
    NSArray *channels = @[@(1), @(2)];
    NSArray *fileBitDepths = @[@(16), @(24)];
    NSArray *bitDepthFormats = @[@(YASAudioBitDepthFormatFloat32), @(YASAudioBitDepthFormatInt16)];
    NSArray *interleaveds = @[@(YES), @(NO)];
#else
    NSArray *sampleRates = @[@(8000.0), @(44100.0), @(48000.0), @(382000.0)];
    NSArray *channels = @[@(1), @(2), @(3), @(6)];
    NSArray *fileBitDepths = @[@(16), @(24), @(32)];
    NSArray *bitDepthFormats = @[
        @(YASAudioBitDepthFormatFloat32),
        @(YASAudioBitDepthFormatFloat64),
        @(YASAudioBitDepthFormatInt16),
        @(YASAudioBitDepthFormatFixed824)
    ];
    NSArray *interleaveds = @[@(YES), @(NO)];
#endif

    YASAudioFileTestData *testData = [[YASAudioFileTestData alloc] init];
    testData.frameLength = 8;
    testData.loopCount = 4;
    testData.fileName = @"test.wav";
    testData.fileType = YASAudioFileTypeWAVE;
    testData.standard = NO;

    for (NSNumber *fileSampleRate in sampleRates) {
        for (NSNumber *processingSampleRate in sampleRates) {
            for (NSNumber *channel in channels) {
                for (NSNumber *fileBitDepth in fileBitDepths) {
                    for (NSNumber *bitDepthFormat in bitDepthFormats) {
                        for (NSNumber *interleved in interleaveds) {
                            testData.fileSampleRate = fileSampleRate.doubleValue;
                            testData.channels = channel.unsignedIntValue;
                            testData.fileBitDepth = fileBitDepth.unsignedIntValue;
                            testData.processingSampleRate = processingSampleRate.doubleValue;
                            testData.bitDepthFormat = bitDepthFormat.unsignedIntValue;
                            testData.interleaved = interleved.boolValue;
                            @autoreleasepool
                            {
                                [self _commonAudioFileTest:testData isWriteAsync:NO];
                            }
                        }
                    }
                }
            }
        }
    }

    testData.standard = YES;
    testData.fileSampleRate = 48000;
    testData.channels = 2;
    testData.fileBitDepth = 32;
    testData.processingSampleRate = 44100;
    testData.bitDepthFormat = YASAudioBitDepthFormatFloat32;
    testData.interleaved = NO;

    [self _commonAudioFileTest:testData isWriteAsync:NO];
#if !WAVEFILE_LIGHT_TEST
    [self _commonAudioFileTest:testData isWriteAsync:YES];
#endif

    YASRelease(testData);
}

- (void)testWaveFileSettingsInt16
{
    const Float64 sampleRate = 44100;
    const UInt32 channels = 2;
    const UInt32 bitDepth = 16;

    NSDictionary *settings =
        [NSDictionary yas_waveFileSettingsWithSampleRate:sampleRate numberOfChannels:channels bitDepth:bitDepth];

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testWaveFileSettingsFloat32
{
    const Float64 sampleRate = 48000;
    const UInt32 channels = 4;
    const UInt32 bitDepth = 32;

    NSDictionary *settings =
        [NSDictionary yas_waveFileSettingsWithSampleRate:sampleRate numberOfChannels:channels bitDepth:bitDepth];

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAIFFSettingsInt16
{
    const Float64 sampleRate = 32000;
    const UInt32 channels = 2;
    const UInt32 bitDepth = 16;

    NSDictionary *settings =
        [NSDictionary yas_aiffFileSettingsWithSampleRate:sampleRate numberOfChannels:channels bitDepth:bitDepth];

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAIFFSettingsFloat32
{
    const Float64 sampleRate = 96000;
    const UInt32 channels = 3;
    const UInt32 bitDepth = 32;

    NSDictionary *settings =
        [NSDictionary yas_aiffFileSettingsWithSampleRate:sampleRate numberOfChannels:channels bitDepth:bitDepth];

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatLinearPCM));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));
    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(YES));
    XCTAssertEqualObjects(settings[AVLinearPCMIsNonInterleaved], @(NO));
    XCTAssertNotNil(settings[AVChannelLayoutKey]);
}

- (void)testAACSettings
{
    const Float64 sampleRate = 48000;
    const UInt32 channels = 2;
    const UInt32 bitDepth = 16;
    const AVAudioQuality encoderQuality = AVAudioQualityMedium;
    const UInt32 bitRate = 128000;
    const UInt32 bitDepthHint = 16;
    const AVAudioQuality converterQuality = AVAudioQualityMax;

    NSDictionary *settings = [NSDictionary yas_aacSettingsWithSampleRate:sampleRate
                                                        numberOfChannels:channels
                                                                bitDepth:bitDepth
                                                         encoderQuallity:encoderQuality
                                                          encoderBitRate:bitRate
                                                     encoderBitDepthHint:bitDepthHint
                                              sampleRateConverterQuality:converterQuality];

    XCTAssertEqualObjects(settings[AVFormatIDKey], @(kAudioFormatMPEG4AAC));
    XCTAssertEqualObjects(settings[AVSampleRateKey], @(sampleRate));

    XCTAssertEqualObjects(settings[AVNumberOfChannelsKey], @(channels));
    XCTAssertEqualObjects(settings[AVLinearPCMBitDepthKey], @(bitDepth));
    XCTAssertEqualObjects(settings[AVLinearPCMIsBigEndianKey], @(NO));
    XCTAssertEqualObjects(settings[AVLinearPCMIsFloatKey], @(NO));
    XCTAssertEqualObjects(settings[AVEncoderAudioQualityKey], @(encoderQuality));
    XCTAssertEqualObjects(settings[AVEncoderBitRateKey], @(bitRate));
    XCTAssertEqualObjects(settings[AVEncoderBitDepthHintKey], @(bitDepthHint));
    XCTAssertEqualObjects(settings[AVSampleRateConverterAudioQualityKey], @(converterQuality));
}

- (void)testAudioFileTypeIDFromFileType
{
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileType3GPP], kAudioFile3GPType);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileType3GPP2], kAudioFile3GP2Type);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeAIFC], kAudioFileAIFCType);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeAIFF], kAudioFileAIFFType);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeAMR], kAudioFileAMRType);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeAC3], kAudioFileAC3Type);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeMPEGLayer3], kAudioFileMP3Type);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeCoreAudioFormat], kAudioFileCAFType);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeMPEG4], kAudioFileMPEG4Type);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeAppleM4A], kAudioFileM4AType);
    XCTAssertEqual([YASAudioFile _audioFileTypeIDFromFileType:YASAudioFileTypeWAVE], kAudioFileWAVEType);
}

- (void)testFileTypeFromAudioFileTypeID
{
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFile3GPType], YASAudioFileType3GPP);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFile3GP2Type], YASAudioFileType3GPP2);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileAIFCType], YASAudioFileTypeAIFC);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileAIFFType], YASAudioFileTypeAIFF);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileAMRType], YASAudioFileTypeAMR);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileAC3Type], YASAudioFileTypeAC3);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileMP3Type], YASAudioFileTypeMPEGLayer3);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileCAFType],
                          YASAudioFileTypeCoreAudioFormat);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileMPEG4Type], YASAudioFileTypeMPEG4);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileM4AType], YASAudioFileTypeAppleM4A);
    XCTAssertEqualObjects([YASAudioFile _fileTypeFromAudioFileTypeID:kAudioFileWAVEType], YASAudioFileTypeWAVE);

    XCTAssertNil([YASAudioFile _fileTypeFromAudioFileTypeID:0]);
}

- (void)testCreateFailed
{
    NSError *error = nil;

    XCTAssertNil([[YASAudioFileReader alloc] initWithURL:nil
                                          bitDepthFormat:YASAudioBitDepthFormatFloat32
                                             interleaved:YES
                                                   error:&error]);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, YASAudioFileErrorCodeArgumentIsNil);

    const Float64 sampleRate = 48000;
    const UInt32 channels = 2;
    const UInt32 bitDepth = 32;
    const YASAudioBitDepthFormat bitDepthFormat = YASAudioBitDepthFormatFloat32;
    const BOOL interleaved = YES;
    NSString *fileName = @"test.wav";
    NSString *filePath = [[self temporaryTestDirectory] stringByAppendingPathComponent:fileName];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    NSString *fileType = YASAudioFileTypeWAVE;
    NSDictionary *settings =
        [NSDictionary yas_waveFileSettingsWithSampleRate:sampleRate numberOfChannels:channels bitDepth:bitDepth];

    XCTAssertNil([[YASAudioFileWriter alloc] initWithURL:nil
                                                fileType:fileType
                                                settings:settings
                                          bitDepthFormat:bitDepthFormat
                                             interleaved:interleaved
                                                   error:nil]);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, YASAudioFileErrorCodeArgumentIsNil);

    XCTAssertNil([[YASAudioFileWriter alloc] initWithURL:fileURL
                                                fileType:nil
                                                settings:settings
                                          bitDepthFormat:bitDepthFormat
                                             interleaved:interleaved
                                                   error:nil]);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, YASAudioFileErrorCodeArgumentIsNil);

    XCTAssertNil([[YASAudioFileWriter alloc] initWithURL:fileURL
                                                fileType:fileType
                                                settings:nil
                                          bitDepthFormat:bitDepthFormat
                                             interleaved:interleaved
                                                   error:nil]);
    XCTAssertNotNil(error);
    XCTAssertEqual(error.code, YASAudioFileErrorCodeArgumentIsNil);
}

#pragma mark -

- (void)_commonAudioFileTest:(YASAudioFileTestData *)testData isWriteAsync:(BOOL)isWriteAsync
{
    NSError *error = nil;

    const BOOL standard = testData.standard;
    const UInt32 channels = testData.channels;
    NSString *fileType = testData.fileType;
    NSString *fileName = testData.fileName;
    NSString *filePath = [[self temporaryTestDirectory] stringByAppendingPathComponent:fileName];
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    const UInt32 frameLength = testData.frameLength;
    const UInt32 loopCount = testData.loopCount;
    const Float64 fileSampleRate = testData.fileSampleRate;
    const Float64 processingSampleRate = testData.processingSampleRate;
    const YASAudioBitDepthFormat bitDepthFormat = testData.bitDepthFormat;
    const BOOL interleaved = testData.interleaved;
    NSDictionary *settings = testData.settings;

    YASAudioFormat *defaultProcessingFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                                  sampleRate:fileSampleRate
                                                                                    channels:channels
                                                                                 interleaved:interleaved];

    YASAudioFormat *processingFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                           sampleRate:processingSampleRate
                                                                             channels:channels
                                                                          interleaved:interleaved];

    XCTAssertNotNil(defaultProcessingFormat);
    XCTAssertNotNil(processingFormat);

    // write

    @autoreleasepool
    {
        YASAudioFileWriter *audioFile = nil;

        if (standard) {
            audioFile =
                [[YASAudioFileWriter alloc] initWithURL:fileURL fileType:fileType settings:settings error:&error];
        } else {
            audioFile = [[YASAudioFileWriter alloc] initWithURL:fileURL
                                                       fileType:fileType
                                                       settings:settings
                                                 bitDepthFormat:bitDepthFormat
                                                    interleaved:interleaved
                                                          error:&error];
        }

        XCTAssertNotNil(audioFile);
        XCTAssertNil(error);

        XCTAssertEqualObjects(audioFile.processingFormat, defaultProcessingFormat);

        audioFile.processingFormat = processingFormat;

        YASAudioData *data = [[YASAudioData alloc] initWithFormat:processingFormat frameCapacity:frameLength];

        UInt32 startIndex = 0;

        for (NSInteger i = 0; i < loopCount; i++) {
            [self _writeToData:data fileFormat:audioFile.fileFormat startIndex:startIndex];

            if (isWriteAsync) {
                XCTAssert([audioFile writeAsyncFromData:data error:&error]);
            } else {
                XCTAssert([audioFile writeSyncFromData:data error:&error]);
            }

            XCTAssertNil(error);

            startIndex += frameLength;
        }

        YASRelease(audioFile);
    }

    // read

    @autoreleasepool
    {
        YASAudioFileReader *audioFile = nil;

        if (standard) {
            audioFile = [[YASAudioFileReader alloc] initWithURL:fileURL error:&error];
        } else {
            audioFile = [[YASAudioFileReader alloc] initWithURL:fileURL
                                                 bitDepthFormat:bitDepthFormat
                                                    interleaved:interleaved
                                                          error:&error];
        }

        XCTAssertNotNil(audioFile);
        XCTAssertNil(error);

        SInt64 loopedFrameLength = frameLength * loopCount;
        XCTAssertEqualWithAccuracy(audioFile.fileLength,
                                   (SInt64)(loopedFrameLength * (fileSampleRate / processingSampleRate)), 1);

        audioFile.processingFormat = processingFormat;

        XCTAssertEqualWithAccuracy(audioFile.processingLength,
                                   audioFile.fileLength * (processingSampleRate / fileSampleRate), 1);

        YASAudioData *data = [[YASAudioData alloc] initWithFormat:processingFormat frameCapacity:frameLength];

        UInt32 startIndex = 0;

        for (NSInteger i = 0; i < loopCount; i++) {
            XCTAssert([audioFile readIntoData:data error:&error]);
            XCTAssertNil(error);
            if (testData.fileSampleRate == testData.processingSampleRate) {
                XCTAssert(data.frameLength == frameLength);
                XCTAssert([self _compareData:data fileFormat:audioFile.fileFormat startIndex:startIndex],
                          @"sampleRate: %@ - bitDepthFormat: %@", @(processingSampleRate), @(bitDepthFormat));
            }

            startIndex += frameLength;
        }

        YASRelease(data);

        audioFile.fileFramePosition = 0;
        XCTAssertEqual(audioFile.fileFramePosition, 0);

        YASRelease(audioFile);
    }

    YASRelease(defaultProcessingFormat);
    YASRelease(processingFormat);
}

- (void)_writeToData:(YASAudioData *)data fileFormat:(YASAudioFormat *)fileFormat startIndex:(NSInteger)startIndex
{
    const UInt32 bufferCount = data.format.bufferCount;
    const UInt32 stride = data.format.stride;

    for (NSInteger bufIndex = 0; bufIndex < bufferCount; bufIndex++) {
        YASAudioMutablePointer pointer = [data pointerAtBuffer:bufIndex];
        for (NSInteger frameIndex = 0; frameIndex < data.frameLength; frameIndex++) {
            SInt16 value = frameIndex + startIndex + 1;
            for (NSInteger strideIndex = 0; strideIndex < stride; strideIndex++) {
                switch (data.format.bitDepthFormat) {
                    case YASAudioBitDepthFormatInt16: {
                        pointer.i16[frameIndex * stride + strideIndex] = value;
                    } break;
                    case YASAudioBitDepthFormatFixed824: {
                        pointer.i32[frameIndex * stride + strideIndex] = value << 16;
                    } break;
                    case YASAudioBitDepthFormatFloat32: {
                        Float32 float32Value = (Float32)value / INT16_MAX;
                        pointer.f32[frameIndex * stride + strideIndex] = float32Value;
                    } break;
                    case YASAudioBitDepthFormatFloat64: {
                        Float64 float64Value = (Float64)value / INT16_MAX;
                        pointer.f64[frameIndex * stride + strideIndex] = (Float64)float64Value;
                    } break;
                    default:
                        break;
                }
            }
        }
    }
}

- (BOOL)_compareData:(YASAudioData *)data fileFormat:(YASAudioFormat *)fileFormat startIndex:(NSInteger)startIndex
{
    const UInt32 bufferCount = data.format.bufferCount;
    const UInt32 stride = data.format.stride;

    for (NSInteger bufIndex = 0; bufIndex < bufferCount; bufIndex++) {
        const YASAudioMutablePointer pointer = [data pointerAtBuffer:bufIndex];
        for (NSInteger frameIndex = 0; frameIndex < data.frameLength; frameIndex++) {
            SInt16 value = frameIndex + startIndex + 1;
            for (NSInteger strideIndex = 0; strideIndex < stride; strideIndex++) {
                SInt16 ptrValue = 0;
                switch (data.format.bitDepthFormat) {
                    case YASAudioBitDepthFormatInt16: {
                        ptrValue = pointer.i16[frameIndex * stride + strideIndex];
                    } break;
                    case YASAudioBitDepthFormatFixed824: {
                        ptrValue = pointer.i32[frameIndex * stride + strideIndex] >> 16;
                    } break;
                    case YASAudioBitDepthFormatFloat32: {
                        ptrValue = roundf(pointer.f32[frameIndex * stride + strideIndex] * INT16_MAX);
                    } break;
                    case YASAudioBitDepthFormatFloat64: {
                        ptrValue = round(pointer.f64[frameIndex * stride + strideIndex] * INT16_MAX);
                    } break;
                    default:
                        break;
                }
                if (value != ptrValue) {
                    return NO;
                }
            }
        }
    }
    return YES;
}

@end
