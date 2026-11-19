#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <objc/message.h>
#import "HaogeTouchFlowConfig.h"
#import "HaogeTouchFlowPanel.h"
#import "HaogeTouchFlowPreferences.h"
#import "HaogeTouchFlowShared.h"
#import "HaogeTouchFlowActions.h"
#import "HaogeTouchFlowPanelSettings.h"
@implementation PSListController
@end
@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
@end
@implementation SBLockScreenManager
+ (instancetype)sharedInstance { static id manager;static dispatch_once_t once;dispatch_once(&once,^{manager=[self new];});return manager; }
- (BOOL)isUILocked { return NO; }
@end
static NSUInteger haoge_touchflow_testExecuted;
void haoge_touchflow_executeBinding(NSDictionary *binding) {
    NSCAssert([binding[@"action"] isEqual:@"controlCenter"],@"expected selected action");haoge_touchflow_testExecuted++;
}
@interface HaogeTouchFlowTestApp : UIResponder <UIApplicationDelegate, UIWindowSceneDelegate>
@property (nonatomic,strong) UIWindow *window;
@property (nonatomic,strong) UINavigationController *navigation;
@property (nonatomic,strong) UIViewController *host;
@property (nonatomic,strong) NSDictionary *binding;
@property (nonatomic,assign) NSUInteger checks;
@end
@implementation HaogeTouchFlowTestApp
- (void)haoge_touchflow_testCheck:(BOOL)condition message:(NSString *)message {
    if (!condition) @throw [NSException exceptionWithName:@"TouchFlowUITestFailure" reason:message userInfo:nil];self.checks++;
}
- (void)haoge_touchflow_testFinish:(NSString *)failure {
    NSString *path=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"ui_result.json"];
    NSDictionary *result=@{@"success":@(failure==nil),@"checks":@(self.checks),@"failure":failure?:@"",@"scope":@"real UIKit with mocked Preferences base, lock state and action callback; not SpringBoard"};
    [[NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:NULL] writeToFile:path atomically:YES];
    NSLog(@"TouchFlow UI TEST %@",result);
}
- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)options {
    (void)session;(void)options;
    @try {
        self.window=[[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];self.navigation=[[UINavigationController alloc] initWithRootViewController:[UIViewController new]];self.window.rootViewController=self.navigation;[self.window makeKeyAndVisible];
        Class hostClass=NSClassFromString(@"HaogeTouchFlowRootListController");self.host=[hostClass new];[self.navigation setViewControllers:@[self.host] animated:NO];[self.host loadViewIfNeeded];
        [self haoge_touchflow_testCheck:![self.host respondsToSelector:@selector(tableView)] message:@"root host must not expose tableView"];
        [self haoge_touchflow_testCheck:self.host.childViewControllers.count==1 message:@"root creates one UIKit child"];
        UITableViewController *settings=(id)self.host.childViewControllers.firstObject;
        [self haoge_touchflow_testCheck:[settings isKindOfClass:UITableViewController.class] message:@"settings are native table"];
        for (NSInteger s=0;s<[settings numberOfSectionsInTableView:settings.tableView];s++) {
            NSInteger count=[settings tableView:settings.tableView numberOfRowsInSection:s];
            for (NSInteger row=0;row<count;row++) [self haoge_touchflow_testCheck:[settings tableView:settings.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:s]]!=nil message:@"settings row builds"];
        }
        Class bindingClass=NSClassFromString(@"HaogeTouchFlowBindingController");SEL factory=NSSelectorFromString(@"haoge_touchflow_controllerWithTrigger:title:");
        UITableViewController *editor=((id (*)(id,SEL,id,id))objc_msgSend)(bindingClass,factory,@"statusLeftTap",@"状态栏左侧单击");
        [self.navigation pushViewController:editor animated:NO];
        [editor loadViewIfNeeded];[editor viewWillAppear:NO];
        NSArray *catalog=haoge_touchflow_actionCatalog();
        NSArray *actionGroups=@[@[@"controlCenter",@"lock",@"appSwitcher",@"respring",@"screenshot",@"screenRecording",@"flashlight"],@[@"kayokoClipboard"],@[@"wechatPay",@"alipayPay",@"wechatScan",@"alipayScan"],@[@"playPause",@"nextTrack",@"previousTrack"],@[@"openApp",@"runShortcut",@"openURL"]];
        [self haoge_touchflow_testCheck:[editor numberOfSectionsInTableView:editor.tableView]==7 message:@"binding page uses grouped action sections"];
        [self haoge_touchflow_testCheck:[editor tableView:editor.tableView numberOfRowsInSection:0]==1 message:@"gesture enable section has one row"];
        [self haoge_touchflow_testCheck:[editor tableView:editor.tableView numberOfRowsInSection:1]==3 message:@"execution mode section has three rows"];
        NSMutableSet *shown=[NSMutableSet set];
        for(NSInteger section=2;section<7;section++)for(NSInteger row=0;row<[editor tableView:editor.tableView numberOfRowsInSection:section];row++){
            NSString *identifier=actionGroups[(NSUInteger)section-2][(NSUInteger)row];NSDictionary *entry=nil;
            for(NSDictionary *candidate in catalog)if([candidate[@"identifier"] isEqual:identifier]){entry=candidate;break;}
            NSIndexPath *path=[NSIndexPath indexPathForRow:row inSection:section];UITableViewCell *cell=[editor tableView:editor.tableView cellForRowAtIndexPath:path];
            [self haoge_touchflow_testCheck:entry!=nil&&[cell.textLabel.text isEqual:entry[@"title"]] message:@"grouped action row matches catalog"];
            [shown addObject:identifier];NSDictionary *selected=@{@"enabled":@YES,@"mode":@"direct",@"action":identifier};[editor setValue:selected forKey:@"haoge_touchflow_binding"];
            cell=[editor tableView:editor.tableView cellForRowAtIndexPath:path];[self haoge_touchflow_testCheck:cell.accessoryType==UITableViewCellAccessoryCheckmark message:@"selected action checkmark maps to row"];
        }
        [self haoge_touchflow_testCheck:shown.count==catalog.count message:@"each action appears in one visual group"];
    [editor setValue:@{@"enabled":@YES,@"mode":@"panel",@"panelItems":@[]} forKey:@"haoge_touchflow_binding"];
    NSIndexPath *panelEditorRow=[NSIndexPath indexPathForRow:2 inSection:1];
    [editor tableView:editor.tableView didSelectRowAtIndexPath:panelEditorRow];
    [self haoge_touchflow_testCheck:[self.navigation.topViewController isKindOfClass:HaogeTouchFlowPanelItemsController.class] message:@"panel editor row opens item settings"];
    HaogeTouchFlowPanelItemsController *panelItems=(id)self.navigation.topViewController;
    [panelItems loadViewIfNeeded];
    [self haoge_touchflow_testCheck:panelItems.navigationItem.rightBarButtonItems.count==2 message:@"panel editor exposes add and edit buttons"];
    [self.navigation popViewControllerAnimated:NO];
    NSDictionary *item=@{@"id":@"test-item",@"action":@"controlCenter",@"value":@"",@"title":@"控制中心",@"symbol":@"switch.2"};
        self.binding=@{@"enabled":@YES,@"mode":@"panel",@"panelItems":@[item]};
        [self haoge_touchflow_testCheck:haoge_touchflow_writePreference(@"bindings",@{@"statusLeftTap":self.binding},NULL) message:@"panel list saves"];
        HaogeTouchFlowPanelActionPickerController *picker=[HaogeTouchFlowPanelActionPickerController haoge_touchflow_controllerForTrigger:@"statusLeftTap" existingItems:@[item]];
        [picker loadViewIfNeeded];NSArray *candidates=((id (*)(id,SEL))objc_msgSend)(picker,NSSelectorFromString(@"haoge_touchflow_candidates"));
        [self haoge_touchflow_testCheck:[candidates indexOfObjectPassingTest:^BOOL(NSDictionary *row,NSUInteger index,BOOL *stop){(void)index;(void)stop;return [row[@"identifier"] isEqual:@"controlCenter"];}]==NSNotFound message:@"already-added action is excluded from add list"];
        NSArray *batch=@[@"lock",@"respring"];
        for(NSString *identifier in batch){NSUInteger row=[candidates indexOfObjectPassingTest:^BOOL(NSDictionary *entry,NSUInteger index,BOOL *stop){(void)index;(void)stop;return [entry[@"identifier"] isEqual:identifier];}];[self haoge_touchflow_testCheck:row!=NSNotFound message:@"multi-add candidate exists"];[picker tableView:picker.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)row inSection:0]];}
        [self haoge_touchflow_testCheck:[[picker valueForKey:@"haoge_touchflow_selectedIDs"] count]==2 message:@"multiple actions are checked together"];
        ((void (*)(id,SEL))objc_msgSend)(picker,NSSelectorFromString(@"haoge_touchflow_saveSelection"));
        NSArray *savedItems=haoge_touchflow_panelItems(haoge_touchflow_binding(haoge_touchflow_readPreferences(),@"statusLeftTap")[@"panelItems"]);
        [self haoge_touchflow_testCheck:savedItems.count==3 message:@"batch save adds both selected functions"];
        [self haoge_touchflow_testCheck:[NSSet setWithArray:[savedItems valueForKey:@"action"]].count==3 message:@"panel item actions remain unique"];
        [self haoge_touchflow_testCheck:haoge_touchflow_writePreference(@"bindings",@{@"statusLeftTap":self.binding},NULL) message:@"restore panel test fixture after batch save"];
        // Assert editable metadata remains mutable after property assignment.
        Class itemClass=NSClassFromString(@"HaogeTouchFlowPanelItemEditor");UIViewController *itemEditor=[itemClass new];
        [itemEditor setValue:[item mutableCopy] forKey:@"haoge_touchflow_item"];
        NSMutableDictionary *mutableItem=[itemEditor valueForKey:@"haoge_touchflow_item"];mutableItem[@"title"]=@"已修改";
        [self haoge_touchflow_testCheck:[mutableItem[@"title"] isEqual:@"已修改"] message:@"item editor must not copy mutable input to immutable"];
        [itemEditor loadViewIfNeeded];
        UITableViewController *appearance=[NSClassFromString(@"HaogeTouchFlowPanelAppearanceController") new];[appearance loadViewIfNeeded];[appearance viewWillAppear:NO];
        for (NSInteger s=0;s<2;s++) for (NSInteger row=0;row<[appearance tableView:appearance.tableView numberOfRowsInSection:s];row++)
            [self haoge_touchflow_testCheck:[appearance tableView:appearance.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:row inSection:s]]!=nil message:@"appearance controls build"];
        [HaogeTouchFlowConfig haoge_touchflow_shared];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(), ^{[self haoge_touchflow_testPanel];});
    } @catch (NSException *error) { [self haoge_touchflow_testFinish:error.reason]; }
}
- (void)haoge_touchflow_testPanel {
    @try {
        HaogeTouchFlowPanel *panel=[HaogeTouchFlowPanel haoge_touchflow_shared];UIWindowScene *scene=nil;
        for (UIScene *candidate in UIApplication.sharedApplication.connectedScenes) if ([candidate isKindOfClass:UIWindowScene.class] && candidate.activationState==UISceneActivationStateForegroundActive) {scene=(id)candidate;break;}
        [self haoge_touchflow_testCheck:scene!=nil message:@"foreground scene available"];
        [panel haoge_touchflow_showBinding:self.binding trigger:@"statusLeftTap" scene:nil sourceWindow:nil];
        [self haoge_touchflow_testCheck:[panel haoge_touchflow_isVisible] message:@"panel visible via key-window scene fallback"];
        UIWindow *overlay=[panel valueForKey:@"haoge_touchflow_window"];
        [self haoge_touchflow_testCheck:[overlay isKindOfClass:NSClassFromString(@"HaogeTouchFlowPanelWindow")] message:@"ordinary non-key overlay receives app-scene touches"];
        [self haoge_touchflow_testCheck:![overlay.rootViewController respondsToSelector:NSSelectorFromString(@"haoge_touchflow_heading")] message:@"panel title removed"];
        [self haoge_touchflow_testCheck:![overlay.rootViewController respondsToSelector:NSSelectorFromString(@"haoge_touchflow_closeButton")] message:@"corner close button removed"];
        [self haoge_touchflow_testCheck:overlay.windowLevel==10000011.0 message:@"panel window above SpringBoard status layer"];
        [self haoge_touchflow_testCheck:![[haoge_touchflow_panelSettings() valueForKey:@"key"] containsObject:@"panelIconCornerPercent"] message:@"icon background radius setting removed"];
        UIViewController *controller=overlay.rootViewController;[controller.view layoutIfNeeded];
        NSArray *buttons=[controller valueForKey:@"haoge_touchflow_buttons"];
        NSArray *icons=[controller valueForKey:@"haoge_touchflow_icons"];
        [self haoge_touchflow_testCheck:buttons.count==1 message:@"one configured action creates one button"];
        [self haoge_touchflow_testCheck:icons.count==buttons.count&&[[icons.firstObject backgroundColor] isEqual:UIColor.clearColor] message:@"action icon has no background fill"];
        UIView *sheet=[controller valueForKey:@"haoge_touchflow_sheet"];
        [self haoge_touchflow_testCheck:CGRectGetMaxY(sheet.frame)<=CGRectGetHeight(overlay.bounds) && CGRectGetMinY(sheet.frame)>=0 message:@"panel fits scene bounds"];
        SEL outsideCheck=NSSelectorFromString(@"haoge_touchflow_shouldDismissForPoint:");
        CGPoint outside=CGPointMake(8,CGRectGetHeight(overlay.bounds)*0.5),inside=sheet.center;
        BOOL dismissOutside=((BOOL (*)(id,SEL,CGPoint))objc_msgSend)(controller,outsideCheck,outside);
        BOOL dismissInside=((BOOL (*)(id,SEL,CGPoint))objc_msgSend)(controller,outsideCheck,inside);
        [self haoge_touchflow_testCheck:dismissOutside message:@"tap outside the sheet closes the panel"];
        [self haoge_touchflow_testCheck:!dismissInside message:@"tap inside the sheet is not treated as outside"];
        NSArray *outsideRecognizers=controller.view.gestureRecognizers;
        UITapGestureRecognizer *outsideTap=nil;
        for (UIGestureRecognizer *recognizer in outsideRecognizers) if ([recognizer isKindOfClass:UITapGestureRecognizer.class]) { outsideTap=(id)recognizer; break; }
        [self haoge_touchflow_testCheck:outsideTap!=nil message:@"outside dismissal tap recognizer is installed"];
        ((void (*)(id,SEL,UIGestureRecognizer *))objc_msgSend)(controller,NSSelectorFromString(@"haoge_touchflow_outsideTapped:"),outsideTap);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(), ^{
            @try {
                [self haoge_touchflow_testCheck:![panel haoge_touchflow_isVisible] message:@"outside tap closes the panel"];
                [panel haoge_touchflow_showBinding:self.binding trigger:@"statusLeftTap" scene:nil sourceWindow:nil];
                [self haoge_touchflow_testCheck:[panel haoge_touchflow_isVisible] message:@"panel can reopen after outside tap"];
                NSArray *reopenedButtons=[[panel valueForKey:@"haoge_touchflow_controller"] valueForKey:@"haoge_touchflow_buttons"];
                UIButton *button=reopenedButtons.firstObject;
                [button sendActionsForControlEvents:UIControlEventTouchUpInside];[button sendActionsForControlEvents:UIControlEventTouchUpInside];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(), ^{
                    @try {
                        [self haoge_touchflow_testCheck:![panel haoge_touchflow_isVisible] message:@"selection cleans window"];
                        [self haoge_touchflow_testCheck:haoge_touchflow_testExecuted==1 message:@"double selection executes once"];
                        [panel haoge_touchflow_showBinding:self.binding trigger:@"statusLeftTap" scene:nil sourceWindow:nil];
                        [self haoge_touchflow_testCheck:[panel haoge_touchflow_isVisible] message:@"panel can reopen"];
                        [panel haoge_touchflow_dismiss];[panel haoge_touchflow_dismiss];
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,NSEC_PER_SEC),dispatch_get_main_queue(), ^{
                            @try {
                                [self haoge_touchflow_testCheck:![panel haoge_touchflow_isVisible] message:@"repeated close idempotent"];
                                [self haoge_touchflow_testCheck:haoge_touchflow_testExecuted==1 message:@"cancel must not run action"];
                                [self haoge_touchflow_testFinish:nil];
                            } @catch (NSException *e) {[self haoge_touchflow_testFinish:e.reason];}
                        });
                    } @catch (NSException *e) {[self haoge_touchflow_testFinish:e.reason];}
                });
            } @catch (NSException *e) {[self haoge_touchflow_testFinish:e.reason];}
        });
    } @catch (NSException *error) {[self haoge_touchflow_testFinish:error.reason];}
}
@end
int main(int argc,char **argv) { @autoreleasepool {return UIApplicationMain(argc,argv,nil,NSStringFromClass(HaogeTouchFlowTestApp.class));} }
