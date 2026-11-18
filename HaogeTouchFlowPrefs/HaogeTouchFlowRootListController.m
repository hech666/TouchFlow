#import "HaogeTouchFlowRootListController.h"
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import "HaogeTouchFlowActions.h"
#import "HaogeTouchFlowGeometry.h"
@interface HaogeTouchFlowBindingController : UITableViewController
+ (instancetype)haoge_touchflow_controllerWithTrigger:(NSString *)trigger title:(NSString *)title;
@end
@interface HaogeTouchFlowSettingsController : UITableViewController
@property (nonatomic, copy) NSDictionary *haoge_touchflow_values;
@end
@implementation HaogeTouchFlowSettingsController
- (instancetype)init { return [super initWithStyle:UITableViewStyleInsetGrouped]; }
- (void)viewDidLoad { [super viewDidLoad]; self.title = @"轻触手势"; }
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated]; self.haoge_touchflow_values = haoge_touchflow_readPreferences(); [self.tableView reloadData];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView { (void)tableView; return 6; }
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    (void)tableView; const NSInteger counts[]={1,5,5,3,2,4}; return counts[section];
}
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    (void)tableView; return @[@"轻触手势 · 首版",@"状态栏左侧",@"状态栏右侧",@"底部与桌面",@"行为",@"灵敏度"][(NSUInteger)section];
}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    (void)tableView;
    if (section==0) return @"安装后默认关闭。先停用 OneStepX 及其他同区域手势插件，再开启本插件。";
    if (section==3) return @"底部中间区域保留系统上滑。手势在竖屏识别；桌面长按只识别空白区域。";
    if (section==4) return @"默认不在锁屏执行动作。开启后系统仍要求解锁受保护内容。设置保存后自动生效。";
    if (section==5) return @"可调整触发区域和距离。首次安装后需由包管理器重新载入 SpringBoard；以后改设置不用注销。";
    return nil;
}
- (NSDictionary *)haoge_touchflow_numeric:(NSInteger)row {
    return @[@{@"key":@"bottomDistance",@"title":@"底部上滑距离",@"default":@110,@"min":@60,@"max":@200,@"suffix":@" pt"},
             @{@"key":@"statusDistance",@"title":@"状态栏横滑距离",@"default":@60,@"min":@30,@"max":@140,@"suffix":@" pt"},
             @{@"key":@"sidePercent",@"title":@"左右各侧区域宽度",@"default":@25,@"min":@10,@"max":@33,@"suffix":@"%"},
             @{@"key":@"longPressDuration",@"title":@"长按触发时间",@"default":@0.55,@"min":@0.35,@"max":@1.2,@"suffix":@" 秒"}][(NSUInteger)row];
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView; UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    if (path.section==0 || path.section==4) {
        NSString *key=path.section==0?@"enabled":(path.row==0?@"haptics":@"allowLocked");
        cell.textLabel.text=path.section==0?@"启用轻触手势":(path.row==0?@"触发时轻振":@"允许锁屏时执行");
        UISwitch *toggle=[UISwitch new]; toggle.accessibilityIdentifier=key;
        id value=self.haoge_touchflow_values[key]; toggle.on=[value isKindOfClass:[NSNumber class]]?[value boolValue]:[key isEqual:@"haptics"];
        [toggle addTarget:self action:@selector(haoge_touchflow_toggled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView=toggle; cell.selectionStyle=UITableViewCellSelectionStyleNone;
    } else if (path.section==5) {
        NSDictionary *field=[self haoge_touchflow_numeric:path.row]; cell.textLabel.text=field[@"title"];
        id value=self.haoge_touchflow_values[field[@"key"]]; if (![value isKindOfClass:[NSNumber class]]) value=field[@"default"];
        cell.detailTextLabel.text=[NSString stringWithFormat:@"%@%@",value,field[@"suffix"]]; cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } else {
        NSInteger index=path.section==1?path.row:(path.section==2?path.row+5:path.row+10);
        NSString *trigger=haoge_touchflow_triggerIDs()[(NSUInteger)index]; cell.textLabel.text=haoge_touchflow_triggerTitles()[(NSUInteger)index];
        NSDictionary *binding=haoge_touchflow_binding(self.haoge_touchflow_values,trigger);
        cell.detailTextLabel.text=haoge_touchflow_bindingEnabled(binding)?haoge_touchflow_actionTitle(binding[@"action"]):@"未启用";
        cell.accessoryType=UITableViewCellAccessoryDisclosureIndicator;
    } return cell;
}
- (void)haoge_touchflow_save:(NSString *)key value:(id)value {
    NSError *error=nil;
    if (!haoge_touchflow_writePreference(key,value,&error)) {
        UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"设置未保存" message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
    self.haoge_touchflow_values=haoge_touchflow_readPreferences(); [self.tableView reloadData];
}
- (void)haoge_touchflow_toggled:(UISwitch *)toggle { [self haoge_touchflow_save:toggle.accessibilityIdentifier value:@(toggle.on)]; }
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];
    if (path.section>=1 && path.section<=3) {
        NSInteger index=path.section==1?path.row:(path.section==2?path.row+5:path.row+10);
        HaogeTouchFlowBindingController *editor=[HaogeTouchFlowBindingController haoge_touchflow_controllerWithTrigger:haoge_touchflow_triggerIDs()[(NSUInteger)index] title:haoge_touchflow_triggerTitles()[(NSUInteger)index]];
        [self.navigationController pushViewController:editor animated:YES]; return;
    }
    if (path.section!=5) return;
    NSDictionary *field=[self haoge_touchflow_numeric:path.row];
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:field[@"title"] message:[NSString stringWithFormat:@"范围：%@～%@%@",field[@"min"],field[@"max"],field[@"suffix"]] preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *input) {
        input.keyboardType=UIKeyboardTypeDecimalPad; input.text=[self.haoge_touchflow_values[field[@"key"]] ?: field[@"default"] description];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf=self;
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        (void)action;
        NSString *text=[alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSScanner *scanner=[NSScanner scannerWithString:text ?: @""]; double number=0;
        BOOL valid=[scanner scanDouble:&number] && scanner.isAtEnd && isfinite(number) && number>=[field[@"min"] doubleValue] && number<=[field[@"max"] doubleValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (valid) [weakSelf haoge_touchflow_save:field[@"key"] value:@(number)];
            else { UIAlertController *error=[UIAlertController alertControllerWithTitle:@"数值超出范围" message:@"请输入范围内的数字。" preferredStyle:UIAlertControllerStyleAlert]; [error addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]]; [weakSelf presentViewController:error animated:YES completion:nil]; }
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

// PreferenceLoader hosts a PSListController; the content is an ordinary UIKit table.
// This keeps Preferences' private specifier index machinery out of custom action rows.
@interface HaogeTouchFlowRootListController ()
@property (nonatomic, strong) HaogeTouchFlowSettingsController *haoge_touchflow_content;
@end
@implementation HaogeTouchFlowRootListController
- (NSArray *)specifiers { return @[]; }
- (void)viewDidLoad {
    [super viewDidLoad]; self.title = @"轻触手势";
    self.tableView.scrollEnabled = NO;
    self.haoge_touchflow_content = [HaogeTouchFlowSettingsController new];
    [self addChildViewController:self.haoge_touchflow_content];
    UIView *contentView = self.haoge_touchflow_content.view;
    contentView.frame = self.view.bounds;
    contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:contentView];
    [self.haoge_touchflow_content didMoveToParentViewController:self];
}
@end
