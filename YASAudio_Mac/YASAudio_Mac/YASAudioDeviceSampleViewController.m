//
//  YASAudioDeviceSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioDeviceSampleViewController.h"
#import "YASAudioGraph.h"
#import "YASAudioDevice.h"
#import "YASAudioDeviceIO.h"
#import "YASMacros.h"
#import "YASAudioMath.h"
#import "YASAudioUtility.h"
#import "YASAudioFormat.h"
#import "YASDecibelValueTransformer.h"
#import "YASFrequencyValueFormatter.h"
#import <Accelerate/Accelerate.h>

static const UInt32 kSineDataMaxCount = 4096;

@interface YASAudioDeviceSampleCore : NSObject

@property (atomic, assign) Float64 throughVolume;
@property (atomic, assign) Float64 sineFrequency;
@property (atomic, assign) Float64 sineVolume;
@property (atomic, strong) YASAudioFormat *format;

@end

@implementation YASAudioDeviceSampleCore {
    Float64 _phase;
    Float32 *_sineData;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _sineData = calloc(kSineDataMaxCount, sizeof(Float32));
        _sineFrequency = 1000.0;
    }
    return self;
}

- (void)dealloc
{
    free(_sineData);
    YASRelease(_format);
    YASSuperDealloc;
}

- (void)processWithOutputData:(AudioBufferList *)outputData inputData:(const AudioBufferList *)inputData frameLength:(const UInt32)frameLength
{
    if (!outputData || frameLength == 0) {
        return;
    }
    
    YASAudioFormat *format = self.format;
    if (format && format.bitDepthFormat == YASAudioBitDepthFormatFloat32) {
        if (inputData) {
            UInt32 outFrameLength = frameLength;
            YASAudioCopyAudioBufferListFlexibly(inputData, outputData, sizeof(Float32), &outFrameLength);
            
            const Float32 throughVol = self.throughVolume;
            
            for (UInt32 buf = 0; buf < outputData->mNumberBuffers; buf++) {
                Float32 *data = outputData->mBuffers[buf].mData;
                UInt32 length = frameLength * outputData->mBuffers[buf].mNumberChannels;
                cblas_sscal(length, throughVol, data, 1);
            }
        }
        
        const Float64 sampleRate = format.sampleRate;
        const Float64 startPhase = _phase;
        const Float64 sineVol = self.sineVolume;
        const Float64 freq = self.sineFrequency;
        Float64 endPhase = 0;
        
        if (frameLength < kSineDataMaxCount) {
            endPhase = YASAudioVectorSinef(_sineData, frameLength, startPhase, freq / sampleRate * YAS_2_PI);
            
            _phase = endPhase;
            
            for (UInt32 buf = 0; buf < outputData->mNumberBuffers; buf++) {
                Float32 *data = outputData->mBuffers[buf].mData;
                const int stride = outputData->mBuffers[buf].mNumberChannels;
                const int length = frameLength;
                for (UInt32 ch = 0; ch < stride; ch++) {
                    cblas_saxpy(length, sineVol, _sineData, 1, &data[ch], stride);
                }
            }
        }
    }
}

@end

@interface YASAudioDeviceSampleViewController ()

@property (nonatomic, strong) YASAudioGraph *audioGraph;
@property (nonatomic, strong) YASAudioDeviceIO *deviceIO;
@property (nonatomic, strong) YASAudioDeviceSampleCore *core;

@property (nonatomic, strong) NSArray *deviceNames;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;
@property (nonatomic, copy) NSString *deviceInfo;

@end

@implementation YASAudioDeviceSampleViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        YASDecibelValueTransformer *decibelValueFormatter = YASAutorelease([[YASDecibelValueTransformer alloc] init]);
        [NSValueTransformer setValueTransformer:decibelValueFormatter forName:NSStringFromClass([YASDecibelValueTransformer class])];
        
        YASFrequencyValueFormatter *freqValueFormatter = YASAutorelease([[YASFrequencyValueFormatter alloc] init]);
        [NSValueTransformer setValueTransformer:freqValueFormatter forName:NSStringFromClass([YASFrequencyValueFormatter class])];
    });
    
    YASAudioGraph *audioGraph = [[YASAudioGraph alloc] init];
    self.audioGraph = audioGraph;
    YASRelease(audioGraph);
    
    self.deviceIO = [audioGraph addAudioDeviceIOWithAudioDevice:nil];
    
    YASAudioDeviceSampleCore *core = [[YASAudioDeviceSampleCore alloc] init];
    self.core = core;
    YASRelease(core);
    
    YASWeakContainer *container = self.deviceIO.weakContainer;
    
    self.deviceIO.renderCallbackBlock = ^(AudioBufferList *outData, const AudioTimeStamp *inTime, const UInt32 inFrameLength) {
        YASAudioDeviceIO *deviceIO = container.retainedObject;
        [core processWithOutputData:outData inputData:deviceIO.inputAudioBufferListOnRender frameLength:inFrameLength];
        YASRelease(deviceIO);
    };
    
    audioGraph.running = YES;
    
    [self updateDeviceNames];
    
    YASAudioDevice *defaultDevice = [YASAudioDevice defaultOutputDevice];
    NSUInteger index = [[YASAudioDevice allDevices] indexOfObject:defaultDevice];
    self.selectedDeviceIndex = index;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioHardwareDidChange:) name:YASAudioHardwareDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(audioDeviceDidChange:) name:YASAudioDeviceDidChangeNotification object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    YASRelease(_core);
    YASRelease(_deviceIO);
    YASRelease(_audioGraph);
    YASRelease(_deviceNames);
    YASSuperDealloc;
}

#pragma mark -

- (void)setSelectedDeviceIndex:(NSUInteger)selectedDeviceIndex
{
    if (_selectedDeviceIndex != selectedDeviceIndex) {
        _selectedDeviceIndex = selectedDeviceIndex;
        
        NSArray *allDevices = [YASAudioDevice allDevices];
        
        if (selectedDeviceIndex < allDevices.count) {
            [self setDevice:allDevices[selectedDeviceIndex]];
        } else {
            [self setDevice:nil];
        }
    }
}

- (void)updateDeviceNames
{
    NSArray *allDevices = [YASAudioDevice allDevices];
    
    NSMutableArray *titles = [NSMutableArray arrayWithCapacity:allDevices.count];
    
    for (YASAudioDevice *device in allDevices) {
        [titles addObject:device.name];
    }
    
    [titles addObject:@"None"];
    
    self.deviceNames = titles;
    
    YASAudioDevice *device = self.deviceIO.audioDevice;
    
    if (device) {
        self.selectedDeviceIndex = [allDevices indexOfObject:device];
    } else {
        self.selectedDeviceIndex = allDevices.count;
    }
}

- (void)setDevice:(YASAudioDevice *)selectedDevice
{
    NSArray *allDevices = [YASAudioDevice allDevices];
    
    if (selectedDevice && [allDevices containsObject:selectedDevice]) {
        self.deviceIO.audioDevice = selectedDevice;
        [self updateCoreSampleRate];
    } else {
        self.deviceIO.audioDevice = nil;
    }
    
    [self updateDeviceInfo];
}

- (void)updateCoreSampleRate
{
    self.core.format = self.deviceIO.audioDevice.outputFormat;
}

- (void)updateDeviceInfo
{
    self.deviceInfo = self.deviceIO.audioDevice.description;
}

#pragma mark -

- (void)audioHardwareDidChange:(NSNotification *)notification
{
    [self updateDeviceNames];
}

- (void)audioDeviceDidChange:(NSNotification *)notification
{
    YASAudioDevice *device = notification.object;
    
    if ([self.deviceIO.audioDevice isEqualToAudioDevice:device]) {
        [self updateCoreSampleRate];
        [self updateDeviceInfo];
    }
}

@end
