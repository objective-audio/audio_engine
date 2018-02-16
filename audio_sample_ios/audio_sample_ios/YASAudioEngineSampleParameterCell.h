//
//  YASAudioEngineSampleParameterCell.h
//

#import <UIKit/UIKit.h>
#import <experimental/optional>
#import <memory>

namespace yas::audio::engine {
class au;
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_engine_au:(const std::experimental::optional<yas::audio::engine::au> &)node_opt index:(uint32_t const)index;

@end
