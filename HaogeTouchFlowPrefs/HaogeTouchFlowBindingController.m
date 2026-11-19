#import <UIKit/UIKit.h>
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import "HaogeTouchFlowActions.h"
#import "HaogeTouchFlowPanelSettings.h"

@interface HaogeTouchFlowBindingController : UITableViewController <UISearchResultsUpdating, UISearchBarDelegate>
@property (nonatomic, copy) NSString *haoge_touchflow_trigger;
@property (nonatomic, copy) NSString *haoge_touchflow_title;
@property (nonatomic, copy) NSDictionary *haoge_touchflow_binding;
@property (nonatomic, strong) UISearchController *haoge_touchflow_searchController;
@property (nonatomic, copy) NSString *haoge_touchflow_searchText;
+ (instancetype)haoge_touchflow_controllerWithTrigger:(NSString *)trigger title:(NSString *)title;
@end
@implementation HaogeTouchFlowBindingController
+ (instancetype)haoge_touchflow_controllerWithTrigger:(NSString *)trigger title:(NSString *)title {
    HaogeTouchFlowBindingController *result = [[self alloc] initWithStyle:UITableViewStyleInsetGrouped];
    if (result) {
        result.haoge_touchflow_trigger = [trigger copy];
        result.haoge_touchflow_title = [title copy];
    }
    return result;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.title=self.haoge_touchflow_title;self.definesPresentationContext=YES;
    self.haoge_touchflow_searchController=[[UISearchController alloc] initWithSearchResultsController:nil];
    self.haoge_touchflow_searchController.searchResultsUpdater=self;
    self.haoge_touchflow_searchController.obscuresBackgroundDuringPresentation=NO;
    self.haoge_touchflow_searchController.searchBar.placeholder=@"搜索动作";
    self.haoge_touchflow_searchController.searchBar.delegate=self;
    self.navigationItem.searchController=self.haoge_touchflow_searchController;
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];self.haoge_touchflow_binding=haoge_touchflow_binding(haoge_touchflow_readPreferences(),self.haoge_touchflow_trigger);[self.tableView reloadData];
}
- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    self.haoge_touchflow_searchText=searchController.searchBar.text?:@"";[self.tableView reloadData];
}
- (NSArray<NSDictionary *> *)haoge_touchflow_entriesForSection:(NSInteger)section {
    static NSArray<NSArray<NSString *> *> *groups;static dispatch_once_t once;
    dispatch_once(&once,^{groups=@[
        @[@"controlCenter",@"lock",@"appSwitcher",@"respring",@"screenshot",@"screenRecording",@"flashlight"],
        @[@"kayokoClipboard"],
        @[@"wechatPay",@"alipayPay",@"wechatScan",@"alipayScan"],
        @[@"playPause",@"nextTrack",@"previousTrack"],
        @[@"openApp",@"runShortcut",@"openURL"]
    ];});
    if(section<2||section>6)return @[];
    NSArray *identifiers=groups[(NSUInteger)section-2];NSMutableArray *rows=[NSMutableArray array];NSString *query=[self.haoge_touchflow_searchText stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    for(NSDictionary *entry in haoge_touchflow_actionCatalog())if([identifiers containsObject:entry[@"identifier"]]){
        NSString *haystack=[NSString stringWithFormat:@"%@ %@ %@",entry[@"title"],entry[@"detail"],entry[@"identifier"]];
        if(!query.length||[haystack localizedCaseInsensitiveContainsString:query])[rows addObject:entry];
    }
    return rows;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView;return 7; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    if(section==0)return 1;
    if(section==1)return 3;
    return (NSInteger)[self haoge_touchflow_entriesForSection:section].count;
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView;
    if(section==1)return @"执行方式";
    NSArray *titles=@[@"系统操作",@"剪切板",@"扫码与付款",@"媒体控制",@"应用与快捷方式"];
    return section>=2&&section<=6?titles[(NSUInteger)section-2]:nil;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if(section==0)return @"开启后，从下方选择一个动作，或使用快捷面板。";
    if(section==1)return @"每个手势只绑定一种执行方式；面板动作可在“编辑快捷面板”中管理。";
    return nil;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)path { (void)tableView;return path.section>=2?64:56; }
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];cell.selectionStyle=UITableViewCellSelectionStyleDefault;
    if(path.section==0){
        cell.textLabel.text=@"启用此手势";UISwitch *toggle=[UISwitch new];toggle.on=[self.haoge_touchflow_binding[@"enabled"] respondsToSelector:@selector(boolValue)]&&[self.haoge_touchflow_binding[@"enabled"] boolValue];
        [toggle addTarget:self action:@selector(haoge_touchflow_toggled:) forControlEvents:UIControlEventValueChanged];cell.accessoryView=toggle;cell.selectionStyle=UITableViewCellSelectionStyleNone;return cell;
    }
    if(path.section==1){
        NSArray *titles=@[@"直接执行动作",@"呼出快捷面板",@"编辑快捷面板"];
        NSArray *details=@[@"选择一个动作执行",@"显示此手势配置的动作网格",@"添加、删除或排列面板动作"];
        NSArray *symbols=@[@"hand.tap.fill",@"square.grid.2x2.fill",@"slider.horizontal.3"];
        cell.textLabel.text=titles[(NSUInteger)path.row];cell.detailTextLabel.text=details[(NSUInteger)path.row];cell.imageView.image=[UIImage systemImageNamed:symbols[(NSUInteger)path.row]];cell.imageView.tintColor=UIColor.systemBlueColor;
        if(path.row==0){cell.accessoryType=!haoge_touchflow_hasPanelMode(self.haoge_touchflow_binding)?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;}
        else if(path.row==1){cell.accessoryType=haoge_touchflow_hasPanelMode(self.haoge_touchflow_binding)?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;}
        else{NSArray *items=haoge_touchflow_panelItems(self.haoge_touchflow_binding[@"panelItems"]);cell.detailTextLabel.text=items.count?[NSString stringWithFormat:@"%lu 项 · 添加、删除或排序",(unsigned long)items.count]:details[(NSUInteger)path.row];cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
        return cell;
    }
    NSDictionary *entry=[self haoge_touchflow_entriesForSection:path.section][(NSUInteger)path.row];cell.textLabel.text=entry[@"title"];cell.detailTextLabel.text=entry[@"detail"];
    cell.textLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];cell.detailTextLabel.textColor=UIColor.secondaryLabelColor;
    cell.imageView.image=[UIImage systemImageNamed:haoge_touchflow_actionSymbol(entry[@"identifier"])];cell.imageView.tintColor=UIColor.systemBlueColor;
    BOOL selected=!haoge_touchflow_hasPanelMode(self.haoge_touchflow_binding)&&[self.haoge_touchflow_binding[@"action"] isEqual:entry[@"identifier"]];cell.accessoryType=selected?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;return cell;
}
- (BOOL)haoge_touchflow_save:(NSDictionary *)updates {
    NSDictionary *all = haoge_touchflow_readPreferences();
    id saved = all[HaogeTouchFlowBindingsKey];
    NSMutableDictionary *bindings = [saved isKindOfClass:[NSDictionary class]] ? [saved mutableCopy] : [NSMutableDictionary dictionary];
    NSMutableDictionary *binding = [haoge_touchflow_binding(all,self.haoge_touchflow_trigger) mutableCopy];
    [binding addEntriesFromDictionary:updates]; bindings[self.haoge_touchflow_trigger] = binding;
    NSError *error = nil;
    if (!haoge_touchflow_writePreference(HaogeTouchFlowBindingsKey,bindings,&error)) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置未保存" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        [self.tableView reloadData]; return NO;
    }
    self.haoge_touchflow_binding = binding; [self.tableView reloadData]; return YES;
}
- (void)haoge_touchflow_toggled:(UISwitch *)toggle { [self haoge_touchflow_save:@{@"enabled":@(toggle.on)}]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if(path.section==1){
        if(path.row==0){NSString *action=self.haoge_touchflow_binding[@"action"];[self haoge_touchflow_save:@{@"mode":@"direct"}];if(haoge_touchflow_actionNeedsValue(action))[self haoge_touchflow_editDirectValue];return;}
        if(path.row==1){
            if(!haoge_touchflow_panelItems(self.haoge_touchflow_binding[@"panelItems"]).count){
                UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"先配置面板动作" message:@"至少添加一个动作后才能选择快捷面板。" preferredStyle:UIAlertControllerStyleAlert];
                [alert addAction:[UIAlertAction actionWithTitle:@"稍后" style:UIAlertActionStyleCancel handler:nil]];
                [alert addAction:[UIAlertAction actionWithTitle:@"配置动作" style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){(void)a;[self haoge_touchflow_editPanelItems];}]];
                [self presentViewController:alert animated:YES completion:nil];return;
            }
            [self haoge_touchflow_save:@{@"mode":@"panel"}];return;
        }
        if(path.row==2){[self haoge_touchflow_editPanelItems];return;}
        return;
    }
    if(path.section>=2){
        NSDictionary *action=[self haoge_touchflow_entriesForSection:path.section][(NSUInteger)path.row];
        if([self haoge_touchflow_save:@{@"mode":@"direct",@"action":action[@"identifier"]}] && [action[@"needsValue"] boolValue]) [self haoge_touchflow_editDirectValue];
    }
}
- (void)haoge_touchflow_editPanelItems {
    [self.navigationController pushViewController:[HaogeTouchFlowPanelItemsController haoge_touchflow_controllerWithTrigger:self.haoge_touchflow_trigger] animated:YES];
}
- (void)haoge_touchflow_editDirectValue {
    NSString *current = [self.haoge_touchflow_binding[@"action"] isKindOfClass:[NSString class]] ? self.haoge_touchflow_binding[@"action"] : @"none";
    NSDictionary *action = nil;
    for (NSDictionary *entry in haoge_touchflow_actionCatalog()) if ([entry[@"identifier"] isEqual:current]) { action=entry; break; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"动作参数" message:action[@"valueHint"] ?: @"仅打开应用、快捷指令、链接使用此参数。" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = [self.haoge_touchflow_binding[@"value"] isKindOfClass:[NSString class]] ? self.haoge_touchflow_binding[@"value"] : @"";
        field.autocapitalizationType = UITextAutocapitalizationTypeNone; field.autocorrectionType = UITextAutocorrectionTypeNo;
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *unused) {
        (void)unused; NSString *value = [alert.textFields.firstObject.text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf haoge_touchflow_save:@{@"value":value}]; });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
