//
//  YASAudioGraphSampleParameterCell.h
//

#import <UIKit/UIKit.h>
#import <audio-engine/common/yas_audio_ptr.h>
#import <memory>
#import <optional>

@interface YASAudioGraphSampleParameterCell : UITableViewCell

- (void)set_parameter:(yas::audio::avf_au_parameter_ptr const &)parameter;

@end
