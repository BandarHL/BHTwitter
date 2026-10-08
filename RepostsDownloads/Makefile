THEOS_PACKAGE_SCHEME := rootless
ARCHS := arm64
TARGET := iphone:clang:16.5:15.0
INSTALL_TARGET_PROCESSES := Twitter
FINALPACKAGE := 1

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := BHRD
BHRD_FILES := RecommendationFeatures.x BHRDContentFilter.m BHRDConfirmationGate.m Confirmations.x Recommendations.x Ads.x BHRDAdFilter.m BHRDShareMediaQuality.m BHRDShareTextCleanup.m BHRDInlineButtonStyle.m BHRDShareLoadedMedia.m BHRDShareVisibleData.m BHRDShareImageButton.m BHRDSharePost.m BHRDShareRenderer.m BHRDShareImageController.m BHRDShareGesture.m BHRDMediaResolver.m BHRDFullscreenVisibility.m BHRDLayoutGeometry.m BHRDInlineLayout.m BHRDTaskState.m BHRDDownloadProgress.m BHRDStreamJob.m BHRDHomePaging.m Interface.x BHRDHomeHeader.m BHRDHomeHeaderView.m BHRDFullscreenActionRouter.m BHRDFullscreenDownloadControl.m Tweak.x Reposts.x BHRDRepostModel.m BHRDRepostPresentation.m BHRDManager.m BHRDPreferences.m BHRDSettingsList.m BHRDDownload.m BHRDDownloadButton.m BHRDRepostFilter.m BHRDSettingsViewController.m $(wildcard ../JGProgressHUD/*.m)
BHRD_FILES += BHRDFullscreenContext.m BHRDPhotoClipboard.m BHRDFileNaming.m BHRDFullscreenPhotoResolver.m BHRDPhotoCopyData.m BHRDFullscreenPhotoCopy.m BHRDShareRenderState.m BHRDStreamArguments.m BHRDDownloadStore.m BHRDDownloadsViewController.m BHRDConversationScope.m BHRDRepostAuthor.m BHRDRepostAuthorRows.m
BHRD_FRAMEWORKS := QuartzCore CoreText ImageIO UIKit Foundation AVFoundation AVKit VideoToolbox Accelerate CoreMedia CoreGraphics AudioToolbox Photos Security SystemConfiguration
BHRD_OBJ_FILES := $(wildcard ../lib/*.a)
BHRD_LIBRARIES := bz2 c++ iconv z
BHRD_FILES += BHRDAvatarDiagnostics.m BHRDDiagnosticsViewController.m
BHRD_FILES += BHRDPhotoLibrarySave.m
BHRD_FILES += BHRDSafety.m Recovery.x
BHRD_FILES += BHRDRuntimeStatus.m BHRDRuntimeStatusViewController.m
BHRD_FILES += BHRDAcceptance.m BHRDAcceptanceViewController.m BHRDPerformanceMonitor.m BHRDPerformanceStats.m
BHRD_FILES += BHRDFullscreenVideoResolver.m
BHRD_CFLAGS := -fobjc-arc -Wno-deprecated-declarations -Wno-nullability-completeness
BHRD_CFLAGS += -I$(CURDIR)/.theos/xsuixin-build

ifeq ($(BHRD_DIAGNOSTICS),1)
BHRD_FILES += Diagnostics.x
BHRD_CFLAGS += -DBHRD_DIAGNOSTICS=1
endif

# All product builds include the bounded local log and its viewer/export UI.
BHRD_CFLAGS += -DBHRD_AVATAR_DIAGNOSTICS=1

include $(THEOS_MAKE_PATH)/tweak.mk
