//
//  YASAudioDevice.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "YASAudioDevice.h"
#import "YASAudioDeviceStream.h"
#import "YASAudioFormat.h"
#import "YASWeakSupport.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"
#import "NSString+YASAudio.h"

NSString *const YASAudioHardwareDidChangeNotification = @"YASAudioHardwareDidChangeNotification";
NSString *const YASAudioDeviceDidChangeNotification = @"YASAudioDeviceDidChangeNotificaiton";

NSString *const YASAudioDevicePropertiesKey = @"properties";
NSString *const YASAudioDeviceSelectorKey = @"selector";
NSString *const YASAudioDeviceScopeKey = @"scope";

static NSDictionary *_allDevices;
static NSArray *_outputDevices;
static NSArray *_inputDevices;
static __unsafe_unretained YASAudioDevice *_defaultSystemOutputDevice;
static __unsafe_unretained YASAudioDevice *_defaultOutputDevice;
static __unsafe_unretained YASAudioDevice *_defaultInputDevice;
static AudioObjectPropertyListenerBlock _globalListenerBlock;

@interface YASAudioDevice ()

@property (nonatomic, copy) AudioObjectPropertyListenerBlock listenerBlock;
@property (atomic, strong) YASAudioFormat *inputFormat;
@property (atomic, strong) YASAudioFormat *outputFormat;

@end

@implementation YASAudioDevice {
    NSDictionary *_inputStreams;
    NSDictionary *_outputStreams;
}

+ (void)initialize
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
      [self _updateAllDevices];
      [self _addNotificationWithSelector:kAudioHardwarePropertyDevices];
      [self _addNotificationWithSelector:kAudioHardwarePropertyDefaultSystemOutputDevice];
      [self _addNotificationWithSelector:kAudioHardwarePropertyDefaultOutputDevice];
      [self _addNotificationWithSelector:kAudioHardwarePropertyDefaultInputDevice];
    });
}

+ (NSArray *)allDevices
{
    return _allDevices.allValues;
}

+ (NSArray *)outputDevices
{
    return _outputDevices;
}

+ (NSArray *)inputDevices
{
    return _inputDevices;
}

+ (YASAudioDevice *)defaultSystemOutputDevice
{
    return _defaultSystemOutputDevice;
}

+ (YASAudioDevice *)defaultOutputDevice
{
    return _defaultOutputDevice;
}

+ (YASAudioDevice *)defaultInputDevice
{
    return _defaultInputDevice;
}

+ (YASAudioDevice *)deviceForID:(AudioDeviceID)audioDeviceID
{
    return _allDevices[@(audioDeviceID)];
}

+ (void)_updateAllDevices
{
    NSMutableDictionary *prevDevices = nil;

    if (_allDevices) {
        prevDevices = [_allDevices copy];
        YASRelease(_allDevices);
        _allDevices = nil;
    }

    YASRelease(_outputDevices);
    _outputDevices = nil;
    YASRelease(_inputDevices);
    _inputDevices = nil;

    @autoreleasepool
    {
        NSData *data = [self _dataWithSelector:kAudioHardwarePropertyDevices];
        if (data) {
            AudioDeviceID *audioDeviceIDs = (AudioDeviceID *)data.bytes;
            NSUInteger deviceCount = data.length / sizeof(AudioDeviceID);
            NSMutableDictionary *newDevices = [[NSMutableDictionary alloc] initWithCapacity:deviceCount];
            for (NSInteger i = 0; i < deviceCount; i++) {
                NSNumber *key = @(audioDeviceIDs[i]);
                YASAudioDevice *audioDevice = prevDevices[key];
                if (audioDevice) {
                    newDevices[key] = audioDevice;
                } else {
                    audioDevice = [[YASAudioDevice alloc] initWithAudioDeviceID:audioDeviceIDs[i]];
                    newDevices[key] = audioDevice;
                    YASRelease(audioDevice);
                }
            }
            _allDevices = newDevices;
        }

        _outputDevices = YASRetain([[self allDevices]
            filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"outputStreams.@count > 0"]]);
        _inputDevices = YASRetain([[self allDevices]
            filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"inputStreams.@count > 0"]]);
    }

    YASRelease(prevDevices);
    prevDevices = nil;

    [self _updateDefaultSystemOutputDevice];
    [self _updateDefaultOutputDevice];
    [self _updateDefaultInputDevice];
}

+ (void)_updateDefaultSystemOutputDevice
{
    _defaultSystemOutputDevice = nil;

    @autoreleasepool
    {
        NSData *data = [self _dataWithSelector:kAudioHardwarePropertyDefaultSystemOutputDevice];
        if (data) {
            AudioDeviceID *audioDeviceID = (AudioDeviceID *)data.bytes;
            for (YASAudioDevice *audioDevice in self.allDevices) {
                if (audioDevice.audioDeviceID == *audioDeviceID) {
                    _defaultSystemOutputDevice = audioDevice;
                    break;
                }
            }
        }
    }
}

+ (void)_updateDefaultOutputDevice
{
    _defaultOutputDevice = nil;

    @autoreleasepool
    {
        NSData *data = [self _dataWithSelector:kAudioHardwarePropertyDefaultOutputDevice];
        if (data) {
            AudioDeviceID *audioDeviceID = (AudioDeviceID *)data.bytes;
            for (YASAudioDevice *audioDevice in self.allDevices) {
                if (audioDevice.audioDeviceID == *audioDeviceID) {
                    _defaultOutputDevice = audioDevice;
                    break;
                }
            }
        }
    }
}

+ (void)_updateDefaultInputDevice
{
    _defaultInputDevice = nil;

    @autoreleasepool
    {
        NSData *data = [self _dataWithSelector:kAudioHardwarePropertyDefaultInputDevice];
        if (data) {
            AudioDeviceID *audioDeviceID = (AudioDeviceID *)data.bytes;
            for (YASAudioDevice *audioDevice in self.allDevices) {
                if (audioDevice.audioDeviceID == *audioDeviceID) {
                    _defaultInputDevice = audioDevice;
                    break;
                }
            }
        }
    }
}

+ (NSData *)_dataWithSelector:(AudioObjectPropertySelector)selector
{
    const AudioObjectPropertyAddress address = {.mSelector = selector,
                                                .mScope = kAudioObjectPropertyScopeGlobal,
                                                .mElement = kAudioObjectPropertyElementMaster};

    UInt32 size = 0;
    YASRaiseIfAUError(AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &address, 0, NULL, &size));

    if (size > 0) {
        NSMutableData *data = [NSMutableData dataWithLength:size];
        void *bytes = data.mutableBytes;
        YASRaiseIfAUError(AudioObjectGetPropertyData(kAudioObjectSystemObject, &address, 0, NULL, &size, bytes));
        return data;
    } else {
        return NULL;
    }
}

+ (void)_setupGlobalListnerBlock
{
    AudioObjectPropertyListenerBlock listenerBlock =
        ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses) {
          NSMutableArray *properties = [[NSMutableArray alloc] initWithCapacity:inNumberAddresses];
          for (NSInteger i = 0; i < inNumberAddresses; i++) {
              if (inAddresses[i].mSelector == kAudioHardwarePropertyDevices) {
                  [self _updateAllDevices];
              } else if (inAddresses[i].mSelector == kAudioHardwarePropertyDefaultSystemOutputDevice) {
                  [self _updateDefaultSystemOutputDevice];
              } else if (inAddresses[i].mSelector == kAudioHardwarePropertyDefaultOutputDevice) {
                  [self _updateDefaultOutputDevice];
              } else if (inAddresses[i].mSelector == kAudioHardwarePropertyDefaultInputDevice) {
                  [self _updateDefaultInputDevice];
              }
              [properties addObject:@{
                  YASAudioDeviceSelectorKey : [NSString yas_fileTypeStringWithHFSTypeCode:inAddresses[i].mSelector]
              }];
          }
          [[NSNotificationCenter defaultCenter] postNotificationName:YASAudioHardwareDidChangeNotification
                                                              object:nil
                                                            userInfo:@{YASAudioDevicePropertiesKey : properties}];
          YASRelease(properties);
        };
    _globalListenerBlock = [listenerBlock copy];
}

+ (void)_addNotificationWithSelector:(AudioObjectPropertySelector)selector
{
    if (!_globalListenerBlock) {
        [self _setupGlobalListnerBlock];
    }

    const AudioObjectPropertyAddress address = {.mSelector = selector,
                                                .mScope = kAudioObjectPropertyScopeGlobal,
                                                .mElement = kAudioObjectPropertyElementMaster};

    YASRaiseIfAUError(AudioObjectAddPropertyListenerBlock(kAudioObjectSystemObject, &address, dispatch_get_main_queue(),
                                                          _globalListenerBlock));
}

+ (void)_removeNotificationWithSelector:(AudioObjectPropertySelector)selector
{
    const AudioObjectPropertyAddress address = {.mSelector = selector,
                                                .mScope = kAudioObjectPropertyScopeGlobal,
                                                .mElement = kAudioObjectPropertyElementMaster};

    YASRaiseIfAUError(AudioObjectRemovePropertyListenerBlock(kAudioObjectSystemObject, &address,
                                                             dispatch_get_main_queue(), _globalListenerBlock));
}

#pragma mark -

- (instancetype)initWithAudioDeviceID:(AudioDeviceID)audioDeviceID
{
    self = [super init];
    if (self) {
        _audioDeviceID = audioDeviceID;

        [self _updateInputStreams];
        [self _updateOutputStreams];
        [self _updateFormatWithScope:kAudioObjectPropertyScopeInput];
        [self _updateFormatWithScope:kAudioObjectPropertyScopeOutput];

        [self _addNotificationWithSelector:kAudioDevicePropertyNominalSampleRate scope:kAudioObjectPropertyScopeGlobal];
        [self _addNotificationWithSelector:kAudioDevicePropertyStreams scope:kAudioObjectPropertyScopeInput];
        [self _addNotificationWithSelector:kAudioDevicePropertyStreams scope:kAudioObjectPropertyScopeOutput];
        [self _addNotificationWithSelector:kAudioDevicePropertyStreamConfiguration
                                     scope:kAudioObjectPropertyScopeInput];
        [self _addNotificationWithSelector:kAudioDevicePropertyStreamConfiguration
                                     scope:kAudioObjectPropertyScopeOutput];
    }
    return self;
}

- (void)dealloc
{
    YASRelease(_inputStreams);
    YASRelease(_outputStreams);
    YASRelease(_inputFormat);
    YASRelease(_outputFormat);
    YASRelease(_listenerBlock);

    _inputStreams = nil;
    _outputStreams = nil;
    _inputFormat = nil;
    _outputFormat = nil;
    _listenerBlock = nil;

    YASSuperDealloc;
}

- (BOOL)isEqual:(id)other
{
    if (other == self) {
        return YES;
    } else if (![other isKindOfClass:self.class]) {
        return NO;
    } else {
        return [self isEqualToAudioDevice:other];
    }
}

- (BOOL)isEqualToAudioDevice:(YASAudioDevice *)otherDevice
{
    if (self == otherDevice) {
        return YES;
    } else {
        return _audioDeviceID == otherDevice.audioDeviceID;
    }
}

- (NSUInteger)hash
{
    return _audioDeviceID;
}

- (NSString *)description
{
    NSMutableString *result = [NSMutableString stringWithFormat:@"<%@: %p>\n{\n", self.class, self];
    NSMutableArray *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"AudioDeviceID = %@", @(_audioDeviceID)]];
    [lines addObject:[NSString stringWithFormat:@"Name = %@", self.name]];
    [lines addObject:[NSString stringWithFormat:@"Manufacture = %@", self.manufacture]];
    [lines addObject:[NSString stringWithFormat:@"Nominal SampleRate = %@", @(self.nominalSampleRate)]];
    if (self.inputFormat) {
        [lines addObject:[NSString stringWithFormat:@"Input Format = %@", self.inputFormat]];
    }
    if (self.outputFormat) {
        [lines addObject:[NSString stringWithFormat:@"Output Format = %@", self.outputFormat]];
    }
    if (self.inputStreams.count > 0) {
        [lines addObject:[NSString stringWithFormat:@"Input Streams = %@", @(self.inputStreams.count)]];
        NSMutableArray *streamLines = [NSMutableArray array];
        for (YASAudioDeviceStream *stream in self.inputStreams) {
            NSMutableString *streamLine = [NSMutableString stringWithFormat:@"{\n"];
            [streamLine appendString:[stream.description stringByAppendingLinePrefix:@"    "]];
            [streamLine appendString:@"\n}"];
            [streamLines addObject:streamLine];
        }
        [lines addObject:[streamLines componentsJoinedByString:@",\n"]];
    }
    if (self.outputStreams.count > 0) {
        [lines addObject:[NSString stringWithFormat:@"Output Streams = %@", @(self.outputStreams.count)]];
        NSMutableArray *streamLines = [NSMutableArray array];
        for (YASAudioDeviceStream *stream in self.outputStreams) {
            NSMutableString *streamLine = [NSMutableString stringWithFormat:@"{\n"];
            [streamLine appendString:[stream.description stringByAppendingLinePrefix:@"    "]];
            [streamLine appendString:@"\n}"];
            [streamLines addObject:streamLine];
        }
        [lines addObject:[streamLines componentsJoinedByString:@",\n"]];
    }
    [result appendString:[[lines componentsJoinedByString:@"\n"] stringByAppendingLinePrefix:@"    "]];
    [result appendFormat:@"\n}"];
    return result;
}

- (NSString *)name
{
    return [self _globalStringValueWithSelector:kAudioObjectPropertyName];
}

- (NSString *)manufacture
{
    return [self _globalStringValueWithSelector:kAudioObjectPropertyManufacturer];
}

- (NSArray *)inputStreams
{
    return _inputStreams.allValues;
}

- (NSArray *)outputStreams
{
    return _outputStreams.allValues;
}

- (Float64)nominalSampleRate
{
    Float64 result = 0.0;

    @autoreleasepool
    {
        NSData *data =
            [self _dataWithSelector:kAudioDevicePropertyNominalSampleRate scope:kAudioObjectPropertyScopeGlobal];
        if (data) {
            Float64 *sampleRate = (Float64 *)data.bytes;
            result = *sampleRate;
        }
    }

    return result;
}

#pragma mark Private

- (void)_updateInputStreams
{
    NSMutableDictionary *prevStreams = nil;
    if (_inputStreams) {
        prevStreams = [_inputStreams copy];
        YASRelease(_inputStreams);
        _inputStreams = nil;
    }

    @autoreleasepool
    {
        NSData *streamData = [self _dataWithSelector:kAudioDevicePropertyStreams scope:kAudioObjectPropertyScopeInput];
        if (streamData) {
            NSUInteger count = streamData.length / sizeof(AudioStreamID);
            NSMutableDictionary *newStreams = [[NSMutableDictionary alloc] initWithCapacity:count];
            AudioStreamID *streamIDs = (AudioStreamID *)streamData.bytes;
            for (NSInteger i = 0; i < count; i++) {
                NSNumber *key = @(streamIDs[i]);
                YASAudioDeviceStream *stream = prevStreams[key];
                if (stream) {
                    newStreams[key] = stream;
                } else {
                    stream = [[YASAudioDeviceStream alloc] initWithAudioStreamID:streamIDs[i] device:self];
                    newStreams[key] = stream;
                    YASRelease(stream);
                }
            }
            _inputStreams = newStreams;
        }
    }

    YASRelease(prevStreams);
    prevStreams = nil;
}

- (void)_updateOutputStreams
{
    NSMutableDictionary *prevStreams = nil;
    if (_outputStreams) {
        prevStreams = [_outputStreams copy];
        YASRelease(_outputStreams);
        _outputStreams = nil;
    }

    @autoreleasepool
    {
        NSData *streamData = [self _dataWithSelector:kAudioDevicePropertyStreams scope:kAudioObjectPropertyScopeOutput];
        if (streamData) {
            NSUInteger count = streamData.length / sizeof(AudioStreamID);
            NSMutableDictionary *newStreams = [[NSMutableDictionary alloc] initWithCapacity:count];
            AudioStreamID *streamIDs = (AudioStreamID *)streamData.bytes;
            for (NSInteger i = 0; i < count; i++) {
                NSNumber *key = @(streamIDs[i]);
                YASAudioDeviceStream *stream = prevStreams[key];
                if (stream) {
                    newStreams[key] = stream;
                } else {
                    stream = [[YASAudioDeviceStream alloc] initWithAudioStreamID:streamIDs[i] device:self];
                    newStreams[key] = stream;
                    YASRelease(stream);
                }
            }
            _outputStreams = newStreams;
        }
    }

    YASRelease(prevStreams);
    prevStreams = nil;
}

- (void)_updateFormatWithScope:(AudioObjectPropertyScope)scope
{
    YASAudioDeviceStream *stream = nil;

    if (scope == kAudioObjectPropertyScopeInput) {
        stream = self.inputStreams.firstObject;
        self.inputFormat = nil;
    } else if (scope == kAudioObjectPropertyScopeOutput) {
        stream = self.outputStreams.firstObject;
        self.outputFormat = nil;
    }

    YASAudioFormat *streamFormat = stream.virtualFormat;

    if (!streamFormat) {
        return;
    }

    @autoreleasepool
    {
        NSData *data = [self _dataWithSelector:kAudioDevicePropertyStreamConfiguration scope:scope];
        if (data.length > 0) {
            const AudioBufferList *configuration = data.bytes;

            UInt32 channelCount = 0;
            for (NSInteger i = 0; i < configuration->mNumberBuffers; i++) {
                channelCount += configuration->mBuffers[i].mNumberChannels;
            }

            YASAudioFormat *format = [[YASAudioFormat alloc] initWithBitDepthFormat:streamFormat.bitDepthFormat
                                                                         sampleRate:streamFormat.sampleRate
                                                                           channels:channelCount
                                                                        interleaved:NO];
            if (scope == kAudioObjectPropertyScopeInput) {
                self.inputFormat = format;
            } else if (scope == kAudioObjectPropertyScopeOutput) {
                self.outputFormat = format;
            }
            YASRelease(format);
        }
    }
}

- (NSData *)_dataWithSelector:(AudioObjectPropertySelector)selector scope:(AudioObjectPropertyScope)scope
{
    const AudioObjectPropertyAddress address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    UInt32 size = 0;
    YASRaiseIfAUError(AudioObjectGetPropertyDataSize(_audioDeviceID, &address, 0, NULL, &size));

    if (size > 0) {
        NSMutableData *data = [NSMutableData dataWithLength:size];
        void *bytes = data.mutableBytes;
        YASRaiseIfAUError(AudioObjectGetPropertyData(_audioDeviceID, &address, 0, NULL, &size, bytes));
        return data;
    } else {
        return NULL;
    }
}

- (NSString *)_globalStringValueWithSelector:(AudioObjectPropertySelector)selector
{
    const AudioObjectPropertyAddress address = {.mSelector = selector,
                                                .mScope = kAudioObjectPropertyScopeGlobal,
                                                .mElement = kAudioObjectPropertyElementMaster};

    CFStringRef cfString = nil;
    UInt32 size = sizeof(CFStringRef);

    YASRaiseIfAUError(AudioObjectGetPropertyData(_audioDeviceID, &address, 0, NULL, &size, &cfString));

    return YASAutorelease((__bridge NSString *)cfString);
}

- (void)_setupListenerBlock
{
    YASWeakContainer *weakContainer = self.weakContainer;

    self.listenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses) {
      YASAudioDevice *device = weakContainer.retainedObject;
      if (device) {
          NSMutableArray *properties = [[NSMutableArray alloc] initWithCapacity:inNumberAddresses];
          for (NSInteger i = 0; i < inNumberAddresses; i++) {
              if (inAddresses[i].mSelector == kAudioDevicePropertyStreams) {
                  if (inAddresses[i].mScope == kAudioObjectPropertyScopeInput) {
                      [device _updateInputStreams];
                  } else if (inAddresses[i].mScope == kAudioObjectPropertyScopeOutput) {
                      [device _updateOutputStreams];
                  }
              } else if (inAddresses[i].mSelector == kAudioDevicePropertyStreamConfiguration) {
                  [device _updateFormatWithScope:inAddresses[i].mScope];
              }
              [properties addObject:@{
                  YASAudioDeviceSelectorKey : [NSString yas_fileTypeStringWithHFSTypeCode:inAddresses[i].mSelector],
                  YASAudioDeviceScopeKey : [NSString yas_fileTypeStringWithHFSTypeCode:inAddresses[i].mScope]
              }];
          }
          [[NSNotificationCenter defaultCenter]
              postNotificationName:YASAudioDeviceDidChangeNotification
                            object:device
                          userInfo:@{YASAudioDevicePropertiesKey : YASAutorelease([properties copy])}];
          YASRelease(properties);
          YASRelease(device);
      } else {
          YASLog(@"%s - Device is nil.", __PRETTY_FUNCTION__);
      }
    };
}

- (void)_addNotificationWithSelector:(AudioObjectPropertySelector)selector scope:(AudioObjectPropertyScope)scope
{
    if (!_listenerBlock) {
        [self _setupListenerBlock];
    }

    const AudioObjectPropertyAddress address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    YASRaiseIfAUError(
        AudioObjectAddPropertyListenerBlock(_audioDeviceID, &address, dispatch_get_main_queue(), self.listenerBlock));
}

- (void)_removeNotificationWithSelector:(AudioObjectPropertySelector)selector scope:(AudioObjectPropertyScope)scope
{
    if (!_listenerBlock) {
        return;
    }

    const AudioObjectPropertyAddress address = {
        .mSelector = selector, .mScope = scope, .mElement = kAudioObjectPropertyElementMaster};

    YASRaiseIfAUError(AudioObjectRemovePropertyListenerBlock(_audioDeviceID, &address, dispatch_get_main_queue(),
                                                             self.listenerBlock));
}

@end

#endif
