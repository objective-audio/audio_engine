//
//  YASAudioGraphViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioGraphViewController.h"
#import "YASAudioGraph.h"
#import "YASAudioUnit.h"
#import "YASAudioFormat.h"
#import "YASMacros.h"
#import <AVFoundation/AVFoundation.h>

@interface YASAudioGraphViewController ()

@property (nonatomic, assign) IBOutlet UISlider *slider;

@property (nonatomic, strong) YASAudioGraph *audioGraph;
@property (nonatomic, strong) YASAudioUnit *ioUnit;
@property (nonatomic, strong) YASAudioUnit *mixerUnit;

@end

@implementation YASAudioGraphViewController

- (void)dealloc
{
    YASRelease(_audioGraph);
    YASRelease(_ioUnit);
    YASRelease(_mixerUnit);

    _audioGraph = nil;
    _ioUnit = nil;
    _mixerUnit = nil;

    YASSuperDealloc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupAudioGraph];

    [self volumeSliderChanged:self.slider];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
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

    self.ioUnit = [audioGraph addAudioUnitWithType:kAudioUnitType_Output
                                           subType:YASAudioUnitSubType_DefaultIO
                                      prepareBlock:^(YASAudioUnit *audioUnit) {
                                        [audioUnit setEnableInput:YES];
                                        [audioUnit setEnableOutput:YES];
                                        [audioUnit setMaximumFramesPerSlice:4096];
                                      }];

    [self.ioUnit setRenderCallback:0];
    [self.ioUnit setInputFormat:format.streamDescription busNumber:0];
    [self.ioUnit setOutputFormat:format.streamDescription busNumber:1];

    YASWeakContainer *ioContainer = self.ioUnit.weakContainer;

    self.mixerUnit = [audioGraph addAudioUnitWithType:kAudioUnitType_Mixer
                                              subType:kAudioUnitSubType_MultiChannelMixer
                                         prepareBlock:^(YASAudioUnit *audioUnit) {
                                           [audioUnit setMaximumFramesPerSlice:4096];
                                         }];

    [self.mixerUnit setRenderCallback:0];
    [self.mixerUnit setElementCount:1 scope:kAudioUnitScope_Input];
    [self.mixerUnit setOutputFormat:format.streamDescription busNumber:0];
    [self.mixerUnit setInputFormat:format.streamDescription busNumber:0];

    YASWeakContainer *mixerContainer = self.mixerUnit.weakContainer;

    self.ioUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
      YASAudioUnit *mixerUnit = mixerContainer.retainedObject;
      [mixerUnit audioUnitRender:renderParameters];
      YASRelease(mixerUnit);
    };

    self.mixerUnit.renderCallbackBlock = ^(YASAudioUnitRenderParameters *renderParameters) {
      renderParameters->inBusNumber = 1;
      YASAudioUnit *ioUnit = ioContainer.retainedObject;
      [ioUnit audioUnitRender:renderParameters];
      YASRelease(ioUnit);
    };

    audioGraph.running = YES;

    YASRelease(format);
}

@end
