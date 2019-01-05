//
//  YASAudioSliderCell.h
//

#import <UIKit/UIKit.h>
#import <objc_utils/yas_objc_macros.h>

@interface YASAudioSliderCell : UITableViewCell

@property (nonatomic, yas_weak_for_property) IBOutlet UISlider *slider;

@end
