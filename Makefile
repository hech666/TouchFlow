DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include HaogeTouchFlowBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HaogeTouchFlow
HaogeTouchFlow_FILES = $(wildcard Hooks/*.xm Sources/*.m)
HaogeTouchFlow_CFLAGS = -fobjc-arc -I./Headers -I./Sources
HaogeTouchFlow_FRAMEWORKS = UIKit Foundation CoreFoundation AVFoundation QuartzCore
HaogeTouchFlow_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += HaogeTouchFlowPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
