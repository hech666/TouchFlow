#import <UIKit/UIKit.h>
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import "HaogeTouchFlowActions.h"
#import "HaogeTouchFlowPanelSettings.h"

@interface HaogeTouchFlowBindingController : UITableViewController
@property (nonatomic, copy) NSString *haoge_touchflow_trigger;
@property (nonatomic, copy) NSString *haoge_touchflow_title;
@property (nonatomic, copy) NSDictionary *haoge_touchflow_binding;
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
- (void)viewDidLoad { [super viewDidLoad]; self.title = self.haoge_touchflow_title; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.haoge_touchflow_binding = haoge_touchflow_binding(haoge_touchflow_readPreferences(),self.haoge_touchflow_trigger);
    [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 2; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? 2 : (NSInteger)haoge_touchflow_actionCatalog().count + 2;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"在下方选择一种动作。选择快捷面板后，在这里添加面板项目。面板在解锁后显示。"
        : @"打开应用填写 Bundle ID，快捷指令填写完整名称，链接填写带协议的 URL。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if (path.section == 0 && path.row == 1) {
        cell.textLabel.text=@"配置面板动作";cell.detailTextLabel.text=[NSString stringWithFormat:@"%lu 项",(unsigned long)haoge_touchflow_panelItems(self.haoge_touchflow_binding[@"panelItems"]).count];
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
    }
    if (path.section == 0) {
        cell.textLabel.text = @"启用此手势"; UISwitch *toggle = [UISwitch new];
        toggle.on = [self.haoge_touchflow_binding[@"enabled"] respondsToSelector:@selector(boolValue)] && [self.haoge_touchflow_binding[@"enabled"] boolValue];
        [toggle addTarget:self action:@selector(haoge_touchflow_toggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle; cell.selectionStyle = UITableViewCellSelectionStyleNone; return cell;
    }
    if (path.row == 0) {
        cell.textLabel.text=@"直接动作参数";
        NSString *value=[self.haoge_touchflow_binding[@"value"] isKindOfClass:[NSString class]]?self.haoge_touchflow_binding[@"value"]:@"";
        cell.detailTextLabel.text=value.length?value:@"应用标识／快捷指令名称／完整 URL";
        cell.detailTextLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else if (path.row == 1) {
        cell.textLabel.text = @"呼出快捷面板";
        cell.detailTextLabel.text = @"显示此手势配置的动作";
        if (haoge_touchflow_hasPanelMode(self.haoge_touchflow_binding)) cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        NSDictionary *entry = haoge_touchflow_actionCatalog()[(NSUInteger)path.row - 2];
        cell.textLabel.text = entry[@"title"];
        cell.detailTextLabel.text = entry[@"detail"];
        id action = self.haoge_touchflow_binding[@"action"];
        NSString *selected = [action isKindOfClass:[NSString class]] ? action : @"none";
        if (!haoge_touchflow_hasPanelMode(self.haoge_touchflow_binding) && [selected isEqual:entry[@"identifier"]]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    return cell;
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
    if (path.section == 0 && path.row == 1) {
        [self.navigationController pushViewController:[HaogeTouchFlowPanelItemsController haoge_touchflow_controllerWithTrigger:self.haoge_touchflow_trigger] animated:YES];
        return;
    }
    if (path.section != 1) return;
    if (path.row == 0) { [self haoge_touchflow_editDirectValue]; return; }
    if (path.row == 1) { [self haoge_touchflow_save:@{@"mode":@"panel"}]; return; }
    NSDictionary *action = haoge_touchflow_actionCatalog()[(NSUInteger)path.row - 2];
    if ([self haoge_touchflow_save:@{@"mode":@"direct", @"action":action[@"identifier"]}] && [action[@"needsValue"] boolValue]) {
        [self haoge_touchflow_editDirectValue];
    }
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
