//
//  YASAudioEngineRouteSampleSelectionViewController.h
//

#import <UIKit/UIKit.h>
#include <cstddef>

namespace yas::route_sample {
enum class selection_section {
    none,
    sine,
    input,
};
static std::size_t constexpr selection_section_count = 3;
}  // namespace yas::route_sample

@interface YASAudioGraphRouteSampleSelectionViewController : UITableViewController

@property (nonatomic) uint32_t outputChannelCount;
@property (nonatomic) uint32_t inputChannelCount;
@property (nonatomic, strong) NSIndexPath *fromCellIndexPath;
@property (nonatomic, strong, readonly) NSIndexPath *selectedIndexPath;

@end
