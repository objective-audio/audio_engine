//
//  YASAudioEngineIOSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineIOSampleViewController.h"
#import "YASAudio.h"

@interface YASAudioEngineIOSampleViewController ()

@property (nonatomic, strong) IBOutlet UISlider *slider;

@property (nonatomic, strong) YASAudioEngine *audioEngine;
@property (nonatomic, strong) YASAudioUnitOutputNode *outputNode;
@property (nonatomic, strong) YASAudioUnitMixerNode *mixerNode;
@property (nonatomic, strong) YASAudioUnitInputNode *inputNode;

@end

@implementation YASAudioEngineIOSampleViewController

- (void)dealloc
{
    YASRelease(_audioEngine);
    YASRelease(_outputNode);
    YASRelease(_mixerNode);
    YASRelease(_inputNode);
    YASRelease(_slider);

    _audioEngine = nil;
    _outputNode = nil;
    _mixerNode = nil;
    _inputNode = nil;
    _slider = nil;

    YASSuperDealloc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    if ([self setupAudioEngine]) {
        [self volumeSliderChanged:self.slider];
    } else {
        [self showErrorAlert];
    }
}

- (IBAction)volumeSliderChanged:(UISlider *)sender
{
    const Float32 value = sender.value;
    [self.mixerNode setVolume:value forBus:@0];
}

- (BOOL)setupAudioEngine
{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];

    NSError *error = nil;
    if (![audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
        NSLog(@"%@", error);
        return NO;
    }

    Float64 sampleRate = [audioSession sampleRate];

    YASAudioEngine *engine = [[YASAudioEngine alloc] init];
    self.audioEngine = engine;
    YASRelease(engine);

    YASAudioUnitOutputNode *outputNode = [[YASAudioUnitOutputNode alloc] init];
    self.outputNode = outputNode;
    YASRelease(outputNode);

    YASAudioUnitMixerNode *mixerNode = [[YASAudioUnitMixerNode alloc] init];
    self.mixerNode = mixerNode;
    YASRelease(mixerNode);

    YASAudioUnitInputNode *inputNode = [[YASAudioUnitInputNode alloc] init];
    self.inputNode = inputNode;
    YASRelease(inputNode);

    YASAudioFormat *format = [[YASAudioFormat alloc] initStandardFormatWithSampleRate:sampleRate channels:2];

    [engine connectFromNode:mixerNode toNode:outputNode format:format];
    [engine connectFromNode:inputNode toNode:mixerNode format:format];

    YASRelease(format);

    if (![engine startRender:&error]) {
        NSLog(@"%@", error);
        return NO;
    }

    return YES;
}

#pragma mark -

- (void)showErrorAlert
{
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error"
                                                                        message:@"Can't start audio engine."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                     [self.navigationController popViewControllerAnimated:YES];
                                                 }]];
    [self presentViewController:controller animated:YES completion:NULL];
}

@end
