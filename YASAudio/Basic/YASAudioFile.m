//
//  YASAudioFile.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioFile.h"
#import "YASAudioFormat.h"
#import "YASAudioPCMBuffer.h"
#import "YASMacros.h"
#import "YASAudioTypes.h"
#import "YASAudioUtility.h"
#import "NSException+YASAudio.h"
#import "NSError+YASAudio.h"

NSString *const YASAudioFileType3GPP = @"public.3gpp";
NSString *const YASAudioFileType3GPP2 = @"public.3gpp2";
NSString *const YASAudioFileTypeAIFC = @"public.aifc-audio";
NSString *const YASAudioFileTypeAIFF = @"public.aiff-audio";
NSString *const YASAudioFileTypeAMR = @"org.3gpp.adaptive-multi-rate-audio";
NSString *const YASAudioFileTypeAC3 = @"public.ac3-audio";
NSString *const YASAudioFileTypeMPEGLayer3 = @"public.mp3";
NSString *const YASAudioFileTypeCoreAudioFormat = @"com.apple.coreaudio-format";
NSString *const YASAudioFileTypeMPEG4 = @"public.mpeg-4";
NSString *const YASAudioFileTypeAppleM4A = @"com.apple.m4a-audio";
NSString *const YASAudioFileTypeWAVE = @"com.microsoft.waveform-audio";

#pragma mark - C Utility Function

static Boolean YASOpenExtAudioFileWithFileURL(ExtAudioFileRef *extAudioFile, const NSURL *url)
{
    CFURLRef cfurl = CFBridgingRetain(url);
    OSStatus err = ExtAudioFileOpenURL(cfurl, extAudioFile);
    CFRelease(cfurl);
    return err == noErr;
}

static Boolean YASCreateExtAudioFileWithFileURL(ExtAudioFileRef *extAudioFile, const NSURL *url,
                                                const AudioFileTypeID fileType, const AudioStreamBasicDescription *asbd)
{
    CFURLRef cfurl = CFBridgingRetain(url);
    OSStatus err = ExtAudioFileCreateWithURL(cfurl, fileType, asbd, NULL, kAudioFileFlags_EraseFile, extAudioFile);
    CFRelease(cfurl);
    return err == noErr;
}

static Boolean YASDisposeExtAudioFile(const ExtAudioFileRef extAudioFile)
{
    OSStatus err = ExtAudioFileDispose(extAudioFile);
    return err == noErr;
}

static AudioFileTypeID YASGetAudioFileType(const AudioFileID fileID)
{
    UInt32 fileType;
    UInt32 size = sizeof(AudioFileTypeID);
    YASRaiseIfAUError(AudioFileGetProperty(fileID, kAudioFilePropertyFileFormat, &size, &fileType));
    return fileType;
}

static Boolean YASGetExtAudioFileFormat(AudioStreamBasicDescription *asbd, const ExtAudioFileRef extAudioFile)
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = noErr;
    YASRaiseIfAUError(err = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileDataFormat, &size, asbd));
    return err == noErr;
}

static Boolean YASSetClientFormat(const AudioStreamBasicDescription *asbd, const ExtAudioFileRef extAudioFile)
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = noErr;
    YASRaiseIfAUError(err = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ClientDataFormat, size, asbd));
    return err == noErr;
}

static SInt64 YASGetFileLengthFrames(const ExtAudioFileRef extAudioFile)
{
    SInt64 result = 0;
    UInt32 size = sizeof(SInt64);
    YASRaiseIfAUError(ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &result));
    return result;
}

static Boolean YASOpenAudioFileWithFileURL(AudioFileID *fileID, const NSURL *url)
{
    CFURLRef cfurl = CFBridgingRetain(url);
    OSStatus err = AudioFileOpenURL(cfurl, kAudioFileReadPermission, kAudioFileWAVEType, fileID);
    CFRelease(cfurl);
    return err == noErr;
}

static Boolean YASCloseAudioFile(const AudioFileID fileID)
{
    OSStatus err = AudioFileClose(fileID);
    return err == noErr;
}

static Boolean YASGetAudioFileFormat(AudioStreamBasicDescription *asbd, const AudioFileID fileID)
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &size, asbd);
    return err == noErr;
}

static Boolean YASCanOpenAudioFile(const NSURL *url)
{
    Boolean result = true;
    AudioFileID fileID;
    AudioStreamBasicDescription asbd;
    if (YASOpenAudioFileWithFileURL(&fileID, url)) {
        if (!YASGetAudioFileFormat(&asbd, fileID)) {
            result = false;
        }
        YASCloseAudioFile(fileID);
    } else {
        result = false;
    }
    return result;
}

static AudioFileID YASGetAudioFileIDFromExtAudioFile(const ExtAudioFileRef extAudioFile)
{
    UInt32 size = sizeof(AudioFileID);
    AudioFileID audioFileID = 0;
    YASRaiseIfAUError(ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_AudioFile, &size, &audioFileID));
    return audioFileID;
}

static AudioFileTypeID YASAudioFileTypeIDFromFileType(NSString *fileType)
{
    if ([fileType isEqualToString:YASAudioFileType3GPP]) {
        return kAudioFile3GPType;
    } else if ([fileType isEqualToString:YASAudioFileType3GPP2]) {
        return kAudioFile3GP2Type;
    } else if ([fileType isEqualToString:YASAudioFileTypeAIFC]) {
        return kAudioFileAIFCType;
    } else if ([fileType isEqualToString:YASAudioFileTypeAIFF]) {
        return kAudioFileAIFFType;
    } else if ([fileType isEqualToString:YASAudioFileTypeAMR]) {
        return kAudioFileAMRType;
    } else if ([fileType isEqualToString:YASAudioFileTypeAC3]) {
        return kAudioFileAC3Type;
    } else if ([fileType isEqualToString:YASAudioFileTypeMPEGLayer3]) {
        return kAudioFileMP3Type;
    } else if ([fileType isEqualToString:YASAudioFileTypeCoreAudioFormat]) {
        return kAudioFileCAFType;
    } else if ([fileType isEqualToString:YASAudioFileTypeMPEG4]) {
        return kAudioFileMPEG4Type;
    } else if ([fileType isEqualToString:YASAudioFileTypeAppleM4A]) {
        return kAudioFileM4AType;
    } else if ([fileType isEqualToString:YASAudioFileTypeWAVE]) {
        return kAudioFileWAVEType;
    }
    return 0;
}

static NSString *YASFileTypeFromAudioFileTypeID(AudioFileTypeID fileTypeID)
{
    switch (fileTypeID) {
        case kAudioFile3GPType:
            return YASAudioFileType3GPP;
            break;
        case kAudioFile3GP2Type:
            return YASAudioFileType3GPP2;
            break;
        case kAudioFileAIFCType:
            return YASAudioFileTypeAIFC;
            break;
        case kAudioFileAIFFType:
            return YASAudioFileTypeAIFF;
            break;
        case kAudioFileAMRType:
            return YASAudioFileTypeAMR;
            break;
        case kAudioFileAC3Type:
            return YASAudioFileTypeAC3;
            break;
        case kAudioFileMP3Type:
            return YASAudioFileTypeMPEGLayer3;
            break;
        case kAudioFileCAFType:
            return YASAudioFileTypeCoreAudioFormat;
            break;
        case kAudioFileMPEG4Type:
            return YASAudioFileTypeMPEG4;
            break;
        case kAudioFileM4AType:
            return YASAudioFileTypeAppleM4A;
            break;
        case kAudioFileWAVEType:
            return YASAudioFileTypeWAVE;
            break;
        default:
            break;
    }
    return nil;
}

#pragma mark - YASAudioFile

@interface YASAudioFile ()

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) YASAudioFormat *fileFormat;
@property (nonatomic, copy) NSString *fileType;
@property (nonatomic, assign) ExtAudioFileRef extAudioFile;

@end

@implementation YASAudioFile {
    SInt64 _fileFramePosition;
}

- (void)dealloc
{
    [self _close];

    YASRelease(_url);
    YASRelease(_fileFormat);
    YASRelease(_processingFormat);
    YASRelease(_fileType);

    _url = nil;
    _fileFormat = nil;
    _processingFormat = nil;
    _fileType = nil;

    YASSuperDealloc;
}

- (SInt64)fileLength
{
    NSAssert(_extAudioFile, nil);
    return YASGetFileLengthFrames(_extAudioFile);
}

- (SInt64)processingLength
{
    const SInt64 fileLength = self.fileLength;
    const Float64 processingPerFileRate =
        _processingFormat.streamDescription->mSampleRate / _fileFormat.streamDescription->mSampleRate;
    return fileLength * processingPerFileRate;
}

- (UInt32)fileFramePosition
{
    return (UInt32)_fileFramePosition;
}

- (void)setFileFramePosition:(UInt32)fileFramePosition
{
    if (_fileFramePosition != fileFramePosition) {
        OSStatus err = ExtAudioFileSeek(_extAudioFile, fileFramePosition);
        if (err == noErr) {
            _fileFramePosition = fileFramePosition;
        }
    }
}

- (void)setProcessingFormat:(YASAudioFormat *)processingFormat
{
    if (processingFormat != _processingFormat) {
        YASRelease(_processingFormat);
        _processingFormat = YASRetain(processingFormat);
        YASSetClientFormat(processingFormat.streamDescription, _extAudioFile);
    }
}

- (SInt64 *)fileFramePositionPointer
{
    return &_fileFramePosition;
}

#pragma mark Private

- (BOOL)_openWithBitDepthFormat:(YASAudioBitDepthFormat)bitDepthFormat interleaved:(BOOL)interleaved
{
    if (!YASCanOpenAudioFile(_url)) {
        return NO;
    }

    if (!YASOpenExtAudioFileWithFileURL(&_extAudioFile, _url)) {
        _extAudioFile = NULL;
        return NO;
    };

    AudioStreamBasicDescription asbd;
    if (!YASGetExtAudioFileFormat(&asbd, _extAudioFile)) {
        [self _close];
        return NO;
    }

    AudioFileID audioFileID = YASGetAudioFileIDFromExtAudioFile(_extAudioFile);
    AudioFileTypeID audioFileTypeID = YASGetAudioFileType(audioFileID);
    self.fileType = YASFileTypeFromAudioFileTypeID(audioFileTypeID);
    if (!_fileType) {
        [self _close];
        return NO;
    }

    YASAudioFormat *fileFormat = [[YASAudioFormat alloc] initWithStreamDescription:&asbd];
    self.fileFormat = fileFormat;
    YASRelease(fileFormat);

    YASAudioFormat *processingFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                           sampleRate:fileFormat.sampleRate
                                                                             channels:fileFormat.channelCount
                                                                          interleaved:interleaved];
    self.processingFormat = processingFormat;
    YASRelease(processingFormat);

    if (!YASSetClientFormat(_processingFormat.streamDescription, _extAudioFile)) {
        [self _close];
        return NO;
    }

    return YES;
}

- (BOOL)_createWithSettings:(NSDictionary *)settings
             bitDepthFormat:(YASAudioBitDepthFormat)bitDepthFormat
                interleaved:(BOOL)interleaved
{
    YASAudioFormat *fileFormat = [[YASAudioFormat alloc] initWithSettings:settings];
    self.fileFormat = fileFormat;
    YASRelease(fileFormat);

    AudioFileTypeID fileTypeID = YASAudioFileTypeIDFromFileType(_fileType);
    if (!fileTypeID) {
        return NO;
    }

    if (!YASCreateExtAudioFileWithFileURL(&_extAudioFile, _url, fileTypeID, _fileFormat.streamDescription)) {
        _extAudioFile = NULL;
        return NO;
    }

    YASAudioFormat *processingFormat = [[YASAudioFormat alloc] initWithBitDepthFormat:bitDepthFormat
                                                                           sampleRate:fileFormat.sampleRate
                                                                             channels:fileFormat.channelCount
                                                                          interleaved:interleaved];
    self.processingFormat = processingFormat;
    YASRelease(processingFormat);

    if (!YASSetClientFormat(_processingFormat.streamDescription, _extAudioFile)) {
        [self _close];
        return NO;
    }

    return YES;
}

- (void)_close
{
    YASDisposeExtAudioFile(_extAudioFile);
    _extAudioFile = NULL;
}

#pragma mark - Tests

+ (AudioFileTypeID)_audioFileTypeIDFromFileType:(NSString *)fileType
{
    return YASAudioFileTypeIDFromFileType(fileType);
}

+ (NSString *)_fileTypeFromAudioFileTypeID:(AudioFileTypeID)fileTypeID
{
    return YASFileTypeFromAudioFileTypeID(fileTypeID);
}

@end

#pragma mark - YASAudioFileReader

@implementation YASAudioFileReader

- (instancetype)initWithURL:(NSURL *)fileURL error:(NSError **)outError
{
    return [self initWithURL:fileURL bitDepthFormat:YASAudioBitDepthFormatFloat32 interleaved:NO error:outError];
}

- (instancetype)initWithURL:(NSURL *)fileURL
             bitDepthFormat:(YASAudioBitDepthFormat)format
                interleaved:(BOOL)interleaved
                      error:(NSError **)outError
{
    self = [super init];
    if (self) {
        if (!fileURL) {
            [NSError yas_error:outError code:YASAudioFileErrorCodeArgumentIsNil];
            YASRelease(self);
            return nil;
        }
        self.url = fileURL;
        if (![self _openWithBitDepthFormat:format interleaved:interleaved]) {
            [NSError yas_error:outError code:YASAudioFileErrorCodeNotOpen];
            YASRelease(self);
            return nil;
        }
    }
    return self;
}

- (BOOL)readIntoBuffer:(YASAudioPCMBuffer *)buffer error:(NSError **)outError
{
    return [self readIntoBuffer:buffer frameLength:buffer.frameCapacity error:outError];
}

- (BOOL)readIntoBuffer:(YASAudioPCMBuffer *)buffer frameLength:(const UInt32)frameLength error:(NSError **)outError
{
    if (![buffer.format isEqualToAudioFormat:self.processingFormat]) {
        [NSError yas_error:outError code:YASAudioFileErrorCodeInvalidFormat];
        return NO;
    }

    OSStatus err = noErr;
    UInt32 outFrameLength = 0;
    UInt32 remainFrames = frameLength;

    AudioBufferList *ioBufferList = YASAudioAllocateAudioBufferListWithoutData(buffer.bufferCount, 0);

    while (remainFrames) {
        UInt32 bytesPerFrame = buffer.format.streamDescription->mBytesPerFrame;
        UInt32 dataByteSize = remainFrames * bytesPerFrame;
        UInt32 dataIndex = outFrameLength * bytesPerFrame;

        for (NSInteger i = 0; i < buffer.bufferCount; i++) {
            AudioBuffer *audioBuffer = &ioBufferList->mBuffers[i];
            audioBuffer->mNumberChannels = buffer.stride;
            audioBuffer->mDataByteSize = dataByteSize;
            audioBuffer->mData = &buffer.audioBufferList->mBuffers[i].mData[dataIndex];
        }

        UInt32 ioFrames = remainFrames;

        err = ExtAudioFileRead(self.extAudioFile, &ioFrames, ioBufferList);
        if (err != noErr) {
            [NSError yas_error:outError code:YASAudioFileErrorCodeReadFailed audioErrorCode:err];
            break;
        }

        if (!ioFrames) {
            break;
        }
        remainFrames -= ioFrames;
        outFrameLength += ioFrames;
    }

    free(ioBufferList);

    buffer.frameLength = outFrameLength;

    if (err == noErr) {
        err = ExtAudioFileTell(self.extAudioFile, self.fileFramePositionPointer);
        if (err != noErr) {
            [NSError yas_error:outError code:YASAudioFileErrorCodeTellFailed audioErrorCode:err];
        }
    }

    return err == noErr;
}

@end

#pragma mark - YASAudioFileWriter

@implementation YASAudioFileWriter

- (instancetype)initWithURL:(NSURL *)fileURL
                   fileType:(NSString *)fileType
                   settings:(NSDictionary *)settings
                      error:(NSError **)outError
{
    return [self initWithURL:fileURL
                    fileType:fileType
                    settings:settings
              bitDepthFormat:YASAudioBitDepthFormatFloat32
                 interleaved:NO
                       error:outError];
}

- (instancetype)initWithURL:(NSURL *)fileURL
                   fileType:(NSString *)fileType
                   settings:(NSDictionary *)settings
             bitDepthFormat:(YASAudioBitDepthFormat)format
                interleaved:(BOOL)interleaved
                      error:(NSError **)outError
{
    self = [super init];
    if (self) {
        if (!fileURL || !fileType || !settings) {
            [NSError yas_error:outError code:YASAudioFileErrorCodeArgumentIsNil];
            YASRelease(self);
            return nil;
        }
        self.url = fileURL;
        self.fileType = fileType;
        if (![self _createWithSettings:settings bitDepthFormat:format interleaved:interleaved]) {
            [NSError yas_error:outError code:YASAudioFileErrorCodeNotCreate];
            YASRelease(self);
            return nil;
        }
    }
    return self;
}

- (BOOL)writeSyncFromBuffer:(YASAudioPCMBuffer *)buffer error:(NSError **)outError
{
    return [self _writeFromBuffer:buffer isAsync:NO error:outError];
}

- (BOOL)writeAsyncFromBuffer:(YASAudioPCMBuffer *)buffer error:(NSError **)outError
{
    return [self _writeFromBuffer:buffer isAsync:YES error:outError];
}

- (BOOL)_writeFromBuffer:(YASAudioPCMBuffer *)buffer isAsync:(BOOL)isAsync error:(NSError **)outError
{
    if (![buffer.format isEqualToAudioFormat:self.processingFormat]) {
        [NSError yas_error:outError code:YASAudioFileErrorCodeInvalidFormat];
        return NO;
    }

    OSStatus err = noErr;

    if (isAsync) {
        err = ExtAudioFileWriteAsync(self.extAudioFile, buffer.frameLength, buffer.audioBufferList);
    } else {
        err = ExtAudioFileWrite(self.extAudioFile, buffer.frameLength, buffer.audioBufferList);
    }

    if (err != noErr) {
        [NSError yas_error:outError code:YASAudioFileErrorCodeWriteFailed audioErrorCode:err];
    }

    if (err == noErr) {
        err = ExtAudioFileTell(self.extAudioFile, self.fileFramePositionPointer);
        if (err != noErr) {
            [NSError yas_error:outError code:YASAudioFileErrorCodeTellFailed audioErrorCode:err];
        }
    }

    return err == noErr;
}

@end

#pragma mark - NSDictionary Category

@implementation NSDictionary (YASAudioFile)

+ (NSDictionary *)yas_waveFileSettingsWithSampleRate:(Float64)sampleRate
                                    numberOfChannels:(UInt32)channels
                                            bitDepth:(UInt32)bitDepth
{
    return [self yas_linearPCMSettingsWithSampleRate:sampleRate
                                    numberOfChannels:channels
                                            bitDepth:bitDepth
                                         isBigEndian:NO
                                             isFloat:bitDepth >= 32
                                    isNonInterleaved:NO];
}

+ (NSDictionary *)yas_aiffFileSettingsWithSampleRate:(Float64)sampleRate
                                    numberOfChannels:(UInt32)channels
                                            bitDepth:(UInt32)bitDepth
{
    return [self yas_linearPCMSettingsWithSampleRate:sampleRate
                                    numberOfChannels:channels
                                            bitDepth:bitDepth
                                         isBigEndian:YES
                                             isFloat:bitDepth >= 32
                                    isNonInterleaved:NO];
}

+ (NSDictionary *)yas_linearPCMSettingsWithSampleRate:(Float64)sampleRate
                                     numberOfChannels:(UInt32)channels
                                             bitDepth:(UInt32)bitDepth
                                          isBigEndian:(BOOL)isBigEndian
                                              isFloat:(BOOL)isFloat
                                     isNonInterleaved:(BOOL)isNonInterleaved
{
    return @{
        AVFormatIDKey : @(kAudioFormatLinearPCM),
        AVSampleRateKey : @(sampleRate),
        AVNumberOfChannelsKey : @(channels),
        AVLinearPCMBitDepthKey : @(bitDepth),
        AVLinearPCMIsBigEndianKey : @(isBigEndian),
        AVLinearPCMIsFloatKey : @(isFloat),
        AVLinearPCMIsNonInterleaved : @(isNonInterleaved),
        AVChannelLayoutKey : [NSData data]
    };
}

+ (NSDictionary *)yas_aacSettingsWithSampleRate:(Float64)sampleRate
                               numberOfChannels:(UInt32)channels
                                       bitDepth:(UInt32)bitDepth
                                encoderQuallity:(AVAudioQuality)encoderQuality
                                 encoderBitRate:(UInt32)bitRate
                            encoderBitDepthHint:(UInt32)bitDepthHint
                     sampleRateConverterQuality:(AVAudioQuality)converterQuality
{
    return @{
        AVFormatIDKey : @(kAudioFormatMPEG4AAC),
        AVSampleRateKey : @(sampleRate),
        AVNumberOfChannelsKey : @(channels),
        AVLinearPCMBitDepthKey : @(bitDepth),
        AVLinearPCMIsBigEndianKey : @(NO),
        AVLinearPCMIsFloatKey : @(NO),
        AVEncoderAudioQualityKey : @(encoderQuality),
        AVEncoderBitRateKey : @(bitRate),
        AVEncoderBitDepthHintKey : @(bitDepthHint),
        AVSampleRateConverterAudioQualityKey : @(converterQuality)
    };
}

@end
