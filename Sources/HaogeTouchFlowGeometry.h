#pragma once
#include <math.h>
// Positive widths leave the middle >=34% to the system. 0 means middle/invalid.
static inline int haoge_touchflow_side(double x, double width, double percent) {
    if (!isfinite(x) || !isfinite(width) || width <= 0 || x < 0 || x > width) return 0;
    percent = isfinite(percent) ? fmin(33.0, fmax(10.0, percent)) : 25.0;
    double edge = width * percent / 100.0;
    return x < edge ? -1 : (x > width - edge ? 1 : 0);
}
static inline int haoge_touchflow_upward(double dx, double dy, double distance) {
    return isfinite(dx) && isfinite(dy) && isfinite(distance) && distance > 0 &&
           -dy >= distance && -dy > fabs(dx) * 1.15;
}
enum {
    HaogeTouchFlowBottomNearMin = 60, HaogeTouchFlowBottomNearDefault = 110, HaogeTouchFlowBottomNearMax = 200,
    HaogeTouchFlowBottomFarMin = 200, HaogeTouchFlowBottomFarDefault = 200, HaogeTouchFlowBottomFarMax = 280
};

typedef enum {
    HaogeTouchFlowBottomNone = 0, HaogeTouchFlowBottomNear, HaogeTouchFlowBottomFar
} HaogeTouchFlowBottomBand;

// The higher threshold wins if both are met, including equal thresholds.
static inline HaogeTouchFlowBottomBand haoge_touchflow_bottomBand(
        double dx, double dy, double nearDistance, double farDistance) {
    if (haoge_touchflow_upward(dx,dy,farDistance)) return HaogeTouchFlowBottomFar;
    if (haoge_touchflow_upward(dx,dy,nearDistance)) return HaogeTouchFlowBottomNear;
    return HaogeTouchFlowBottomNone;
}

// Remain quiet for consecutive samples in the same band. Returning to a
// different band is a new cue because it changes what release would do.
static inline int haoge_touchflow_bottomEnterBand(HaogeTouchFlowBottomBand *previous,
        HaogeTouchFlowBottomBand current) {
    int changed = *previous != current;
    *previous = current;
    return changed && current != HaogeTouchFlowBottomNone;
}
static inline int haoge_touchflow_horizontal(double dx, double dy, double distance) {
    return isfinite(dx) && isfinite(dy) && isfinite(distance) && distance > 0 &&
           fabs(dx) >= distance && fabs(dx) > fabs(dy) * 1.3;
}
static inline int haoge_touchflow_hapticLevelFromLegacy(int level) {
    switch (level) {
        case 0: return 0;
        case 1: return 1;
        case 2: return 1; // former medium becomes the stronger weak preset
        case 3: return 2; // former strong becomes medium; new strong is level 3
        default: return 1;
    }
}
static inline double haoge_touchflow_hapticIntensityForLevel(int level) {
    switch (level) {
        case 0: return 0.0;
        case 1: return 0.8;
        case 2: return 1.0;
        case 3: return 1.0; // heavy double pulse; Apple impact intensity tops out at 1.0
        default: return 0.8;
    }
}
static inline double haoge_touchflow_finiteClamp(double value, double fallback, double lo, double hi) {
    return isfinite(value) ? fmax(lo, fmin(value, hi)) : fallback;
}
