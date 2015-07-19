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

    auto wave_settings = yas::wave_file_settings(YASAudioOfflineSampleSampleRate, 2, 16);
    auto create_result =
        yas::audio_file_writer::create((__bridge CFURLRef)url, yas::audio_file_type::wave, wave_settings);

    if (!create_result) {
        std::cout << __PRETTY_FUNCTION__ << " - error:" << yas::to_string(create_result.error()) << std::endl;
        return;
    }

    auto file_writer = create_result.value();

    __block UInt32 remain = self.length * YASAudioOfflineSampleSampleRate;

    YASAudioOfflineSampleSineNode *offlineSineNode = self.offlineSineNode;
    offlineSineNode.frequency = self.playSineNode.frequency;
    offlineSineNode.playing = YES;
    [self.offlineMixerNode setInputVolume:self.volume forBus:@0];

    NSError *error = nil;

    if (![self.offlineEngine startOfflineRenderWithOutputCallbackBlock:^(YASAudioData *data, AVAudioTime *when,
                                                                         BOOL *stop) {
            auto format = yas::audio_format::create(*data.format.streamDescription);
            auto pcm_buffer = yas::pcm_buffer::create(format, data.mutableAudioBufferList);
            pcm_buffer->set_frame_length(data.frameLength);

            UInt32 frame_length = MIN(remain, pcm_buffer->frame_length());
            if (frame_length > 0) {
                pcm_buffer->set_frame_length(frame_length);
                auto write_result = file_writer->write_from_buffer(pcm_buffer);
                if (!write_result) {
                    std::cout << __PRETTY_FUNCTION__ << " - error:" << yas::to_string(write_result.error())
                              << std::endl;
                }
            }

            remain -= frame_length;
            if (remain == 0) {
                file_writer->close();
                *stop = YES;
            }
        } completionBlock:^(BOOL cancelled) {
            self.processing = NO;
        } error:&error]) {
        self.processing = NO;
        NSLog(@"%s start offline render error = %@", __PRETTY_FUNCTION__, error);
    };
}

@end
