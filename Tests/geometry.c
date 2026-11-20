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
    HaogeTouchFlowBottomHold hold = {0};
    assert(haoge_touchflow_bottomSample(&hold,0,-119.9,1.0,0)==HaogeTouchFlowBottomNone);
    assert(hold.band==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-120,2.0,0)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-120,2.179,1)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-120,2.18,1)==HaogeTouchFlowBottomNear);
    hold = (HaogeTouchFlowBottomHold){0};
    assert(haoge_touchflow_bottomSample(&hold,0,-195,3.0,0)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-199.9,3.2,0)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-200,3.22,0)==HaogeTouchFlowBottomNone);
    assert(hold.band==HaogeTouchFlowBottomFar);
    assert(haoge_touchflow_bottomSample(&hold,0,-200,3.31,1)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-206,3.22+0.18,1)==HaogeTouchFlowBottomFar);
    assert(haoge_touchflow_bottomSample(&hold,0,-199,3.5,1)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-199,3.7,1)==HaogeTouchFlowBottomNear);
    hold = (HaogeTouchFlowBottomHold){0};
    assert(haoge_touchflow_bottomSample(&hold,0,-210,4.0,0)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,4,-219,4.4,1)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-110,4.6,1)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,200,-210,4.7,1)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,NAN,-220,5.0,1)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-220,NAN,1)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomSample(&hold,0,-220,6.0,1)==HaogeTouchFlowBottomNone);
    printf("PASS geometry and two-stage bottom hold/release checks\n");
    return 0;
}
