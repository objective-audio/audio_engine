//
//  YASAudioSliderCell.h
//

#import <UIKit/UIKit.h>
#import <objc-utils/macros.h>

@interface YASAudioSliderCell : UITableViewCell

@property (nonatomic, yas_weak_for_property) IBOutlet UISlider *slider;

@end
