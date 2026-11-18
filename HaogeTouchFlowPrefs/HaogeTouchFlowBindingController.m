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
    (void)tableView; return section == 0 ? 4 : (NSInteger)haoge_touchflow_actionCatalog().count + 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"开启总开关与本项开关后生效。旧配置默认直接执行；呼出面板模式需先配置面板动作，空面板不会接管手势。面板仅在解锁后显示。"
        : @"下面是直接执行模式使用的动作。打开应用：Bundle ID。快捷指令：完整名称。链接：带协议 URL。面板动作在上方单独配置。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if (path.section == 0 && path.row == 1) {
        cell.textLabel.text=@"执行模式";cell.detailTextLabel.text=haoge_touchflow_hasPanelMode(self.haoge_touchflow_binding)?@"呼出快捷面板":@"直接执行动作";
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
    }
    if (path.section == 0 && path.row == 2) {
        cell.textLabel.text=@"备用直接动作";cell.detailTextLabel.text=haoge_touchflow_actionTitle(self.haoge_touchflow_binding[@"action"]?:@"none");
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;return cell;
    }
    if (path.section == 0 && path.row == 3) {
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
        NSString *currentMode=[self.haoge_touchflow_binding[@"mode"] isKindOfClass:[NSString class]]?self.haoge_touchflow_binding[@"mode"]:@"direct";
        cell.textLabel.text=[currentMode isEqual:@"panel"]?@"面板打开后的备用动作":@"直接执行动作";
        NSString *value=haoge_touchflow_actionTitle(self.haoge_touchflow_binding[@"action"]?:@"none");
        cell.detailTextLabel.text=value;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else if (path.row == 1) {
        cell.textLabel.text=@"动作参数";
        NSString *value=[self.haoge_touchflow_binding[@"value"] isKindOfClass:[NSString class]]?self.haoge_touchflow_binding[@"value"]:@"";
        cell.detailTextLabel.text=value.length?value:@"点击填写应用标识／指令名称／链接";
        cell.detailTextLabel.lineBreakMode=NSLineBreakByTruncatingMiddle;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSString *value=[self.haoge_touchflow_binding[@"panelItems"] isKindOfClass:[NSArray class]]?[NSString stringWithFormat:@"%lu 项",(unsigned long)haoge_touchflow_panelItems(self.haoge_touchflow_binding[@"panelItems"]).count]:@"尚未设置";
        cell.textLabel.text=@"快捷面板动作";cell.detailTextLabel.text=value;cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
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
    if (path.section==0 && path.row==1) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"执行模式" message:@"直接执行使用下面选择的单一动作。快捷面板显示本手势配置的动作网格。" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"直接执行动作" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action;dispatch_async(dispatch_get_main_queue(), ^{ [self haoge_touchflow_save:@{@"mode":@"direct"}]; [self.tableView reloadData]; });
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"呼出快捷面板" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action;dispatch_async(dispatch_get_main_queue(), ^{ [self haoge_touchflow_save:@{@"mode":@"panel"}]; [self.tableView reloadData]; });
        }]];
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:alert animated:YES completion:nil];return;
    }
    if (path.section==0 && path.row==2) { [self haoge_touchflow_editDirectAction];return; }
    if (path.section==0 && path.row==3) {
        [self.navigationController pushViewController:[HaogeTouchFlowPanelItemsController haoge_touchflow_controllerWithTrigger:self.haoge_touchflow_trigger] animated:YES];return;
    }
    if (path.section != 1) return;
    if (path.row == 0) { [self haoge_touchflow_editDirectValue]; return; }
    NSDictionary *action = haoge_touchflow_actionCatalog()[(NSUInteger)path.row-1];
    if ([self haoge_touchflow_save:@{@"action":action[@"identifier"],@"mode":@"direct"}] && [action[@"needsValue"] boolValue]) [self haoge_touchflow_editDirectValue];
}
- (void)haoge_touchflow_editDirectAction {
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"直接执行动作" message:nil preferredStyle:UIAlertControllerStyleAlert];
    for (NSDictionary *entry in haoge_touchflow_actionCatalog()) {
        [alert addAction:[UIAlertAction actionWithTitle:entry[@"title"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            (void)action; dispatch_async(dispatch_get_main_queue(), ^{ if ([self haoge_touchflow_save:@{@"action":entry[@"identifier"],@"mode":@"direct"}] && [entry[@"needsValue"] boolValue]) [self haoge_touchflow_editDirectValue]; });
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];[self presentViewController:alert animated:YES completion:nil];
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
        dispatch_async(dispatch_get_main_queue(), ^{ [weakSelf haoge_touchflow_save:@{@"value":value,@"mode":@"direct"}]; });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end
