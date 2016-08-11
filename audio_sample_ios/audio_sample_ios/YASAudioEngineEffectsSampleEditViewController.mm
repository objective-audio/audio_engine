//
//  YASAudioEngineEffectsSampleEditViewController.m
//

#import "YASAudioEngineEffectsSampleEditViewController.h"
#import "YASAudioEngineSampleParameterCell.h"
#import "yas_audio.h"

using namespace yas;

@interface YASAudioEngineEffectsSampleEditViewController ()

@end

@implementation YASAudioEngineEffectsSampleEditViewController {
    std::experimental::optional<audio::unit_extension> _ext_opt;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)set_audio_unit_extension:(const audio::unit_extension &)ext {
    _ext_opt = ext;

    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_ext_opt) {
        return _ext_opt->global_parameters().size();
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YASAudioEngineSampleParameterCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"ParameterCell" forIndexPath:indexPath];

    [cell set_extension:*_ext_opt index:static_cast<uint32_t>(indexPath.row)];

    return cell;
}

@end
