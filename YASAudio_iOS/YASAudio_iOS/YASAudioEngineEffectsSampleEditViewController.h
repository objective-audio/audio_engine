//
//  YASAudioEngineEffectsSampleEditViewController.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>
#import <memory>

namespace yas {
namespace audio {
    class unit_node;
}
}

@interface YASAudioEngineEffectsSampleEditViewController : UITableViewController

- (void)set_audio_unit_node:(const yas::audio::unit_node &)node;

@end
