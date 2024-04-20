//
//  YASAudioGraphRouteSampleSelectionViewController.mm
//

#import "YASAudioGraphRouteSampleSelectionViewController.h"
#import <audio/yas_audio_umbrella.h>
#import <objc-utils/yas_objc_macros.h>
#import "YASAudioGraphRouteSampleViewController.h"

using namespace yas;

@interface YASAudioGraphRouteSampleSelectionViewController ()

@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@end

@implementation YASAudioGraphRouteSampleSelectionViewController

- (void)dealloc {
    yas_release(_fromCellIndexPath);
    yas_release(_selectedIndexPath);

    _fromCellIndexPath = nil;
    _selectedIndexPath = nil;

    yas_super_dealloc();
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(UITableViewCell *)cell {
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioGraphRouteSampleViewController class]]) {
        self.selectedIndexPath = [self.tableView indexPathForCell:cell];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return route_sample::selection_section_count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (route_sample::selection_section(section)) {
        case route_sample::selection_section::none:
            return 1;
        case route_sample::selection_section::sine:
            return self.outputChannelCount;
        case route_sample::selection_section::input:
            return self.inputChannelCount;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    switch (route_sample::selection_section(indexPath.section)) {
        case route_sample::selection_section::none:
            cell.textLabel.text = @"None";
            break;
        case route_sample::selection_section::sine:
            cell.textLabel.text = [NSString stringWithFormat:@"Sine ch : %@", @(indexPath.row)];
            break;
        case route_sample::selection_section::input:
            cell.textLabel.text = [NSString stringWithFormat:@"Input ch : %@", @(indexPath.row)];
            break;
    }

    return cell;
}

@end
