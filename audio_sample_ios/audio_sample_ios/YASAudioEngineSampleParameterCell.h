//
//  YASAudioEngineSampleParameterCell.h
//

#import <UIKit/UIKit.h>
#import <experimental/optional>
#import <memory>

namespace yas {
namespace audio {
    class unit_node;
}
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_node:(const std::experimental::optional<yas::audio::unit_node> &)node_opt index:(uint32_t const)index;

@end
