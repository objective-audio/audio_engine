//
//  YASAudioOfflineSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioOfflineSampleViewController.h"
#import "YASAudio.h"
#import "yas_audio.h"
#import <Accelerate/Accelerate.h>

static Float64 YASAudioOfflineSampleSampleRate = 44100.0;

@interface YASAudioOfflineSampleSineNode : YASAudioTapNode

@property (atomic, assign) Float32 frequency;
@property (nonatomic, assign) Float64 phaseOnRender;
@property (atomic, assign, getter=isPlaying) BOOL playing;

@end

@implementation YASAudioOfflineSampleSineNode

- (instancetype)init
{
    self = [super init];
    if (self) {
        _frequency = 1000.0;

        YASWeakContainer *container = self.weakContainer;
        self.renderBlock = ^(YASAudioData *data, NSNumber *bus, AVAudioTime *when) {
            [data clear];

            YASAudioOfflineSampleSineNode *node = [container retainedObject];
            if (node.isPlaying) {
                const Float64 startPhase = node.phaseOnRender;
                const Float64 phasePerFrame = node.frequency / YASAudioOfflineSampleSampleRate * YAS_2_PI;
                Float64 nextPhase = startPhase;
                const UInt32 frameLength = data.frameLength;

                if (frameLength > 0) {
                    const YASAudioFrameEnumerator *enumerator =
                        [[YASAudioFrameEnumerator alloc] initWithAudioData:data];
                    const YASAudioPointer *pointer = enumerator.pointer;
                    while (pointer->v) {
                        nextPhase = YASAudioVectorSinef(pointer->f32, frameLength, startPhase, phasePerFrame);
                        YASAudioFrameEnumeratorMoveChannel(enumerator);
                    }
                    YASRelease(enumerator);

                    node.phaseOnRender = nextPhase;
                }

                YASRelease(node);
            }
        };
    }
    return self;
}

@end

@interface YASAudioOfflineSampleViewController ()

@property (nonatomic, assign) Float32 volume;
@property (nonatomic, assign) Float32 length;

@property (nonatomic, strong) YASAudioEngine *playEngine;
@property (nonatomic, strong) YASAudioUnitMixerNode *playMixerNode;
@property (nonatomic, strong) YASAudioOfflineSampleSineNode *playSineNode;

@property (nonatomic, strong) YASAudioEngine *offlineEngine;
@property (nonatomic, strong) YASAudioUnitMixerNode *offlineMixerNode;
@property (nonatomic, strong) YASAudioOfflineSampleSineNode *offlineSineNode;
@property (nonatomic, assign, getter=isProcessing) BOOL processing;

@property (nonatomic, strong) id observer;

@end

@implementation YASAudioOfflineSampleViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    YASAudioFormat *format = [[YASAudioFormat alloc] initWithPCMFormat:YASAudioPCMFormatFloat32
                                                            sampleRate:YASAudioOfflineSampleSampleRate
                                                              channels:2
                                                           interleaved:NO];

    /*
     play engine
     */

    YASAudioEngine *playEngine = [[YASAudioEngine alloc] init];
    self.playEngine = playEngine;
    YASRelease(playEngine);

    YASAudioUnitOutputNode *playOutputNode = [[YASAudioUnitOutputNode alloc] init];

    YASAudioUnitMixerNode *playMixerNode = [[YASAudioUnitMixerNode alloc] init];
    [playMixerNode setInputPan:0.0 forBus:@0];
    [playMixerNode setInputEnabled:YES forBus:@0];
    [playMixerNode setOutputVolume:1.0 forBus:@0];
    [playMixerNode setOutputPan:0.0 forBus:@0];
    self.playMixerNode = playMixerNode;
    YASRelease(playMixerNode);

    YASAudioOfflineSampleSineNode *playSineNode = [[YASAudioOfflineSampleSineNode alloc] init];
    self.playSineNode = playSineNode;
    YASRelease(playSineNode);

    [playEngine connectFromNode:playMixerNode toNode:playOutputNode format:format];
    [playEngine connectFromNode:playSineNode toNode:playMixerNode format:format];

    YASRelease(playOutputNode);

    /*
     offline engine
     */

    YASAudioEngine *offlineEngine = [[YASAudioEngine alloc] init];
    self.offlineEngine = offlineEngine;
    YASRelease(offlineEngine);

    YASAudioOfflineOutputNode *offlineOutputNode = [[YASAudioOfflineOutputNode alloc] init];

    YASAudioUnitMixerNode *offlineMixerNode = [[YASAudioUnitMixerNode alloc] init];
    [offlineMixerNode setInputPan:0.0 forBus:@0];
    [offlineMixerNode setInputEnabled:YES forBus:@0];
    [offlineMixerNode setOutputVolume:1.0 forBus:@0];
    [offlineMixerNode setOutputPan:0.0 forBus:@0];
    self.offlineMixerNode = offlineMixerNode;
    YASRelease(offlineMixerNode);

    YASAudioOfflineSampleSineNode *offlineSineNode = [[YASAudioOfflineSampleSineNode alloc] init];
    self.offlineSineNode = offlineSineNode;
    YASRelease(playSineNode);

    [offlineEngine connectFromNode:offlineMixerNode toNode:offlineOutputNode format:format];
    [offlineEngine connectFromNode:offlineSineNode toNode:offlineMixerNode format:format];

    YASRelease(offlineOutputNode);

    YASRelease(format);

    YASWeakContainer *outputNodeContainer = playOutputNode.weakContainer;

    self.observer =
        [[NSNotificationCenter defaultCenter] addObserverForName:YASAudioEngineConfigurationChangeNotification
                                                          object:self.playEngine
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          YASAudioUnitOutputNode *node =
                                                              outputNodeContainer.retainedObject;
                                                          node.device = [YASAudioDevice defaultOutputDevice];
                                                          YASRelease(node);
                                                      }];

    self.volume = 0.5;
    self.playSineNode.frequency = 1000.0;
    self.length = 1.0;
}

- (void)viewDidAppear
{
    [super viewDidAppear];

    NSError *error = nil;
    if (![self.playEngine startRender:&error]) {
        NSLog(@"%s error = %@", __PRETTY_FUNCTION__, error);
    }
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];

    [self.playEngine stop];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:_observer];

    YASRelease(_playSineNode);
    YASRelease(_playMixerNode);
    YASRelease(_playEngine);
    YASRelease(_offlineSineNode);
    YASRelease(_offlineMixerNode);
    YASRelease(_offlineEngine);
    YASRelease(_observer);

    _playSineNode = nil;
    _playMixerNode = nil;
    _playEngine = nil;
    _offlineSineNode = nil;
    _offlineMixerNode = nil;
    _offlineEngine = nil;
    _observer = nil;

    YASSuperDealloc;
}

- (void)setVolume:(Float32)volume
{
    _volume = volume;

    [self.playMixerNode setInputVolume:volume forBus:@0];
}

- (IBAction)playButtonTapped:(id)sender
{
    self.playSineNode.playing = YES;
}

- (IBAction)stopButtonTapped:(id)sender
{
    self.playSineNode.playing = NO;
}

- (IBAction)exportButtonTapped:(id)sender
{
    if (self.processing) {
        return;
    }

    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedFileTypes = @[@"wav"];
    panel.extensionHidden = NO;
    if ([panel runModal] == NSFileHandlingPanelOKButton) {
        [self startOfflineFileWritingWithURL:panel.URL];
    }
}

- (void)startOfflineFileWritingWithURL:(NSURL *)url
{
    self.processing = YES;

    NSError *error = nil;

    NSDictionary *waveSettings = [NSDictionary yas_waveFileSettingsWithSampleRate:YASAudioOfflineSampleSampleRate
                                                                 numberOfChannels:2
                                                                         bitDepth:16];
    YASAudioFileWriter *fileWriter = [[YASAudioFileWriter alloc] initWithURL:url
                                                                    fileType:YASAudioFileTypeWAVE
                                                                    settings:waveSettings
                                                                   pcmFormat:YASAudioPCMFormatFloat32
                                                                 interleaved:NO
                                                                       error:&error];

    if (error) {
        NSLog(@"%s error = %@", __PRETTY_FUNCTION__, error);
        return;
    }

    __block UInt32 remain = self.length * YASAudioOfflineSampleSampleRate;

    YASAudioOfflineSampleSineNode *offlineSineNode = self.offlineSineNode;
    offlineSineNode.frequency = self.playSineNode.frequency;
    offlineSineNode.playing = YES;
    [self.offlineMixerNode setInputVolume:self.volume forBus:@0];

    if (![self.offlineEngine startOfflineRenderWithOutputCallbackBlock:^(YASAudioData *data, AVAudioTime *when,
                                                                         BOOL *stop) {
            UInt32 frameLength = MIN(remain, data.frameLength);
            if (frameLength > 0) {
                NSError *error = nil;
                data.frameLength = frameLength;
                if (![fileWriter writeSyncFromData:data error:&error]) {
                    NSLog(@"%s error = %@", __PRETTY_FUNCTION__, error);
                }
            }

            remain -= frameLength;
            if (remain == 0) {
                [fileWriter close];
                *stop = YES;
            }
        } completionBlock:^(BOOL cancelled) {
            self.processing = NO;
        } error:&error]) {
        self.processing = NO;
        NSLog(@"%s error = %@", __PRETTY_FUNCTION__, error);
    };

    YASRelease(fileWriter);
}

@end
