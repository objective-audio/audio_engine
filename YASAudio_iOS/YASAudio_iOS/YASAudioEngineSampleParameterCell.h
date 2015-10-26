//
//  YASAudioEngineSampleParameterCell.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>
#import <memory>
#import <experimental/optional>

namespace yas
{
    class audio_unit_node;
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_node:(const std::experimental::optional<yas::audio_unit_node> &)node_opt index:(const UInt32)index;

@end
