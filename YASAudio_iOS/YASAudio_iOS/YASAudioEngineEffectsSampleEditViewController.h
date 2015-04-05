//
//  YASAudioEngineEffectsSampleEditViewController.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>

@class YASAudioUnitNode;

@interface YASAudioEngineEffectsSampleEditViewController : UITableViewController

@property (nonatomic, strong) YASAudioUnitNode *audioUnitNode;

@end
