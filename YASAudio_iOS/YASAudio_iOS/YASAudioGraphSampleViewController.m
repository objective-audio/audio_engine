//
//  YASAudioGraphSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioGraphSampleViewController.h"
#import "YASAudio.h"
#import <AVFoundation/AVFoundation.h>

@interface YASAudioGraphSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@property (nonatomic, strong) YASAudioGraph *audioGraph;
@property (nonatomic, strong) YASAudioUnit *ioUnit;
@property (nonatomic, strong) YASAudioUnit *mixerUnit;

@end

@implementation YASAudioGraphSampleViewController

- (void)dealloc
{
    YASRelease(_audioGraph);
    YASRelease(_ioUnit);
    YASRelease(_mixerUnit);
    YASRelease(_slider);

    _audioGraph = nil;
    _ioUnit = nil;
    _mixerUnit = nil;
    _slider = nil;

    YASSuperDealloc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupAudioGraph];

    [self volumeSliderChanged:self.slider];
}

- (IBAction)volumeSliderChanged:(UISlider *)sender
{
    const AudioUnitParameterValue value = sender.value;
    [self.mixerUnit setParameter:kMultiChannelMixerParam_Volume value:value scope:kAudioUnitScope_Input element:0];
}

- (void)setupAudioGraph
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    Float64 sampleRate = [audioSession sampleRate];

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:2];

    YASAudioGraph *audioGraph = [[YASAudioGraph alloc] init];
    self.audioGraph = audioGraph;
    YASRelease(audioGraph);

    YASAudioUnit *ioUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_Output subType:YASAudioUnitSubType_DefaultIO];
    self.ioUnit = ioUnit;
    YASRelease(ioUnit);

    [ioUnit setEnableInput:YES];
    [ioUnit setEnableOutput:YES];
    [ioUnit setMaximumFramesPerSlice:4096];

    [audioGraph addAudioUnit:ioUnit];

    [self.ioUnit setRenderCallback:0];
    [self.ioUnit setInputFormat:format.streamDescription busNumber:0];
    [self.ioUnit setOutputFormat:format.streamDescription busNumber:1];

    YASWeakContainer *ioContainer = self.ioUnit.weakContainer;

    YASAudioUnit *mixerUnit =
        [[YASAudioUnit alloc] initWithType:kAudioUnitType_Mixer subType:kAudioUnitSubType_MultiChannelMixer];
    self.mixerUnit = mixerUnit;
    YASRelease(mixerUnit);

    [mixerUnit setMaximumFramesPerSlice:4096];

    [audioGraph addAudioUnit:mixerUnit];

    [self.mixerUnit setRenderCallback:0];
    [self.mixerUnit setElementCount:1 scope:kAudioUnitScope_Input];
    [self.mixerUnit setOutputFormat:format.streamDescription busNumber:0];
    [self.mixerUnit setInputFormat:format.streamDescription busNumber:0];

    YASWeakContainer *mixerContainer = self.mixerUnit.weakContainer;

    self.ioUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        YASAudioUnit *mixerUnit = [mixerContainer retainedObject];
        [mixerUnit audioUnitRender:renderParameters];
        YASRelease(mixerUnit);
    };

    self.mixerUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
        renderParameters->inBusNumber = 1;
        YASAudioUnit *ioUnit = [ioContainer retainedObject];
        [ioUnit audioUnitRender:renderParameters];
        YASRelease(ioUnit);
    };

    audioGraph.running = YES;

    YASRelease(format);
}

@end
