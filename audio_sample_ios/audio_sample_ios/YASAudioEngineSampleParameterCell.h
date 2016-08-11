//
//  YASAudioEngineSampleParameterCell.h
//

#import <UIKit/UIKit.h>
#import <experimental/optional>
#import <memory>

namespace yas {
namespace audio {
    class unit_extension;
}
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_extension:(const std::experimental::optional<yas::audio::unit_extension> &)ext_opt
                index:(uint32_t const)index;

@end
