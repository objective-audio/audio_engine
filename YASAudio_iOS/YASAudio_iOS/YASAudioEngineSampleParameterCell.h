//
//  YASAudioEngineSampleParameterCell.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>

@class YASAudioUnitParameter, YASAudioUnitNode;

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)setParameterInfo:(YASAudioUnitParameter *)parameterInfo node:(YASAudioUnitNode *)node;

@end
