//
//  YASAudioEngineEffectsSampleEditViewController.h
//

#import <UIKit/UIKit.h>
#import <memory>

namespace yas {
namespace audio {
    namespace engine {
        class au;
    }
}
}

@interface YASAudioEngineEffectsSampleEditViewController : UITableViewController

- (void)set_engine_au:(yas::audio::engine::au const &)node;

@end
