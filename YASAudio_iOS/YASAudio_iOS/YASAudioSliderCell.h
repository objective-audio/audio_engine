//
//  YASAudioSliderCell.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>
#import "yas_objc_macros.h"

@interface YASAudioSliderCell : UITableViewCell

@property (nonatomic, yas_weak_for_property) IBOutlet UISlider *slider;

@end
