//
//  YASAudioGraphSampleParameterCell.h
//

#import <UIKit/UIKit.h>
#import <audio-engine/common/ptr.h>
#import <memory>
#import <optional>

@interface YASAudioGraphSampleParameterCell : UITableViewCell

- (void)set_parameter:(yas::audio::avf_au_parameter_ptr const &)parameter;

@end
