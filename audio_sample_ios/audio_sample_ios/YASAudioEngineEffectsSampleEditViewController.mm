//
//  YASAudioEngineEffectsSampleEditViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineEffectsSampleEditViewController.h"
#import "YASAudioEngineSampleParameterCell.h"
#import "yas_audio.h"

@interface YASAudioEngineEffectsSampleEditViewController ()

@end

@implementation YASAudioEngineEffectsSampleEditViewController {
    std::experimental::optional<yas::audio::unit_node> _node_opt;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)set_audio_unit_node:(const yas::audio::unit_node &)node {
    _node_opt = node;

    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_node_opt) {
        return _node_opt->global_parameters().size();
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    YASAudioEngineSampleParameterCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"ParameterCell" forIndexPath:indexPath];

    [cell set_node:*_node_opt index:static_cast<UInt32>(indexPath.row)];

    return cell;
}

@end
