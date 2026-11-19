#pragma once
#import <Foundation/Foundation.h>
// Catalog entries: identifier, title, detail, valueHint/url (optional), needsValue (NSNumber).
// Catalog .m is compiled into tweak and preference bundle (functions only, no duplicate classes).
NSArray<NSDictionary *> *haoge_touchflow_actionCatalog(void);
NSString *haoge_touchflow_actionTitle(NSString *identifier);
BOOL haoge_touchflow_actionNeedsValue(NSString *identifier);
// App-entry URLs selected by built-in actions; nil for all other identifiers.
NSURL *haoge_touchflow_actionURL(NSString *identifier);
// Runtime implementation is compiled into the SpringBoard tweak only.
// Always schedules or performs on main; a nil/invalid binding is a no-op.
void haoge_touchflow_executeBinding(NSDictionary *binding);
