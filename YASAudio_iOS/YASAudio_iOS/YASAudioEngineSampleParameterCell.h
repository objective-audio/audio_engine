//
//  YASAudioEngineSampleParameterCell.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>
#import <memory>
#import "yas_audio.h"

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_node:(const yas::audio_unit_node_sptr &)node index:(const uint32_t)index;

@end
