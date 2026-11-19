include ../HaogeTouchFlowBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = HaogeTouchFlowPrefs
HaogeTouchFlowPrefs_FILES = HaogeTouchFlowRootListController.m HaogeTouchFlowBindingController.m HaogeTouchFlowPanelSettings.m HaogeTouchFlowActionPickerController.m ../Sources/HaogeTouchFlowActionCatalog.m ../Sources/HaogeTouchFlowPanelModel.m
HaogeTouchFlowPrefs_CFLAGS = -fobjc-arc -I../Sources
HaogeTouchFlowPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
HaogeTouchFlowPrefs_PRIVATE_FRAMEWORKS = Preferences
HaogeTouchFlowPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
