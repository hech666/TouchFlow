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

typedef struct {
    HaogeTouchFlowBottomBand band;
    double x, y, since;
} HaogeTouchFlowBottomHold;

// Sample on movement and once on release. Crossing a band boundary or moving
// more than 8 pt from the hold anchor restarts the dwell. No timer can fire early.
static inline HaogeTouchFlowBottomBand haoge_touchflow_bottomSample(HaogeTouchFlowBottomHold *hold,
        double dx, double dy, double nearDistance, double farDistance, double now, int released) {
    HaogeTouchFlowBottomBand band = haoge_touchflow_upward(dx,dy,farDistance) ? HaogeTouchFlowBottomFar :
        (haoge_touchflow_upward(dx,dy,nearDistance) ? HaogeTouchFlowBottomNear : HaogeTouchFlowBottomNone);
    if (!isfinite(now) || band == HaogeTouchFlowBottomNone) {
        hold->band = HaogeTouchFlowBottomNone;
        return HaogeTouchFlowBottomNone;
    }
    double x = dx - hold->x, y = dy - hold->y;
    if (band != hold->band || x*x+y*y > 64 || now < hold->since) {
        hold->band = band; hold->x = dx; hold->y = dy; hold->since = now;
    }
    return released && now >= hold->since + 0.18 ? band : HaogeTouchFlowBottomNone;
}
static inline int haoge_touchflow_horizontal(double dx, double dy, double distance) {
    return isfinite(dx) && isfinite(dy) && isfinite(distance) && distance > 0 &&
           fabs(dx) >= distance && fabs(dx) > fabs(dy) * 1.3;
}
static inline double haoge_touchflow_finiteClamp(double value, double fallback, double lo, double hi) {
    return isfinite(value) ? fmax(lo, fmin(value, hi)) : fallback;
}
