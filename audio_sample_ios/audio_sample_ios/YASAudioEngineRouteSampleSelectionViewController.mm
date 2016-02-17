//
//  YASAudioEngineRouteSampleSelectionViewController.mm
//

#import "YASAudioEngineRouteSampleSelectionViewController.h"
#import "YASAudioEngineRouteSampleViewController.h"
#import "yas_audio.h"

@interface YASAudioEngineRouteSampleSelectionViewController ()

@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@end

@implementation YASAudioEngineRouteSampleSelectionViewController

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
    if ([destinationViewController isKindOfClass:[YASAudioEngineRouteSampleViewController class]]) {
        self.selectedIndexPath = [self.tableView indexPathForCell:cell];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return YASAudioEngineRouteSampleSelectionSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case YASAudioEngineRouteSampleSelectionSectionNone:
            return 1;
        case YASAudioEngineRouteSampleSelectionSectionSine:
        case YASAudioEngineRouteSampleSelectionSectionInput:
            return 2;
        default:
            break;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    switch (indexPath.section) {
        case YASAudioEngineRouteSampleSelectionSectionNone:
            cell.textLabel.text = @"None";
            break;
        case YASAudioEngineRouteSampleSelectionSectionSine:
            cell.textLabel.text = [NSString stringWithFormat:@"Sine ch : %@", @(indexPath.row)];
            break;
        case YASAudioEngineRouteSampleSelectionSectionInput:
            cell.textLabel.text = [NSString stringWithFormat:@"Input ch : %@", @(indexPath.row)];
            break;

        default:
            break;
    }

    return cell;
}

@end
