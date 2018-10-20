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
    std::optional<audio::engine::au> _au_opt;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)set_engine_au:(audio::engine::au const &)au {
    _au_opt = au;

    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_au_opt) {
        return _au_opt->global_parameters().size();
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YASAudioEngineSampleParameterCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"ParameterCell" forIndexPath:indexPath];

    [cell set_engine_au:*_au_opt index:static_cast<uint32_t>(indexPath.row)];

    return cell;
}

@end
