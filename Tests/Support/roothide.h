#pragma once
#import <Foundation/Foundation.h>
// Simulator-only test path; the production build uses the real Theos roothide.h.
static inline NSString *haoge_touchflow_test_jbroot(NSString *path) {
    NSArray *dirs=NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES);
    return [dirs.firstObject stringByAppendingPathComponent:path.lastPathComponent];
}
#define jbroot(path) haoge_touchflow_test_jbroot(path)
