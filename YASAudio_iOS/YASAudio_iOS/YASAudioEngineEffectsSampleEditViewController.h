//
//  YASAudioEngineEffectsSampleEditViewController.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>
#import <memory>

namespace yas
{
    class audio_unit_node;
}

@interface YASAudioEngineEffectsSampleEditViewController : UITableViewController

- (void)set_audio_unit_node:(const std::shared_ptr<yas::audio_unit_node> &)node;

@end
