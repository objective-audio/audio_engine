//
//  YASAudioEngineSampleParameterCell.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>
#import <memory>

namespace yas {
    class audio_unit_node;
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_node:(const std::shared_ptr<yas::audio_unit_node> &)node index:(const UInt32)index;

@end
