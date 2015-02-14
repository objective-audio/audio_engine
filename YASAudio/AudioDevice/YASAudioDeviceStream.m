//
//  YASAudioDeviceStream.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <TargetConditionals.h>

#if (TARGET_OS_MAC && !TARGET_OS_IPHONE)

#import "YASAudioDeviceStream.h"
#import "YASAudioDevice.h"
#import "YASAudioFormat.h"
#import "YASMacros.h"
#import "NSException+YASAudio.h"

NSString *const YASAudioDeviceStreamVirtualFormatDidChangeNotification = @"YASAudioDeviceStreamVirtualFormatDidChangeNotification";
NSString *const YASAudioDeviceStreamIsActiveDidChangeNotification = @"YASAudioDeviceStreamIsActiveDidChangeNotification";
NSString *const YASAudioDeviceStreamStartingChannelDidChangeNotification = @"YASAudioDeviceStreamStartingChannelDidChangeNotification";

@interface YASAudioDeviceStream ()

@property (nonatomic, copy) AudioObjectPropertyListenerBlock listenerBlock;

@end

@implementation YASAudioDeviceStream {
    AudioDeviceID _audioDeviceID;
}

- (instancetype)initWithAudioStreamID:(AudioStreamID)audioStreamID device:(YASAudioDevice *)device
{
    self = [super init];
    if (self) {
        _audioStreamID = audioStreamID;
        _audioDeviceID = device.audioDeviceID;
        [self _addNotificationWithSelector:kAudioStreamPropertyVirtualFormat];
        [self _addNotificationWithSelector:kAudioStreamPropertyIsActive];
        [self _addNotificationWithSelector:kAudioStreamPropertyStartingChannel];
    }
    return self;
}

- (void)dealloc
{
    YASRelease(_listenerBlock);
    
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
        return [self isEqualToAudioDeviceStream:other];
    }
}

- (BOOL)isEqualToAudioDeviceStream:(YASAudioDeviceStream *)otherStream
{
    if (self == otherStream) {
        return YES;
    } else {
        return _audioStreamID == otherStream.audioStreamID;
    }
}

- (NSUInteger)hash
{
    return _audioStreamID;
}

- (NSString *)description
{
    NSMutableString *result = [NSMutableString stringWithFormat:@"<%@: %p>\n", self.class, self];
    NSDictionary *dict = @{@"01_isActive": @(self.isActive),
                           @"02_virtualFormat": self.virtualFormat,
                           @"03_direction": self.direction == YASAudioDeviceStreamDirectionOutput ? @"output" : @"input",
                           @"04_startingChannel": @(self.startingChannel)};
    [result appendString:dict.description];
    return result;
}

- (YASAudioDevice *)device
{
    return [YASAudioDevice deviceForID:_audioDeviceID];
}

- (BOOL)isActive
{
    BOOL result = NO;
    
    @autoreleasepool {
        NSData *data = [self _dataWithSelector:kAudioStreamPropertyIsActive];
        if (data) {
            const UInt32 *isActive = (UInt32 *)data.bytes;
            result = *isActive > 0;
        }
    }
    
    return result;
}

- (YASAudioFormat *)virtualFormat
{
    YASAudioFormat *format = nil;
    
    @autoreleasepool {
        NSData *data = [self _dataWithSelector:kAudioStreamPropertyVirtualFormat];
        if (data) {
            const AudioStreamBasicDescription *asbd = (AudioStreamBasicDescription *)data.bytes;
            format = [[YASAudioFormat alloc] initWithStreamDescription:asbd];
        }
    }
    
    return YASAutorelease(format);
}

- (YASAudioDeviceStreamDirection)direction
{
    YASAudioDeviceStreamDirection direction;
    
    @autoreleasepool {
        NSData *data = [self _dataWithSelector:kAudioStreamPropertyDirection];
        if (data) {
            const UInt32 *dataPtr = (UInt32 *)data.bytes;
            direction = *dataPtr;
        }
    }
    
    return direction;
}

- (UInt32)startingChannel
{
    UInt32 startingChannel = 0;
    
    @autoreleasepool {
        NSData *data = [self _dataWithSelector:kAudioStreamPropertyStartingChannel];
        if (data) {
            const UInt32 *dataPtr = (UInt32 *)data.bytes;
            startingChannel = *dataPtr;
        }
    }
    
    return startingChannel;
}

#pragma mark Private

- (NSData *)_dataWithSelector:(AudioObjectPropertySelector)selector
{
    const AudioObjectPropertyAddress address = {
        .mSelector = selector,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMaster
    };
    
    UInt32 size = 0;
    YASRaiseIfAUError(AudioObjectGetPropertyDataSize(_audioStreamID, &address, 0, NULL, &size));
    
    if (size > 0) {
        NSMutableData *data = [NSMutableData dataWithLength:size];
        void *bytes = data.mutableBytes;
        YASRaiseIfAUError(AudioObjectGetPropertyData(_audioStreamID, &address, 0, NULL, &size, bytes));
        return data;
    } else {
        return NULL;
    }
}

- (void)_setupListenerBlock
{
    YASWeakContainer *weakContainer = self.weakContainer;
    
    self.listenerBlock = ^(UInt32 inNumberAddresses, const AudioObjectPropertyAddress *inAddresses) {
        YASAudioDeviceStream *stream = weakContainer.retainedObject;
        if (stream) {
            for (NSInteger i = 0; i < inNumberAddresses; i++) {
                if (inAddresses[i].mSelector == kAudioStreamPropertyVirtualFormat) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:YASAudioDeviceStreamVirtualFormatDidChangeNotification object:stream];
                } else if (inAddresses[i].mSelector == kAudioStreamPropertyIsActive) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:YASAudioDeviceStreamIsActiveDidChangeNotification object:stream];
                } else if (inAddresses[i].mSelector == kAudioStreamPropertyStartingChannel) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:YASAudioDeviceStreamStartingChannelDidChangeNotification object:stream];
                }
            }
            YASRelease(stream);
        }
    };
}

- (void)_addNotificationWithSelector:(AudioObjectPropertySelector)selector
{
    if (!_listenerBlock) {
        [self _setupListenerBlock];
    }
    
    const AudioObjectPropertyAddress address = {
        .mSelector = selector,
        .mScope = kAudioObjectPropertyScopeGlobal,
        .mElement = kAudioObjectPropertyElementMaster
    };
    
    YASRaiseIfAUError(AudioObjectAddPropertyListenerBlock(_audioStreamID, &address, dispatch_get_main_queue(), self.listenerBlock));
}

@end

#endif
