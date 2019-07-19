//
//  YASAudioEngineEffectsSampleEditViewController.h
//

#import <UIKit/UIKit.h>
#import <memory>

namespace yas::audio::engine {
class au;
}

@interface YASAudioEngineEffectsSampleEditViewController : UITableViewController

- (void)set_engine_au:(yas::audio::engine::au &)node;

@end
