#import "HaogeTouchFlowPanelSettings.h"
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import "HaogeTouchFlowActions.h"

@interface HaogeTouchFlowPanelActionPickerController : UITableViewController
@property(nonatomic,copy)NSString *haoge_touchflow_trigger;
@property(nonatomic,strong)NSArray<NSDictionary *> *haoge_touchflow_existingItems;
@property(nonatomic,strong)NSMutableSet<NSString *> *haoge_touchflow_selectedIDs;
@property(nonatomic,strong)NSArray<NSDictionary *> *haoge_touchflow_pendingEntries;
@property(nonatomic,strong)NSMutableArray<NSDictionary *> *haoge_touchflow_pendingItems;
@property(nonatomic,assign)NSUInteger haoge_touchflow_pendingIndex;
+ (instancetype)haoge_touchflow_controllerForTrigger:(NSString *)trigger existingItems:(NSArray<NSDictionary *> *)items;
@end

@implementation HaogeTouchFlowPanelActionPickerController
+ (instancetype)haoge_touchflow_controllerForTrigger:(NSString *)trigger existingItems:(NSArray<NSDictionary *> *)items {
    HaogeTouchFlowPanelActionPickerController *controller=[[self alloc] initWithStyle:UITableViewStyleInsetGrouped];
    controller.haoge_touchflow_trigger=[trigger copy];controller.haoge_touchflow_existingItems=[items copy]?:@[];controller.haoge_touchflow_selectedIDs=[NSMutableSet set];return controller;
}
- (void)viewDidLoad {
    [super viewDidLoad];self.title=@"添加动作";
    self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc] initWithTitle:@"保存所选" style:UIBarButtonItemStyleDone target:self action:@selector(haoge_touchflow_saveSelection)];
}
- (NSArray<NSDictionary *> *)haoge_touchflow_candidates {
    NSSet *existing=[NSSet setWithArray:[self.haoge_touchflow_existingItems valueForKey:@"action"]];NSMutableArray *result=[NSMutableArray array];
    for(NSDictionary *entry in haoge_touchflow_actionCatalog())if(![existing containsObject:entry[@"identifier"]])[result addObject:entry];
    return result;
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {(void)tableView;return 1;}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {(void)tableView;(void)section;return (NSInteger)self.haoge_touchflow_candidates.count;}
- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {(void)tableView;(void)section;return @"点按可多选，再点一次取消勾选；最后点右上角“保存所选”。已加入面板的功能不会重复显示，参数、名称和图标可添加后编辑。";}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)path {
    (void)tableView;NSDictionary *entry=self.haoge_touchflow_candidates[(NSUInteger)path.row];UITableViewCell *cell=[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];
    cell.textLabel.text=entry[@"title"];cell.detailTextLabel.text=entry[@"detail"];cell.textLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];cell.detailTextLabel.textColor=UIColor.secondaryLabelColor;
    cell.imageView.image=[UIImage systemImageNamed:haoge_touchflow_actionSymbol(entry[@"identifier"])];cell.imageView.tintColor=UIColor.systemBlueColor;
    cell.accessoryType=[self.haoge_touchflow_selectedIDs containsObject:entry[@"identifier"]]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)path {
    [tableView deselectRowAtIndexPath:path animated:YES];NSDictionary *entry=self.haoge_touchflow_candidates[(NSUInteger)path.row];NSString *identifier=entry[@"identifier"];
    if([self.haoge_touchflow_selectedIDs containsObject:identifier])[self.haoge_touchflow_selectedIDs removeObject:identifier];else [self.haoge_touchflow_selectedIDs addObject:identifier];
    self.navigationItem.rightBarButtonItem.title=[NSString stringWithFormat:@"保存所选 (%lu)",(unsigned long)self.haoge_touchflow_selectedIDs.count];
    [tableView reloadRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationNone];
}
- (void)haoge_touchflow_writePendingItems {
    NSDictionary *values=haoge_touchflow_readPreferences();id raw=values[HaogeTouchFlowBindingsKey];NSMutableDictionary *bindings=[raw isKindOfClass:NSDictionary.class]?[raw mutableCopy]:[NSMutableDictionary dictionary];NSMutableDictionary *binding=[haoge_touchflow_binding(values,self.haoge_touchflow_trigger) mutableCopy];binding[@"panelItems"]=haoge_touchflow_panelItems(self.haoge_touchflow_pendingItems?:@[]);bindings[self.haoge_touchflow_trigger]=binding;NSError *error=nil;
    if(!haoge_touchflow_writePreference(HaogeTouchFlowBindingsKey,bindings,&error)){UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"设置未保存" message:error.localizedDescription?:@"无法写入配置。" preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];return;}
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)haoge_touchflow_promptForNextSelection {
    if(self.haoge_touchflow_pendingIndex>=self.haoge_touchflow_pendingEntries.count){[self haoge_touchflow_writePendingItems];return;}
    NSDictionary *entry=self.haoge_touchflow_pendingEntries[self.haoge_touchflow_pendingIndex];NSString *identifier=entry[@"identifier"];
    if(![entry[@"needsValue"] boolValue]){
        [self.haoge_touchflow_pendingItems addObject:@{@"id":NSUUID.UUID.UUIDString,@"action":identifier,@"value":@"",@"title":@"",@"symbol":@""}];self.haoge_touchflow_pendingIndex++;[self haoge_touchflow_promptForNextSelection];return;
    }
    UIAlertController *alert=[UIAlertController alertControllerWithTitle:entry[@"title"] message:entry[@"valueHint"]?:@"请输入动作参数" preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field){field.autocapitalizationType=UITextAutocapitalizationTypeNone;field.autocorrectionType=UITextAutocorrectionTypeNo;}];
    [alert addAction:[UIAlertAction actionWithTitle:@"取消整个批量添加" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action){(void)action;self.haoge_touchflow_pendingEntries=nil;self.haoge_touchflow_pendingItems=nil;self.haoge_touchflow_pendingIndex=0;[self.haoge_touchflow_selectedIDs removeAllObjects];self.navigationItem.rightBarButtonItem.title=@"保存所选";}]];
    [alert addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action){
        (void)action;NSString *value=[alert.textFields.firstObject.text?:@"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if(!value.length||([identifier isEqual:@"openURL"]&&![NSURL URLWithString:value].scheme.length)){alert.message=[identifier isEqual:@"openURL"]?@"请输入包含协议的完整 URL。":@"此动作需要填写参数。";[alert.textFields.firstObject becomeFirstResponder];return;}
        [self.haoge_touchflow_pendingItems addObject:@{@"id":NSUUID.UUID.UUIDString,@"action":identifier,@"value":value,@"title":@"",@"symbol":@""}];self.haoge_touchflow_pendingIndex++;
        [alert dismissViewControllerAnimated:YES completion:^{[self haoge_touchflow_promptForNextSelection];}];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}
- (void)haoge_touchflow_saveSelection {
    if(!self.haoge_touchflow_selectedIDs.count)return;
    NSArray *current=haoge_touchflow_panelItems(haoge_touchflow_binding(haoge_touchflow_readPreferences(),self.haoge_touchflow_trigger)[@"panelItems"]);
    self.haoge_touchflow_pendingItems=[current mutableCopy];NSMutableSet *existing=[NSMutableSet setWithArray:[current valueForKey:@"action"]];
    NSMutableArray *selectedEntries=[NSMutableArray array];for(NSDictionary *entry in haoge_touchflow_actionCatalog()){NSString *identifier=entry[@"identifier"];if([self.haoge_touchflow_selectedIDs containsObject:identifier]&&![existing containsObject:identifier])[selectedEntries addObject:entry];}
    self.haoge_touchflow_pendingEntries=selectedEntries;
    if(self.haoge_touchflow_pendingItems.count+self.haoge_touchflow_pendingEntries.count>30){UIAlertController *alert=[UIAlertController alertControllerWithTitle:@"超过面板上限" message:@"一个面板最多添加 30 个动作。" preferredStyle:UIAlertControllerStyleAlert];[alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];[self presentViewController:alert animated:YES completion:nil];return;}
    self.haoge_touchflow_pendingIndex=0;[self haoge_touchflow_promptForNextSelection];
}
@end
