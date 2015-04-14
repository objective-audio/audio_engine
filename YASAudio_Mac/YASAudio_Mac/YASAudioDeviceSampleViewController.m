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
    const UInt32 frameLength = outputData.frameLength;

    if (!outputData || frameLength == 0) {
        return;
    }

    YASAudioFormat *format = outputData.format;
    if (format.bitDepthFormat == YASAudioBitDepthFormatFloat32 && format.stride == 1) {
        if (inputData.frameLength >= frameLength) {
            [outputData copyFlexiblyFromData:inputData];

            const Float32 throughVol = self.throughVolume;
            [outputData writeBuffersUsingBlock:^(YASAudioMutableScanner *scanner, const UInt32 buffer) {
                cblas_sscal(frameLength, throughVol, scanner.mutablePointer->f32, 1);
            }];
        }

        const Float64 sampleRate = format.sampleRate;
        const Float64 startPhase = _phase;
        const Float64 sineVol = self.sineVolume;
        const Float64 freq = self.sineFrequency;

        if (frameLength < kSineDataMaxCount) {
            _phase = YASAudioVectorSinef(_sineData, frameLength, startPhase, freq / sampleRate * YAS_2_PI);
            [outputData writeBuffersUsingBlock:^(YASAudioMutableScanner *scanner, const UInt32 buffer) {
                cblas_saxpy(frameLength, sineVol, _sineData, 1, scanner.mutablePointer->f32, 1);
            }];
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
