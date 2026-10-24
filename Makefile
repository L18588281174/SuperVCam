ARCHS = arm64
TARGET = iphone:clang:latest:15.0
THEOS_PACKAGE_SCHEME = rootless
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = SuperVCam
SuperVCam_FILES = Tweak.x VCFrameEngine.m
SuperVCam_FRAMEWORKS = AVFoundation CoreMedia CoreVideo CoreImage UIKit Foundation PhotosUI Photos
SuperVCam_CFLAGS = -fobjc-arc
include $(THEOS_MAKE_PATH)/tweak.mk
