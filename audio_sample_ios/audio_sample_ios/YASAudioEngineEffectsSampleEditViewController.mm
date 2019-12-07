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
    audio::engine::avf_au_ptr _au;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)set_engine_au:(audio::engine::avf_au_ptr const &)au {
    self->_au = au;

    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self->_au) {
        return self->_au->raw_au()->global_parameters().size();
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YASAudioEngineSampleParameterCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"ParameterCell" forIndexPath:indexPath];

    auto const &parameter = self->_au->raw_au()->global_parameters().at(indexPath.row);
    [cell set_parameter:parameter];

    return cell;
}

@end
