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
static inline int haoge_touchflow_horizontal(double dx, double dy, double distance) {
    return isfinite(dx) && isfinite(dy) && isfinite(distance) && distance > 0 &&
           fabs(dx) >= distance && fabs(dx) > fabs(dy) * 1.3;
}
static inline double haoge_touchflow_finiteClamp(double value, double fallback, double lo, double hi) {
    return isfinite(value) ? fmax(lo, fmin(value, hi)) : fallback;
}
