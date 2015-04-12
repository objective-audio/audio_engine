//
//  YASAudioDeviceSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioDeviceSampleViewController.h"
#import "YASAudio.h"
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

- (void)processWithOutputData:(YASAudioData *)outputData inputData:(YASAudioData *)inputData
{
    UInt32 frameLength = outputData.frameLength;
    AudioBufferList *outputAbl = outputData.mutableAudioBufferList;
    const AudioBufferList *inputAbl = inputData.audioBufferList;

    if (!outputAbl || frameLength == 0) {
        return;
    }

    YASAudioFormat *format = self.format;
    if (format && format.bitDepthFormat == YASAudioBitDepthFormatFloat32) {
        if (inputAbl && inputData.frameLength >= frameLength) {
            UInt32 outFrameLength = frameLength;
            YASAudioCopyAudioBufferListFlexibly(inputAbl, outputAbl, sizeof(Float32), &outFrameLength);

            const Float32 throughVol = self.throughVolume;

            for (UInt32 buf = 0; buf < outputAbl->mNumberBuffers; buf++) {
                Float32 *data = outputAbl->mBuffers[buf].mData;
                UInt32 length = frameLength * outputAbl->mBuffers[buf].mNumberChannels;
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

            for (UInt32 buf = 0; buf < outputAbl->mNumberBuffers; buf++) {
                Float32 *data = outputAbl->mBuffers[buf].mData;
                const int stride = outputAbl->mBuffers[buf].mNumberChannels;
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
@property (nonatomic, assign) Float64 nominalSampleRate;
@property (nonatomic, assign) NSUInteger selectedDeviceIndex;
@property (nonatomic, copy) NSString *deviceInfo;
@property (nonatomic, strong) NSColor *ioThroughTextColor;
@property (nonatomic, strong) NSColor *sineTextColor;

@end

@implementation YASAudioDeviceSampleViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        YASDecibelValueTransformer *decibelValueFormatter = YASAutorelease([[YASDecibelValueTransformer alloc] init]);
        [NSValueTransformer setValueTransformer:decibelValueFormatter
                                        forName:NSStringFromClass([YASDecibelValueTransformer class])];

        YASFrequencyValueFormatter *freqValueFormatter = YASAutorelease([[YASFrequencyValueFormatter alloc] init]);
        [NSValueTransformer setValueTransformer:freqValueFormatter
                                        forName:NSStringFromClass([YASFrequencyValueFormatter class])];
    });

    YASAudioGraph *audioGraph = [[YASAudioGraph alloc] init];
    self.audioGraph = audioGraph;
    YASRelease(audioGraph);

    YASAudioDeviceIO *deviceIO = [[YASAudioDeviceIO alloc] init];
    self.deviceIO = deviceIO;
    [audioGraph addAudioDeviceIO:deviceIO];
    YASRelease(deviceIO);

    YASAudioDeviceSampleCore *core = [[YASAudioDeviceSampleCore alloc] init];
    self.core = core;
    YASRelease(core);

    YASWeakContainer *container = self.deviceIO.weakContainer;

    self.deviceIO.renderCallbackBlock = ^(YASAudioData *outData, YASAudioTime *when) {
        YASAudioDeviceIO *deviceIO = [container retainedObject];
        [core processWithOutputData:outData inputData:[deviceIO inputDataOnRender]];
        YASRelease(deviceIO);
    };

    audioGraph.running = YES;

    [self updateDeviceNames];

    YASAudioDevice *defaultDevice = [YASAudioDevice defaultOutputDevice];
    NSUInteger index = [[YASAudioDevice allDevices] indexOfObject:defaultDevice];
    self.selectedDeviceIndex = index;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioHardwareDidChange:)
                                                 name:YASAudioHardwareDidChangeNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(audioDeviceDidChange:)
                                                 name:YASAudioDeviceDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    YASRelease(_core);
    YASRelease(_deviceIO);
    YASRelease(_audioGraph);
    YASRelease(_deviceNames);
    YASRelease(_deviceInfo);
    YASRelease(_ioThroughTextColor);
    YASRelease(_sineTextColor);
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
    } else {
        self.deviceIO.audioDevice = nil;
    }

    [self updateDeviceInfo];
}

- (void)updateDeviceInfo
{
    YASAudioDevice *device = self.deviceIO.audioDevice;
    NSColor *onColor = [NSColor blackColor];
    NSColor *offColor = [NSColor lightGrayColor];

    self.core.format = device.outputFormat;
    self.deviceInfo = device.description;
    self.nominalSampleRate = device.nominalSampleRate;
    self.ioThroughTextColor = (device.inputFormat && device.outputFormat) ? onColor : offColor;
    self.sineTextColor = device.outputFormat ? onColor : offColor;
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
        [self updateDeviceInfo];
    }
}

@end
