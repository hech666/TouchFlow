#import "HaogeTouchFlowPanelSettings.h"
#import "HaogeTouchFlowPanelModel.h"
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import <math.h>

static void haoge_touchflow_panelError(UIViewController *controller,NSError *error) {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"设置未保存" message:error.localizedDescription?:@"无法写入配置。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];[controller presentViewController:alert animated:YES completion:nil];
}
@interface HaogeTouchFlowPanelItemEditor : UITableViewController
@property (nonatomic, strong) NSMutableDictionary *haoge_touchflow_item;
@property (nonatomic, copy) void (^haoge_touchflow_saveBlock)(NSDictionary *);
@end
@implementation HaogeTouchFlowPanelItemEditor
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad {
    [super viewDidLoad];self.title=@"编辑面板动作";
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(haoge_touchflow_done)];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView;return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;return section==0?3:(NSInteger)haoge_touchflow_actionCatalog().count-1; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;return section==0?@"参数用于应用 Bundle ID、快捷指令名称或完整 URL。名称和图标可留空，使用动作默认值。图标填写 SF Symbol 名称，例如 bolt.fill。":@"选择动作后点击右上角保存。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if (path.section==0) {
        NSString *key=@[@"value",@"title",@"symbol"][(NSUInteger)path.row];cell.textLabel.text=@[@"动作参数",@"显示名称",@"图标符号"][(NSUInteger)path.row];
        NSString *text=[self.haoge_touchflow_item[key] isKindOfClass:[NSString class]]?self.haoge_touchflow_item[key]:@"";
        cell.detailTextLabel.text=text.length?text:@"点击填写";cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSDictionary *entry=haoge_touchflow_actionCatalog()[(NSUInteger)path.row+1];cell.textLabel.text=entry[@"title"];cell.detailTextLabel.text=entry[@"detail"];
        if ([self.haoge_touchflow_item[@"action"] isEqual:entry[@"identifier"]]) cell.accessoryType=UITableViewCellAccessoryCheckmark;
    }return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section==1) { self.haoge_touchflow_item[@"action"]=haoge_touchflow_actionCatalog()[(NSUInteger)path.row+1][@"identifier"];[tableView reloadData];return; }
    NSString *key=@[@"value",@"title",@"symbol"][(NSUInteger)path.row];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@[@"动作参数",@"显示名称",@"图标符号"][(NSUInteger)path.row] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *input) {
        input.text=self.haoge_touchflow_item[key];input.autocorrectionType=UITextAutocorrectionTypeNo;input.autocapitalizationType=UITextAutocapitalizationTypeNone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;NSString *text=[alert.textFields.firstObject.text?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        self.haoge_touchflow_item[key]=[text substringToIndex:MIN(text.length,4096u)];[self.tableView reloadData];
    }]];[self presentViewController:alert animated:YES completion:nil];
}
- (void)haoge_touchflow_done {
    NSString *action=self.haoge_touchflow_item[@"action"],*value=self.haoge_touchflow_item[@"value"];
    if (haoge_touchflow_actionNeedsValue(action) && !value.length) {
        haoge_touchflow_panelError(self,[NSError errorWithDomain:HaogeTouchFlowPreferencesDomain code:20 userInfo:@{NSLocalizedDescriptionKey:@"这个动作需要填写参数。"}]);return;
    }
    if ([action isEqual:@"openURL"] && ![NSURL URLWithString:value].scheme.length) {
        haoge_touchflow_panelError(self,[NSError errorWithDomain:HaogeTouchFlowPreferencesDomain code:21 userInfo:@{NSLocalizedDescriptionKey:@"请输入包含协议的完整 URL。"}]);return;
    }
    if (self.haoge_touchflow_saveBlock) self.haoge_touchflow_saveBlock([self.haoge_touchflow_item copy]);
}
@end

@interface HaogeTouchFlowPanelItemsController ()
@property (nonatomic, copy) NSString *haoge_touchflow_trigger;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *haoge_touchflow_items;
@end
@implementation HaogeTouchFlowPanelItemsController
+ (instancetype)haoge_touchflow_controllerWithTrigger:(NSString *)trigger {
    HaogeTouchFlowPanelItemsController *controller=[[self alloc] initWithStyle:UITableViewStyleInsetGrouped];controller.haoge_touchflow_trigger=trigger;return controller;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.title=@"面板动作";self.navigationItem.rightBarButtonItems=@[
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(haoge_touchflow_add)],self.editButtonItem];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];self.haoge_touchflow_items=[haoge_touchflow_panelItems(haoge_touchflow_binding(haoge_touchflow_readPreferences(),self.haoge_touchflow_trigger)[@"panelItems"]) mutableCopy];[self.tableView reloadData];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;(void)section;return (NSInteger)self.haoge_touchflow_items.count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;(void)section;return @"点击 ＋ 添加动作，点击行编辑参数、名称和图标。点击编辑可以删除或拖动排序。最多 30 项；空面板不会接管手势。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;NSDictionary *item=self.haoge_touchflow_items[(NSUInteger)path.row];
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text=haoge_touchflow_panelItemTitle(item);cell.detailTextLabel.text=haoge_touchflow_actionTitle(item[@"action"]);
    cell.imageView.image=[UIImage systemImageNamed:[item[@"symbol"] length]?item[@"symbol"]:haoge_touchflow_actionSymbol(item[@"action"])];
    cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
}
- (BOOL)haoge_touchflow_saveItems:(NSArray *)items {
    NSDictionary *values=haoge_touchflow_readPreferences();id saved=values[HaogeTouchFlowBindingsKey];
    NSMutableDictionary *bindings=[saved isKindOfClass:[NSDictionary class]]?[saved mutableCopy]:[NSMutableDictionary dictionary];
    NSMutableDictionary *binding=[haoge_touchflow_binding(values,self.haoge_touchflow_trigger) mutableCopy];binding[@"panelItems"]=haoge_touchflow_panelItems(items);bindings[self.haoge_touchflow_trigger]=binding;
    NSError *error=nil;
    if (!haoge_touchflow_writePreference(HaogeTouchFlowBindingsKey,bindings,&error)) { haoge_touchflow_panelError(self,error);[self.tableView reloadData];return NO; }
    self.haoge_touchflow_items=[binding[@"panelItems"] mutableCopy];[self.tableView reloadData];return YES;
}
- (void)haoge_touchflow_editItem:(NSDictionary *)item {
    HaogeTouchFlowPanelItemEditor *editor=[HaogeTouchFlowPanelItemEditor new];editor.haoge_touchflow_item=[item mutableCopy];
    __weak typeof(self) weakSelf=self;__weak typeof(editor) weakEditor=editor;
    editor.haoge_touchflow_saveBlock=^(NSDictionary *updated) {
        typeof(self) strongSelf=weakSelf;if (!strongSelf) return;
        NSMutableArray *items=[strongSelf.haoge_touchflow_items mutableCopy];NSUInteger found=[items indexOfObjectPassingTest:^BOOL(NSDictionary *row,NSUInteger index,BOOL *stop) {(void)index;(void)stop;return [row[@"id"] isEqual:updated[@"id"]];}];
        if (found==NSNotFound) { if (items.count>=30) return;[items addObject:updated]; } else items[found]=updated;
        // Save errors must be presented on the visible editor, not its hidden parent.
        NSDictionary *values=haoge_touchflow_readPreferences();id existing=values[HaogeTouchFlowBindingsKey];
        NSMutableDictionary *bindings=[existing isKindOfClass:[NSDictionary class]]?[existing mutableCopy]:[NSMutableDictionary dictionary];
        NSMutableDictionary *binding=[haoge_touchflow_binding(values,strongSelf.haoge_touchflow_trigger) mutableCopy];binding[@"panelItems"]=haoge_touchflow_panelItems(items);bindings[strongSelf.haoge_touchflow_trigger]=binding;NSError *error=nil;
        if (!haoge_touchflow_writePreference(HaogeTouchFlowBindingsKey,bindings,&error)) { haoge_touchflow_panelError(weakEditor,error);return; }
        strongSelf.haoge_touchflow_items=[binding[@"panelItems"] mutableCopy];[strongSelf.navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:editor animated:YES];
}
- (void)haoge_touchflow_add {
    if (self.haoge_touchflow_items.count>=30) return;
    [self haoge_touchflow_editItem:@{@"id":NSUUID.UUID.UUIDString,@"action":@"controlCenter",@"value":@"",@"title":@"",@"symbol":@""}];
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];[self haoge_touchflow_editItem:self.haoge_touchflow_items[(NSUInteger)path.row]];
}
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)path { (void)tableView;(void)path;return YES; }
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)path { (void)tableView;(void)path;return YES; }
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style forRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;if (style!=UITableViewCellEditingStyleDelete) return;NSMutableArray *items=[self.haoge_touchflow_items mutableCopy];[items removeObjectAtIndex:(NSUInteger)path.row];[self haoge_touchflow_saveItems:items];
}
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    (void)tableView;NSMutableArray *items=[self.haoge_touchflow_items mutableCopy];NSDictionary *item=items[(NSUInteger)from.row];[items removeObjectAtIndex:(NSUInteger)from.row];[items insertObject:item atIndex:(NSUInteger)to.row];[self haoge_touchflow_saveItems:items];
}
@end

@interface HaogeTouchFlowPanelSliderCell : UITableViewCell
@property (nonatomic, strong) UILabel *haoge_touchflow_name;
@property (nonatomic, strong) UILabel *haoge_touchflow_value;
@property (nonatomic, strong) UISlider *haoge_touchflow_slider;
@property (nonatomic, copy) NSDictionary *haoge_touchflow_field;
@property (nonatomic, copy) void (^haoge_touchflow_commit)(double);
@end
@implementation HaogeTouchFlowPanelSliderCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self=[super initWithStyle:style reuseIdentifier:identifier])) {
        self.selectionStyle=UITableViewCellSelectionStyleNone;
        _haoge_touchflow_name=[UILabel new];_haoge_touchflow_name.font=[UIFont systemFontOfSize:15];
        _haoge_touchflow_value=[UILabel new];_haoge_touchflow_value.font=[UIFont monospacedDigitSystemFontOfSize:13 weight:UIFontWeightRegular];_haoge_touchflow_value.textAlignment=NSTextAlignmentRight;
        _haoge_touchflow_slider=[UISlider new];
        [self.contentView addSubview:_haoge_touchflow_name];[self.contentView addSubview:_haoge_touchflow_value];[self.contentView addSubview:_haoge_touchflow_slider];
        [_haoge_touchflow_slider addTarget:self action:@selector(haoge_touchflow_changed) forControlEvents:UIControlEventValueChanged];
        [_haoge_touchflow_slider addTarget:self action:@selector(haoge_touchflow_finished) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];
    }return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];CGFloat width=CGRectGetWidth(self.contentView.bounds);
    self.haoge_touchflow_name.frame=CGRectMake(16,7,MAX(1,width-120),24);
    self.haoge_touchflow_value.frame=CGRectMake(MAX(16,width-100),7,84,24);
    self.haoge_touchflow_slider.frame=CGRectMake(16,35,MAX(1,width-32),30);
}
- (void)haoge_touchflow_changed {
    double step=[self.haoge_touchflow_field[@"step"] doubleValue];double value=round(self.haoge_touchflow_slider.value/step)*step;
    self.haoge_touchflow_slider.accessibilityLabel=self.haoge_touchflow_field[@"title"];
    self.haoge_touchflow_slider.accessibilityValue=[NSString stringWithFormat:step<1?@"%.2f%@":@"%.0f%@",value,self.haoge_touchflow_field[@"unit"]];
    self.haoge_touchflow_value.text=self.haoge_touchflow_slider.accessibilityValue;
    if (UIAccessibilityIsVoiceOverRunning()) [self haoge_touchflow_finished];
}
- (void)haoge_touchflow_finished {
    double step=[self.haoge_touchflow_field[@"step"] doubleValue];double value=round(self.haoge_touchflow_slider.value/step)*step;
    if (self.haoge_touchflow_commit) self.haoge_touchflow_commit(value);
}
@end

@interface HaogeTouchFlowPanelAppearanceController ()
@property (nonatomic, copy) NSDictionary *haoge_touchflow_values;
@end
@implementation HaogeTouchFlowPanelAppearanceController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad { [super viewDidLoad];self.title=@"面板外观"; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];self.haoge_touchflow_values=haoge_touchflow_readPreferences();[self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView;return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { (void)tableView;return section==0?2:(NSInteger)haoge_touchflow_panelSettings().count; }
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;return section==0?@"面板显示后可点外侧、右上角关闭，或从顶部短条下滑关闭。当前面板只在解锁后显示。":@"滑条松手保存；面板高度不会超过可用屏幕，图标过大时会自动适应列宽。所有手势面板共用外观参数。";
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path { (void)tableView;return path.section==1?74:48; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;
    if (path.section==0) {
        UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        if (path.row==0) {
            cell.textLabel.text=@"显示动作名称";UISwitch *toggle=[UISwitch new];toggle.on=haoge_touchflow_panelFlag(self.haoge_touchflow_values,@"panelShowsLabels",YES);
            [toggle addTarget:self action:@selector(haoge_touchflow_labelsToggled:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;
        } else {
            cell.textLabel.text=@"面板颜色";NSString *appearance=self.haoge_touchflow_values[@"panelAppearance"];
            cell.detailTextLabel.text=[appearance isEqual:@"dark"]?@"深色":([appearance isEqual:@"light"]?@"浅色":@"跟随系统");cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
        }return cell;
    }
    NSDictionary *field=haoge_touchflow_panelSettings()[(NSUInteger)path.row];
    HaogeTouchFlowPanelSliderCell *cell=[[HaogeTouchFlowPanelSliderCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
    cell.haoge_touchflow_field=field;cell.haoge_touchflow_name.text=field[@"title"];
    cell.haoge_touchflow_slider.minimumValue=[field[@"min"] floatValue];cell.haoge_touchflow_slider.maximumValue=[field[@"max"] floatValue];
    cell.haoge_touchflow_slider.value=(float)haoge_touchflow_panelNumber(self.haoge_touchflow_values,field[@"key"]);[cell haoge_touchflow_changed];
    __weak typeof(self) weakSelf=self;cell.haoge_touchflow_commit=^(double value) { [weakSelf haoge_touchflow_save:field[@"key"] value:@(value)]; };
    return cell;
}
- (void)haoge_touchflow_save:(NSString *)key value:(id)value {
    NSError *error=nil;if (!haoge_touchflow_writePreference(key,value,&error)) { haoge_touchflow_panelError(self,error);self.haoge_touchflow_values=haoge_touchflow_readPreferences();[self.tableView reloadData];return; }
    self.haoge_touchflow_values=haoge_touchflow_readPreferences();
}
- (void)haoge_touchflow_labelsToggled:(UISwitch *)toggle { [self haoge_touchflow_save:@"panelShowsLabels" value:@(toggle.on)]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];if (path.section!=0 || path.row!=1) return;
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"面板颜色" message:nil preferredStyle:UIAlertControllerStyleAlert];
    NSArray *titles=@[@"跟随系统",@"浅色",@"深色"],*values=@[@"system",@"light",@"dark"];
    for (NSUInteger i=0;i<titles.count;i++) [alert addAction:[UIAlertAction actionWithTitle:titles[i] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;[self haoge_touchflow_save:@"panelAppearance" value:values[i]];[self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:alert animated:YES completion:nil];
}
@end
