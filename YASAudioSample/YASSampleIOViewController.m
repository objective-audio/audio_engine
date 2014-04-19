//
//  YASSampleIOViewController.m
//  YASAudioSample
//
//  Created by Yuki Yasoshima on 2014/02/03.
//  Copyright (c) 2014年 Yuki Yasoshima. All rights reserved.
//

#import "YASSampleIOViewController.h"
#import "YASSampleIOGraph.h"
#import "YASAudioUtilities.h"

@interface YASSampleIOViewController ()
@property (nonatomic, strong) YASSampleIOGraph *graph;
@property (nonatomic, assign) IBOutlet UISlider *volumeSlider;
@end

@implementation YASSampleIOViewController

- (void)dealloc
{
    YASRelease(_graph);
    YASSuperDealloc;
}

- (void)viewDidAppear:(BOOL)animated
{
    self.graph = [YASSampleIOGraph sampleIOGraph];
    [self volume:self.volumeSlider];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [_graph invalidate];
    self.graph = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)volume:(UISlider *)sender
{
    self.graph.inputVolume = sender.value;
}

@end
