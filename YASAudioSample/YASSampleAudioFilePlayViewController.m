//
//  YASSampleAudioFilePlayViewController.m
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/02/05.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASSampleAudioFilePlayViewController.h"
#import "YASSampleAudioFilePlayGraph.h"

@interface YASSampleAudioFilePlayViewController ()
@property (nonatomic, strong) YASSampleAudioFilePlayGraph *graph;
@property (nonatomic, assign) IBOutlet UIButton *playButton;
@property (nonatomic, assign) IBOutlet UIButton *stopButton;
@property (nonatomic, assign) IBOutlet UISlider *volumeSlider;
@end

@implementation YASSampleAudioFilePlayViewController

- (void)dealloc
{
    [_graph release];
    [super dealloc];
}

- (void)viewDidAppear:(BOOL)animated
{
    self.graph = [YASSampleAudioFilePlayGraph sampleAudioFilePlayGraph];
    
    [self volume:self.volumeSlider];
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

- (IBAction)play:(UIButton *)sender
{
    [self.graph play];
    [self _updateUI];
}

- (IBAction)stop:(UIButton *)sender
{
    [self.graph stop];
    [self _updateUI];
}

- (IBAction)loadStrings:(UIButton *)sender
{
    NSURL *url = [[NSBundle mainBundle] URLForAuxiliaryExecutable:@"PastralAll.wav"];
    
    [self.graph setAudioFileURL:url];
    [self.graph play];
    [self _updateUI];
}

- (IBAction)loadRhythm:(UIButton *)sender
{
    NSURL *url = [[NSBundle mainBundle] URLForAuxiliaryExecutable:@"NeonFireworksBeat.wav"];
    
    [self.graph setAudioFileURL:url];
    [self.graph play];
    [self _updateUI];
}

- (IBAction)volume:(UISlider *)sender
{
    self.graph.volume = sender.value;
}

- (void)_updateUI
{
    self.playButton.enabled = !self.graph.isPlaying;
    self.stopButton.enabled = self.graph.isPlaying;
}

@end
