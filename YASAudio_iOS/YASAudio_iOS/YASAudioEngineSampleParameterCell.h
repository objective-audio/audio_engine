//
//  YASAudioEngineSampleParameterCell.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>
#import <memory>

namespace yas
{
    class audio_unit_parameter;
    class audio_unit_node;

    using audio_unit_node_ptr = std::shared_ptr<audio_unit_node>;
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_node:(const yas::audio_unit_node_ptr &)node index:(const uint32_t)index;

@end
