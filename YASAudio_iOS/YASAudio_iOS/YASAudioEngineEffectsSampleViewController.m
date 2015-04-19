//
//  YASAudioEngineEffectsSampleViewController.m
//  Copyright (c) 2015 Yuki Yasoshima.
//

#import "YASAudioEngineEffectsSampleViewController.h"
#import "YASAudioEngineEffectsSampleEditViewController.h"
#import "YASAudio.h"

typedef NS_ENUM(NSUInteger, YASAudioEngineEffectsSampleSection) {
    YASAudioEngineEffectsSampleSectionNone,
    YASAudioEngineEffectsSampleSectionEffects,
    YASAudioEngineEffectsSampleSectionCount,
};

static const AudioComponentDescription baseAcd = {.componentType = kAudioUnitType_Effect,
                                                  .componentSubType = 0,
                                                  .componentManufacturer = kAudioUnitManufacturer_Apple,
                                                  .componentFlags = 0,
                                                  .componentFlagsMask = 0};

@interface YASAudioEngineEffectsSampleViewController ()

@property (nonatomic, strong) NSArray *audioUnits;
@property (nonatomic, strong) NSNumber *index;

@property (nonatomic, strong) YASAudioEngine *engine;
@property (nonatomic, strong) YASAudioUnitOutputNode *outputNode;
@property (nonatomic, strong) YASAudioUnitNode *effectNode;
@property (nonatomic, strong) YASAudioConnection *throughConnection;
@property (nonatomic, strong) YASAudioTapNode *tapNode;

@end

@implementation YASAudioEngineEffectsSampleViewController

- (void)dealloc
{
    YASRelease(_engine);
    YASRelease(_outputNode);
    YASRelease(_effectNode);
    YASRelease(_tapNode);
    YASRelease(_throughConnection);
    YASRelease(_index);
    YASRelease(_audioUnits);

    _engine = nil;
    _outputNode = nil;
    _effectNode = nil;
    _tapNode = nil;
    _throughConnection = nil;
    _index = nil;
    _audioUnits = nil;

    YASSuperDealloc;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    NSMutableArray *audioUnits = [[NSMutableArray alloc] init];

    AudioComponent component = NULL;

    while (true) {
        component = AudioComponentFindNext(component, &baseAcd);
        if (component != NULL) {
            AudioComponentDescription acd;
            YASRaiseIfAUError(AudioComponentGetDescription(component, &acd));

            YASAudioUnit *audioUnit = [[YASAudioUnit alloc] initWithAudioComponentDescription:&acd];
            [audioUnits addObject:audioUnit];
            YASRelease(audioUnit);
        } else {
            break;
        }
    }

    NSArray *copiedAudioUnits = [audioUnits copy];
    self.audioUnits = copiedAudioUnits;
    YASRelease(copiedAudioUnits);
    YASRelease(audioUnits);

    [self setupAudioEngine];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    id destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[YASAudioEngineEffectsSampleEditViewController class]]) {
        YASAudioEngineEffectsSampleEditViewController *controller = destinationViewController;
        controller.audioUnitNode = self.effectNode;
    }
}

#pragma mark -

- (void)setupAudioEngine
{
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    if (![audioSession setCategory:AVAudioSessionCategoryPlayback error:&error]) {
        [self _showErrorAlertWithMessage:error.description];
        return;
    }

    YASAudioEngine *engine = [[YASAudioEngine alloc] init];
    self.engine = engine;
    YASRelease(engine);

    YASAudioUnitOutputNode *outputNode = [[YASAudioUnitOutputNode alloc] init];
    self.outputNode = outputNode;
    YASRelease(outputNode);

    YASAudioTapNode *tapNode = [[YASAudioTapNode alloc] init];
    self.tapNode = tapNode;
    YASRelease(tapNode);

    __block Float64 phase = 0;

    tapNode.renderBlock = ^(YASAudioData *data, NSNumber *bus, YASAudioTime *when, id nodeCore) {
        const Float64 startPhase = phase;
        const Float64 phasePerFrame = 1000.0 / data.format.sampleRate * YAS_2_PI;
        YASAudioMutableFrameScanner *scanner = [[YASAudioMutableFrameScanner alloc] initWithAudioData:data];
        const YASAudioMutablePointer *pointer = scanner.mutablePointer;
        const UInt32 length = (UInt32)scanner.frameLength;
        while (pointer->v) {
            phase = YASAudioVectorSinef(pointer->f32, length, startPhase, phasePerFrame);
            YASAudioFrameScannerMoveChannel(scanner);
        }
        YASRelease(scanner);
    };

    [self replaceEffectNodeWithAudioComponentDescription:NULL];

    if (![engine startRender:&error]) {
        [self _showErrorAlertWithMessage:error.description];
    }
}

- (void)replaceEffectNodeWithAudioComponentDescription:(const AudioComponentDescription *)acd
{
    YASAudioEngine *engine = self.engine;

    if (self.effectNode) {
        [engine disconnectNode:self.effectNode];
        self.effectNode = nil;
    }

    if (self.throughConnection) {
        [engine disconnect:self.throughConnection];
        self.throughConnection = nil;
    }

    YASAudioFormat *format =
        [[YASAudioFormat alloc] initStandardFormatWithSampleRate:[AVAudioSession sharedInstance].sampleRate channels:2];

    if (acd) {
        YASAudioUnitNode *effectNode = [[YASAudioUnitNode alloc] initWithAudioComponentDescription:acd];
        self.effectNode = effectNode;
        YASRelease(effectNode);

        [engine connectFromNode:effectNode toNode:self.outputNode format:format];
        [engine connectFromNode:self.tapNode toNode:effectNode format:format];
    } else {
        self.throughConnection = [engine connectFromNode:self.tapNode toNode:self.outputNode format:format];
    }

    YASRelease(format);
}

#pragma mark -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return YASAudioEngineEffectsSampleSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case YASAudioEngineEffectsSampleSectionNone:
            return 1;
        case YASAudioEngineEffectsSampleSectionEffects:
            return self.audioUnits.count;
        default:
            return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self _dequeueCellWithIndexPath:indexPath];

    if (indexPath.section == 0) {
        cell.textLabel.text = @"None";
        if (!self.index) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    } else {
        YASAudioUnit *audioUnit = self.audioUnits[indexPath.row];
        cell.textLabel.text = audioUnit.name;
        if (self.index && indexPath.row == self.index.integerValue) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case YASAudioEngineEffectsSampleSectionNone: {
            self.index = nil;
            [self replaceEffectNodeWithAudioComponentDescription:NULL];
        } break;
        case YASAudioEngineEffectsSampleSectionEffects: {
            self.index = @(indexPath.row);
            AudioComponentDescription acd = baseAcd;
            YASAudioUnit *audioUnit = self.audioUnits[indexPath.row];
            acd.componentSubType = audioUnit.subType;
            [self replaceEffectNodeWithAudioComponentDescription:&acd];
        } break;
    }

    [tableView
          reloadSections:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, YASAudioEngineEffectsSampleSectionCount)]
        withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Private

- (void)_showErrorAlertWithMessage:(NSString *)message
{
    UIAlertController *controller = [UIAlertController alertControllerWithTitle:@"Error"
                                                                        message:@"Can't start audio engine."
                                                                 preferredStyle:UIAlertControllerStyleAlert];
    [controller addAction:[UIAlertAction actionWithTitle:@"OK"
                                                   style:UIAlertActionStyleDefault
                                                 handler:^(UIAlertAction *action) {
                                                     [self.navigationController popViewControllerAnimated:YES];
                                                 }]];
    [self presentViewController:controller animated:YES completion:NULL];
}

- (UITableViewCell *)_dequeueCellWithIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    return cell;
}

@end
