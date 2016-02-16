//
//  YASAudioSliderCell.h
//

#import <UIKit/UIKit.h>
#import "yas_objc_macros.h"

@interface YASAudioSliderCell : UITableViewCell

@property (nonatomic, yas_weak_for_property) IBOutlet UISlider *slider;

@end
