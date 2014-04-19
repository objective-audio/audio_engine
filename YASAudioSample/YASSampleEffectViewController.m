//
//  YASViewController.m
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/01/13.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASSampleEffectViewController.h"
#import "YASAudio.h"
#import "YASSampleEffectGraph.h"
#import <AVFoundation/AVFoundation.h>

@interface YASSampleEffectViewController ()
@property (nonatomic, strong) YASSampleEffectGraph *graph;
@property (nonatomic, assign) IBOutlet UISlider *sineVolumeSlider;
@property (nonatomic, assign) IBOutlet UISlider *noiseVolumeSlider;
@property (nonatomic, assign) IBOutlet UISlider *delayMixSlider;
@property (nonatomic, assign) IBOutlet UISlider *delayTimeSlider;
@property (nonatomic, assign) IBOutlet UISlider *delayFeedbackSlider;
@property (nonatomic, assign) IBOutlet UIButton *setupNodesButton;
@property (nonatomic, assign) IBOutlet UIButton *disposeNodesButton;
@property (nonatomic, assign) IBOutlet UIButton *addDelayConnectionButton;
@property (nonatomic, assign) IBOutlet UIButton *removeDelayConnectionButton;
@end

@implementation YASSampleEffectViewController

- (void)dealloc
{
    self.graph = nil;
    YASSuperDealloc;
}

- (void)viewDidAppear:(BOOL)animated
{
    self.graph = [YASSampleEffectGraph sampleGraph];
    [self.graph setupNodes];
    
    [self sineVolume:self.sineVolumeSlider];
    [self noiseVolume:self.noiseVolumeSlider];
    [self delayMix:self.delayMixSlider];
    [self delayTime:self.delayTimeSlider];
    [self delayFeedback:self.delayFeedbackSlider];
    
    [self _updateUI];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.graph invalidate];
    self.graph = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)sineVolume:(UISlider *)sender
{
    [self.graph setMixerVolume:sender.value atBusIndex:0];
}

- (IBAction)noiseVolume:(UISlider *)sender
{
    [self.graph setMixerVolume:sender.value atBusIndex:1];
}

- (IBAction)delayMix:(UISlider *)sender
{
    [self.graph setDelayMix:sender.value];
}

- (IBAction)delayTime:(UISlider *)sender
{
    [self.graph setDelayTime:sender.value];
}

- (IBAction)delayFeedback:(UISlider *)sender
{
    [self.graph setDelayFeedback:sender.value];
}

- (IBAction)addDelayConnection:(id)sender
{
    [self.graph addDelayConnection];
    [self _updateUI];
}

- (IBAction)removeDelayConnection:(id)sender
{
    [self.graph removeDelayConnection];
    [self _updateUI];
}

- (IBAction)setupNodes:(id)sender
{
    [self.graph setupNodes];
    [self _updateUI];
}

- (IBAction)disposeNodes:(id)sender
{
    [self.graph disposeNodes];
    [self _updateUI];
}

- (void)_updateUI
{
    if ([self.graph isNodesAvailable]) {
        self.setupNodesButton.enabled = NO;
        self.disposeNodesButton.enabled = YES;
        self.graph.running = YES;
    } else {
        self.setupNodesButton.enabled = YES;
        self.disposeNodesButton.enabled = NO;
    }
    
    if ([self.graph isDelayConnected]) {
        self.addDelayConnectionButton.enabled = NO;
        self.removeDelayConnectionButton.enabled = YES;
    } else {
        self.addDelayConnectionButton.enabled = [self.graph isNodesAvailable];
        self.removeDelayConnectionButton.enabled = NO;
    }
    
    [self sineVolume:self.sineVolumeSlider];
    [self delayMix:self.delayMixSlider];
    [self delayTime:self.delayTimeSlider];
    [self delayFeedback:self.delayFeedbackSlider];
}

@end
