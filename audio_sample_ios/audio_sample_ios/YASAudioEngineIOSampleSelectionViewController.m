//
//  YASAudioEngineIOSampleSelectionViewController.m
//

#import "YASAudioEngineIOSampleSelectionViewController.h"
#import <objc_utils/yas_objc_macros.h>
#import "YASAudioEngineIOSampleViewController.h"

@interface YASAudioEngineIOSampleSelectionViewController ()

@end

@implementation YASAudioEngineIOSampleSelectionViewController

- (void)dealloc {
    yas_release(_fromCellIndexPath);

    _fromCellIndexPath = nil;

    yas_super_dealloc();
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell {
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineIOSampleViewController class]]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        _selectedValue = (uint32_t)[self valueAtIndex:indexPath.row];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.channelCount + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = [NSString stringWithFormat:@"%@", @([self valueAtIndex:indexPath.row])];
    return cell;
}

- (NSInteger)valueAtIndex:(NSInteger)idx {
    return idx < self.channelCount ? idx : -1;
}

@end
