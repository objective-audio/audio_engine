//
//  YASAudioEngineEffectsSampleEditViewController.h
//

#import <UIKit/UIKit.h>
#import <memory>

namespace yas {
namespace audio {
    class unit_node;
}
}

@interface YASAudioEngineEffectsSampleEditViewController : UITableViewController

- (void)set_audio_unit_node:(const yas::audio::engine::unit_node &)node;

@end
