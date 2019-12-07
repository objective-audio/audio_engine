//
//  YASAudioEngineSampleParameterCell.h
//

#import <UIKit/UIKit.h>
#import <audio/yas_audio_ptr.h>
#import <memory>
#import <optional>

namespace yas::audio::engine {
class avf_au;
}

@interface YASAudioEngineSampleParameterCell : UITableViewCell

- (void)set_parameter:(yas::audio::avf_au_parameter_ptr const &)parameter;

@end
