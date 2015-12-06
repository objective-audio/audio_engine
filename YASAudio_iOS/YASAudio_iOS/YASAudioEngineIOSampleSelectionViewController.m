//
//  YASAudioEngineIOSampleSelectionViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineIOSampleSelectionViewController.h"
#import "YASAudioEngineIOSampleViewController.h"
#import "yas_objc_macros.h"

@interface YASAudioEngineIOSampleSelectionViewController ()

@end

@implementation YASAudioEngineIOSampleSelectionViewController

- (void)dealloc {
    YASRelease(_fromCellIndexPath);

    _fromCellIndexPath = nil;

    YASSuperDealloc;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell {
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineIOSampleViewController class]]) {
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        _selectedValue = (UInt32)[self valueAtIndex:indexPath.row];
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
