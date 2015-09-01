//
//  YASAudioEngineIOSampleSelectionViewController.h
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import <UIKit/UIKit.h>

@interface YASAudioEngineIOSampleSelectionViewController : UITableViewController

@property (nonatomic, strong) NSIndexPath *fromCellIndexPath;
@property (nonatomic, assign) NSInteger channelCount;
@property (nonatomic, assign, readonly) UInt32 selectedValue;

@end
