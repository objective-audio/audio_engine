//
//  YASAudioGraphEffectsSampleEditViewController.h
//

#import <UIKit/UIKit.h>
#import <audio/common/yas_audio_ptr.h>
#import <memory>

@interface YASAudioGraphEffectsSampleEditViewController : UITableViewController

- (void)set_graph_au:(yas::audio::graph_avf_au_ptr const &)node;

@end
