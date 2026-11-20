#include <assert.h>
#include <stdio.h>
#include "../Sources/HaogeTouchFlowGeometry.h"

int main(void) {
    // Boundary touches stay with the system center.
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

    assert(haoge_touchflow_bottomBand(0,-119.9,120,200)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomBand(0,-120,120,200)==HaogeTouchFlowBottomNear);
    assert(haoge_touchflow_bottomBand(0,-199.9,120,200)==HaogeTouchFlowBottomNear);
    assert(haoge_touchflow_bottomBand(0,-200,120,200)==HaogeTouchFlowBottomFar);
    assert(haoge_touchflow_bottomBand(0,-59.9,60,280)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomBand(0,-60,60,280)==HaogeTouchFlowBottomNear);
    assert(haoge_touchflow_bottomBand(0,-279.9,180,280)==HaogeTouchFlowBottomNear);
    assert(haoge_touchflow_bottomBand(0,-280,180,280)==HaogeTouchFlowBottomFar);
    assert(haoge_touchflow_bottomBand(0,-300,180,280)==HaogeTouchFlowBottomFar);
    assert(haoge_touchflow_bottomBand(0,-200,200,200)==HaogeTouchFlowBottomFar);
    assert(haoge_touchflow_bottomBand(200,-210,120,200)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomBand(0,210,120,200)==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomBand(NAN,-220,120,200)==HaogeTouchFlowBottomNone);

    // A new valid band gives one cue. Further movement in it stays quiet.
    HaogeTouchFlowBottomBand previous = HaogeTouchFlowBottomNone;
    assert(!haoge_touchflow_bottomEnterBand(&previous,HaogeTouchFlowBottomNone));
    assert(haoge_touchflow_bottomEnterBand(&previous,HaogeTouchFlowBottomNear));
    assert(!haoge_touchflow_bottomEnterBand(&previous,HaogeTouchFlowBottomNear));
    assert(haoge_touchflow_bottomEnterBand(&previous,HaogeTouchFlowBottomFar));
    assert(!haoge_touchflow_bottomEnterBand(&previous,HaogeTouchFlowBottomFar));
    assert(haoge_touchflow_bottomEnterBand(&previous,HaogeTouchFlowBottomNear));
    assert(!haoge_touchflow_bottomEnterBand(&previous,HaogeTouchFlowBottomNone));
    assert(previous==HaogeTouchFlowBottomNone);
    assert(haoge_touchflow_bottomEnterBand(&previous,HaogeTouchFlowBottomFar));
    assert(haoge_touchflow_hapticIntensityForLevel(0)==0.0);
    assert(haoge_touchflow_hapticIntensityForLevel(1)==0.8);
    assert(haoge_touchflow_hapticIntensityForLevel(2)==1.0);
    assert(haoge_touchflow_hapticIntensityForLevel(3)==1.0);
    assert(haoge_touchflow_hapticLevelFromLegacy(0)==0);
    assert(haoge_touchflow_hapticLevelFromLegacy(1)==1);
    assert(haoge_touchflow_hapticLevelFromLegacy(2)==1);
    assert(haoge_touchflow_hapticLevelFromLegacy(3)==2);
    assert(haoge_touchflow_hapticLevelFromLegacy(99)==1);
    printf("PASS geometry, tier cues, legacy migration and stronger haptics\n");
    return 0;
}
