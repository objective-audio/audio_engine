//
//  YASAudioEngineEffectsSampleEditViewController.h
//

#import <UIKit/UIKit.h>
#import <memory>

namespace yas {
namespace audio {
    class unit_extension;
}
}

@interface YASAudioEngineEffectsSampleEditViewController : UITableViewController

- (void)set_audio_unit_extension:(const yas::audio::unit_extension &)node;

@end
