//
//  YASAudioEngineEffectsSampleEditViewController.h
//

#import <UIKit/UIKit.h>
#import <audio/yas_audio_engine_ptr.h>
#import <memory>

@interface YASAudioEngineEffectsSampleEditViewController : UITableViewController

- (void)set_engine_au:(yas::audio::engine::avf_au_ptr const &)node;

@end
