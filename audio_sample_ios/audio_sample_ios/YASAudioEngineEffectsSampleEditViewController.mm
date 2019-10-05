//
//  YASAudioEngineEffectsSampleEditViewController.m
//

#import "YASAudioEngineEffectsSampleEditViewController.h"
#import <audio/yas_audio_umbrella.h>
#import "YASAudioEngineSampleParameterCell.h"

using namespace yas;

@interface YASAudioEngineEffectsSampleEditViewController ()

@end

@implementation YASAudioEngineEffectsSampleEditViewController {
    audio::engine::au_ptr _au;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)set_engine_au:(audio::engine::au_ptr const &)au {
    _au = au;

    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_au) {
        return _au->global_parameters().size();
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YASAudioEngineSampleParameterCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"ParameterCell" forIndexPath:indexPath];

    [cell set_engine_au:_au index:static_cast<uint32_t>(indexPath.row)];

    return cell;
}

@end
