#import <UIKit/UIKit.h>
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import "HaogeTouchFlowActions.h"

@interface HaogeTouchFlowBindingController : UITableViewController
@property (nonatomic, copy) NSString *haoge_touchflow_trigger;
@property (nonatomic, copy) NSString *haoge_touchflow_title;
@property (nonatomic, copy) NSDictionary *haoge_touchflow_binding;
- (instancetype)haoge_touchflow_initWithTrigger:(NSString *)trigger title:(NSString *)title;
@end
@implementation HaogeTouchFlowBindingController
- (instancetype)haoge_touchflow_initWithTrigger:(NSString *)trigger title:(NSString *)title {
    HaogeTouchFlowBindingController *result = [super initWithStyle:UITableViewStyleInsetGrouped];
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
    (void)tableView; return section == 0 ? 1 : (NSInteger)haoge_touchflow_actionCatalog().count + 1;
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    return section == 0 ? @"同时开启插件总开关和本项开关，选择一个动作后生效。选择“不执行动作”会保留系统手势。"
        : @"打开应用：输入 Bundle ID。运行快捷指令：输入完整名称。打开链接：输入带协议的 URL。保存后立即生效。";
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    if (path.section == 0) {
        cell.textLabel.text = @"启用此手势"; UISwitch *toggle = [UISwitch new];
        toggle.on = [self.haoge_touchflow_binding[@"enabled"] respondsToSelector:@selector(boolValue)] && [self.haoge_touchflow_binding[@"enabled"] boolValue];
        [toggle addTarget:self action:@selector(haoge_touchflow_toggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = toggle; cell.selectionStyle = UITableViewCellSelectionStyleNone; return cell;
    }
    NSArray *catalog = haoge_touchflow_actionCatalog();
    if (path.row == 0) {
        cell.textLabel.text = @"动作参数";
        NSString *value = [self.haoge_touchflow_binding[@"value"] isKindOfClass:[NSString class]] ? self.haoge_touchflow_binding[@"value"] : @"";
        cell.detailTextLabel.text = value.length ? value : @"点击填写应用标识／指令名称／链接";
        cell.detailTextLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSDictionary *action = catalog[(NSUInteger)path.row-1];
        cell.textLabel.text = action[@"title"]; cell.detailTextLabel.text = action[@"detail"];
        NSString *current = [self.haoge_touchflow_binding[@"action"] isKindOfClass:[NSString class]] ? self.haoge_touchflow_binding[@"action"] : @"none";
        if ([current isEqual:action[@"identifier"]]) cell.accessoryType = UITableViewCellAccessoryCheckmark;
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
    if (path.section != 1) return;
    if (path.row == 0) { [self haoge_touchflow_editValue]; return; }
    NSDictionary *action = haoge_touchflow_actionCatalog()[(NSUInteger)path.row-1];
    if ([self haoge_touchflow_save:@{@"action":action[@"identifier"]}] && [action[@"needsValue"] boolValue])
        [self haoge_touchflow_editValue];
}
- (void)haoge_touchflow_editValue {
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
