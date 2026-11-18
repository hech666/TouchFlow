#include <assert.h>
#include <stdio.h>
#include "../Sources/HaogeTouchFlowGeometry.h"
int main(void) {
    // Boundary touches must stay with the system center, not reserve both sides.
    assert(haoge_touchflow_side(0,400,25)==-1);
    assert(haoge_touchflow_side(99,400,25)==-1);
    assert(haoge_touchflow_side(100,400,25)==0);
    assert(haoge_touchflow_side(200,400,25)==0);
    assert(haoge_touchflow_side(300,400,25)==0);
    assert(haoge_touchflow_side(301,400,25)==1);
    assert(haoge_touchflow_side(-1,400,25)==0);
    assert(haoge_touchflow_side(401,400,25)==0);
    assert(haoge_touchflow_side(NAN,400,25)==0);
    assert(haoge_touchflow_side(10,0,25)==0);
    assert(haoge_touchflow_side(180,400,99)==0);
    assert(haoge_touchflow_side(35,400,-1)==-1);
    assert(haoge_touchflow_upward(0,-110,110));
    assert(!haoge_touchflow_upward(0,-109,110));
    assert(!haoge_touchflow_upward(0,120,110));
    assert(!haoge_touchflow_upward(130,-110,110));
    assert(!haoge_touchflow_upward(NAN,-110,110));
    assert(haoge_touchflow_horizontal(-60,0,60));
    assert(haoge_touchflow_horizontal(60,0,60));
    assert(!haoge_touchflow_horizontal(59,0,60));
    assert(!haoge_touchflow_horizontal(60,50,60));
    assert(!haoge_touchflow_horizontal(INFINITY,0,60));
    assert(haoge_touchflow_finiteClamp(NAN,25,10,33)==25);
    assert(haoge_touchflow_finiteClamp(99,25,10,33)==33);
    assert(haoge_touchflow_finiteClamp(-1,25,10,33)==10);
    printf("PASS 25 geometry boundary/direction/NaN checks\n");
    return 0;
}
