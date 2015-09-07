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
    yas::audio_unit_node_sptr _node;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)set_audio_unit_node:(const std::shared_ptr<yas::audio_unit_node> &)node
{
    _node = node;

    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _node->global_parameters().size();
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    YASAudioEngineSampleParameterCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"ParameterCell" forIndexPath:indexPath];

    [cell set_node:_node index:static_cast<UInt32>(indexPath.row)];

    return cell;
}

@end
