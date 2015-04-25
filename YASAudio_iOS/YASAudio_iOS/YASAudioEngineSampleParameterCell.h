//
//  YASAudioEngineSampleParameterCell.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>

@class YASAudioUnitParameter, YASAudioUnitNode;

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)setParameter:(YASAudioUnitParameter *)parameter node:(YASAudioUnitNode *)node;

@end
