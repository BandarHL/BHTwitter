TARGET := iphone:clang:latest:14.0
INSTALL_TARGET_PROCESSES = Twitter


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = keychainfix

keychainfix_FILES = Tweak.x
keychainfix_FRAMEWORKS = UIKit Foundation Security
keychainfix_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
