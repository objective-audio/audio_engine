//
//  YASAudioEngineSampleParameterCell.h
//

#import <UIKit/UIKit.h>
#import <memory>
#import <experimental/optional>

namespace yas {
namespace audio {
    class unit_node;
}
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_node:(const std::experimental::optional<yas::audio::unit_node> &)node_opt index:(const UInt32)index;

@end
