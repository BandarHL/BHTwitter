THEOS_PACKAGE_SCHEME := roothide
ARCHS := arm64
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES := Twitter

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := HideReposts

HideReposts_FILES := Tweak.x
HideReposts_FRAMEWORKS := Foundation UIKit
HideReposts_CFLAGS := -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
