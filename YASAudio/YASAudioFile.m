
/**
 *
 *  YASAudioFile.m
 *
 *  Created by Yuki Yasoshima
 *
 */

#import "YASAudioFile.h"
#import "YASAudioUtilities.h"

@implementation YASAudioFile {
    
    ExtAudioFileRef _extAudioFileRef;
    AudioFileID _audioFileID;
    AudioStreamBasicDescription _fileFormat;
    AudioStreamBasicDescription _clientFormat;
    double _filePerClientRate;
}

@dynamic fileFormat, clientFormat;

#pragma mark - ユーティリティ

static void GetDefaultWaveFileFormat(AudioStreamBasicDescription *format, UInt32 ch)
{
    format->mSampleRate = 44100.0;
    format->mFormatID = kAudioFormatLinearPCM;
    format->mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    format->mBitsPerChannel = 16;
    format->mChannelsPerFrame = ch;
    format->mFramesPerPacket = 1;
    format->mBytesPerFrame = format->mBitsPerChannel / 8 * format->mChannelsPerFrame;
    format->mBytesPerPacket = format->mBytesPerFrame;
}

static void GetDefaultClientFormat(AudioStreamBasicDescription *format, UInt32 ch)
{
    format->mSampleRate = 44100.0;
    format->mFormatID = kAudioFormatLinearPCM;
    format->mFormatFlags = kAudioFormatFlagsCanonical;
    format->mBitsPerChannel = 16;
    format->mChannelsPerFrame = ch;
    format->mFramesPerPacket = 1;
    format->mBytesPerFrame = format->mBitsPerChannel / 8 * format->mChannelsPerFrame;
    format->mBytesPerPacket = format->mBytesPerFrame;
}

static BOOL FillAudioFormat(AudioStreamBasicDescription *format, UInt32 formatID, Float64 sampleRate, UInt32 ch)
{
    format->mFormatID = formatID;
    format->mChannelsPerFrame = (formatID == kAudioFormatiLBC ? 1 : ch);
    format->mSampleRate = sampleRate;
    
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, format);
    YAS_Require_NoErr(err, bail);
    
bail:
    if (err != noErr) {
        return NO;
    }
    return YES;
}

static BOOL OpenExtAudioFileWithFileURL(ExtAudioFileRef *extAudioFile, NSURL *url)
{
    OSStatus err = ExtAudioFileOpenURL((CFURLRef)url, extAudioFile);
    YAS_Verify_NoErr(err);
    return (err == noErr) ? YES : NO;
}
/*
static BOOL OpenExtAudioFileWithPath(ExtAudioFileRef *extAudioFile, NSString *path)
{
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    BOOL result = OpenExtAudioFileWithFileURL(extAudioFile, url);
    [url release];
    return result;
}
*/
static BOOL CreateExtAudioFileWithFileURL(ExtAudioFileRef *extAudioFile, NSURL *url, AudioFileTypeID fileType, AudioStreamBasicDescription *format)
{
    OSStatus err = ExtAudioFileCreateWithURL((CFURLRef)url, fileType, format, NULL, kAudioFileFlags_EraseFile, extAudioFile);
    YAS_Verify_NoErr(err);
    return (err == noErr) ? YES : NO;
}

static BOOL DisposeExtAudioFile(ExtAudioFileRef extAudioFile)
{
    OSStatus err = ExtAudioFileDispose(extAudioFile);
    YAS_Verify_NoErr(err);
    return (err == noErr) ? YES : NO;
}

static AudioFileID GetAudioFileID(ExtAudioFileRef extAudioFile)
{
    AudioFileID fileID;
    UInt32 size = sizeof(AudioFileID);
    OSStatus err = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_AudioFile, &size, &fileID);
    YAS_Verify_NoErr(err);
    return fileID;
}

static BOOL OpenAudioFileWithFileURL(AudioFileID *fileID, NSURL *url)
{
    OSStatus err = AudioFileOpenURL((CFURLRef)url, kAudioFileReadPermission , kAudioFileWAVEType, fileID);
    YAS_Verify_NoErr(err);
    return (err == noErr) ? YES : NO;
}

static BOOL CloseAudioFile(AudioFileID fileID)
{
    OSStatus err = AudioFileClose(fileID);
    YAS_Verify_NoErr(err);
    return (err == noErr) ? YES : NO;
}

static AudioFileTypeID GetFileType(AudioFileID fileID)
{
    UInt32 fileType;
    UInt32 size = sizeof(AudioFileTypeID);
    OSStatus err = AudioFileGetProperty(fileID, kAudioFilePropertyFileFormat, &size, &fileType);
    YAS_Verify_NoErr(err);
    return fileType;
}
/*
static BOOL GetExtAudioFileFormat(AudioStreamBasicDescription *format, ExtAudioFileRef extAudioFile)
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileDataFormat, &size, format);
    YAS_Verify_NoErr(err);
    if (err != noErr) return NO;
    return YES;
}
*/
static BOOL GetAudioFileFormat(AudioStreamBasicDescription *format, AudioFileID fileID)
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = AudioFileGetProperty(fileID, kAudioFilePropertyDataFormat, &size, format);
    YAS_Verify_NoErr(err);
    if (err != noErr) return NO;
    return YES;
}

static BOOL SetClientFormat(AudioStreamBasicDescription *format, ExtAudioFileRef extAudioFile)
{
    UInt32 size = sizeof(AudioStreamBasicDescription);
    OSStatus err = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ClientDataFormat, size, format);
    YAS_Verify_NoErr(err);
    if (err != noErr) return NO;
    return YES;
}

static SInt64 GetFileLengthFrames(ExtAudioFileRef extAudioFile)
{
    SInt64 result = 0;
    UInt32 size = sizeof(SInt64);
    OSStatus err = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &result);
    YAS_Verify_NoErr(err);
    return result;
}

static NSDictionary *GetInfoDictionary(AudioFileID fileID)
{
    NSDictionary *dict;
    UInt32 size = sizeof(id);
    OSStatus err = AudioFileGetProperty(fileID, kAudioFilePropertyInfoDictionary, &size, &dict);
    YAS_Verify_NoErr(err);
    if (err != noErr) return nil;
    return [dict autorelease];
}

static BOOL CanOpenAudioFile(NSURL *url)
{
    BOOL result = YES;
    AudioFileID fileID;
    AudioStreamBasicDescription fileFormat;
    if (OpenAudioFileWithFileURL(&fileID, url)) {
        if (!GetAudioFileFormat(&fileFormat, fileID)) {
            result = NO;
        }
        CloseAudioFile(fileID);
    } else {
        result = NO;
    }
    
    return result;
}

+ (AudioFileMarkerList *)createMarkerList:(AudioFileID)fileID
{
    AudioFileMarkerList *list;
    UInt32 size;
    OSStatus err;
    
    err = AudioFileGetPropertyInfo(fileID, kAudioFilePropertyMarkerList, &size, NULL);
    YAS_Verify_NoErr(err);
    
    list = malloc(size);
    
    err = AudioFileGetProperty(fileID, kAudioFilePropertyMarkerList, &size, list);
    YAS_Verify_NoErr(err);
    
    return list;
}

+ (void)disposeMarkerList:(AudioFileMarkerList *)list
{
    UInt32 markers = list->mNumberMarkers;
    for (UInt32 i = 0; i < markers; i++) {
        CFRelease(list->mMarkers[i].mName);
    }
    free(list);
}

#pragma mark プライベート

- (void)_refreshTotalFrames
{
    _totalFrames = 0;
    
    SInt64 fileLengthFrames = GetFileLengthFrames(_extAudioFileRef);
    _filePerClientRate = _fileFormat.mSampleRate / _clientFormat.mSampleRate;
    _totalFrames = fileLengthFrames / _filePerClientRate;
}

- (void)_applyClientFormat
{
    SetClientFormat(&_clientFormat, _extAudioFileRef);
    [self _refreshTotalFrames];
}

#pragma mark メモリ管理

- (id)initWithPath:(NSString *)path
{
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    id result = [self initWithURL:url];
    [url release];
    
    return result;
}

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self != nil) {
        
        _url = [url retain];
        _extAudioFileRef = NULL;
        _fileType = kAudioFileWAVEType;
        GetDefaultWaveFileFormat(&_fileFormat, 2);
        GetDefaultClientFormat(&_clientFormat, 2);
    }
    
    return self;
}

- (id)init
{
    NSParameterAssert(0);
    return nil;
}

- (BOOL)open
{
    if (!CanOpenAudioFile(_url)) {
        return NO;
    }
    
    if (!OpenExtAudioFileWithFileURL(&_extAudioFileRef, _url)) {
		_extAudioFileRef = NULL;
		return NO;
	};
	
    _audioFileID = GetAudioFileID(_extAudioFileRef);
    
    GetFileType(_audioFileID);
    GetAudioFileFormat(&_fileFormat, _audioFileID);
    
    [self _applyClientFormat];
    
    return YES;
}

- (BOOL)create
{
    if (CreateExtAudioFileWithFileURL(&_extAudioFileRef, _url, _fileType, &_fileFormat)) {
        [self _applyClientFormat];
        return YES;
    } else {
        _extAudioFileRef = NULL;
        return NO;
    }
}

- (void)close
{
    DisposeExtAudioFile(_extAudioFileRef);
    _extAudioFileRef = NULL;
    _audioFileID = 0;
    _totalFrames = 0;
    _filePerClientRate = 0;
}

- (void) dealloc
{
    if (_extAudioFileRef) [self close];
    [_url release];
    [super dealloc];
}

#pragma mark アクセサ

- (void)setFileType:(AudioFileTypeID)type
{
    NSParameterAssert(!_extAudioFileRef);
    if (!_extAudioFileRef) {
        _fileType = type;
    }
}

- (void)setFileFormat:(AudioStreamBasicDescription *)format
{
    NSParameterAssert(!_extAudioFileRef);
    if (!_extAudioFileRef) {
        _fileFormat = *format;
    }
}

- (AudioStreamBasicDescription *)fileFormat
{
    return &_fileFormat;
}

- (void)setClientFormat:(AudioStreamBasicDescription *)format
{
    _clientFormat = *format;
    if (_extAudioFileRef) [self _applyClientFormat];
}

- (AudioStreamBasicDescription *)clientFormat
{
    return &_clientFormat;
}

- (NSString *)title
{
    NSString *title = nil;
    
    NSDictionary *infoDict = GetInfoDictionary(_audioFileID);
    if (infoDict != nil) {
        title = [infoDict objectForKey:@"title"];
    }
    
    if (title == nil) title = [[_url lastPathComponent] stringByDeletingPathExtension];
    
    return title;
}

- (NSDictionary *)infoDictionary
{
    return GetInfoDictionary(_audioFileID);
}

- (NSDictionary *)attributes
{
    NSError *error = nil;
    NSFileManager *fileManger = [NSFileManager defaultManager];
    NSDictionary *attributes = [fileManger attributesOfItemAtPath:[_url path] error:&error];
    NSAssert1(attributes, @"%@", error);
    return attributes;
}

- (void)setAndFillFileFormatWithFormatID:(UInt32)formatID sampleRate:(Float64)sampleRate channels:(UInt32)ch
{
    AudioStreamBasicDescription format = {0};
    FillAudioFormat(&format, formatID, sampleRate, ch);
    _fileFormat = format;
}

#pragma mark 位置

- (BOOL)seek:(SInt64)frame
{
    SInt64 filePos = frame * _filePerClientRate;
    OSStatus err = ExtAudioFileSeek(_extAudioFileRef, filePos);
    YAS_Verify_NoErr(err);
    return (err == noErr) ? YES : NO;
}

- (SInt64)tell
{
    SInt64 result = 0;
    OSStatus err = ExtAudioFileTell(_extAudioFileRef, &result);
    YAS_Verify_NoErr(err);
    result = result / _filePerClientRate;
    return result;
}

#pragma mark オーディオ読み書き

- (void)read:(void *)outBuffer ioFrames:(UInt32 *)ioFrames
{
    OSStatus err = noErr;
    UInt32 remainFrames = *ioFrames;
    AudioBufferList bufList;
    bufList.mNumberBuffers = 1;
    bufList.mBuffers[0].mNumberChannels = _clientFormat.mChannelsPerFrame;
    
    Byte *buf = outBuffer;
    UInt32 bufBytePerChannel = _clientFormat.mBitsPerChannel / 8;
    
    while (1) {
        
        UInt32 curBytePos = (*ioFrames - remainFrames) * _clientFormat.mChannelsPerFrame * bufBytePerChannel;
        bufList.mBuffers[0].mData = &buf[curBytePos];
        bufList.mBuffers[0].mDataByteSize = remainFrames * _clientFormat.mBytesPerFrame;
        
        UInt32 readFrames = remainFrames;
        err = ExtAudioFileRead(_extAudioFileRef, &readFrames, &bufList);
        YAS_Verify_NoErr(err);
        
        remainFrames -= readFrames;
		
		if (remainFrames == 0) {
			break;
		} else if (readFrames == 0) {
			if (_loop) {
				[self seek:0];
			} else {
				break;
			}
		}
    }
    
    if (remainFrames) {
        UInt32 curBytePos = (*ioFrames - remainFrames) * _clientFormat.mChannelsPerFrame * bufBytePerChannel;
        UInt32 clearByteCount = remainFrames * _clientFormat.mChannelsPerFrame;
        memset(&buf[curBytePos], 0, clearByteCount);
		*ioFrames -= remainFrames;
    }
}

- (void)readDirectLPCM16Bits:(SInt16 *)outBuffer ioFrames:(UInt32 *)ioFrames startFrame:(SInt64)startFrame
{
	UInt32 readBufferBytes = *ioFrames * _fileFormat.mBytesPerPacket;
	UInt32 outFrames = *ioFrames;
	OSStatus err = AudioFileReadPackets(_audioFileID, false, &readBufferBytes, NULL, startFrame, &outFrames, outBuffer);
	if (err != noErr) {
		*ioFrames = 0;
	} else {
		*ioFrames = outFrames;
		if (outFrames < *ioFrames) {
			UInt32 curBytePos = outFrames * _clientFormat.mChannelsPerFrame;
			UInt32 clearByteCount = (*ioFrames - outFrames) * _clientFormat.mChannelsPerFrame;
			memset(&outBuffer[curBytePos], 0, clearByteCount);
		}
	}
}

- (void)write:(void *)inBuffer frames:(UInt32)inFrames
{
    AudioBufferList bufList;
    bufList.mNumberBuffers = 1;
    bufList.mBuffers[0].mNumberChannels = _clientFormat.mChannelsPerFrame;
    bufList.mBuffers[0].mData = inBuffer;
    bufList.mBuffers[0].mDataByteSize = inFrames * _clientFormat.mBytesPerFrame;
    
    OSStatus err = ExtAudioFileWrite(_extAudioFileRef, inFrames, &bufList);
    YAS_Verify_NoErr(err);
}

@end
