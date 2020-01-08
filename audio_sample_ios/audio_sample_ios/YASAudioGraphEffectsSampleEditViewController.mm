//
//  YASAudioGraphEffectsSampleEditViewController.m
//

#import "YASAudioGraphEffectsSampleEditViewController.h"
#import <audio/yas_audio_umbrella.h>
#import "YASAudioGraphSampleParameterCell.h"

using namespace yas;

@interface YASAudioGraphEffectsSampleEditViewController ()

@end

@implementation YASAudioGraphEffectsSampleEditViewController {
    audio::graph_avf_au_ptr _au;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)set_graph_au:(audio::graph_avf_au_ptr const &)au {
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
    YASAudioGraphSampleParameterCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"ParameterCell" forIndexPath:indexPath];

    auto const &parameter = self->_au->raw_au()->global_parameters().at(indexPath.row);
    [cell set_parameter:parameter];

    return cell;
}

@end
