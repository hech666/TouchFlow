#pragma once
#import <UIKit/UIKit.h>
// Test host intentionally has NO tableView selector; mirrors the observed iOS16
// PSListController limitation. Never compile this header into the shipped bundle.
@interface PSListController : UIViewController
@end
