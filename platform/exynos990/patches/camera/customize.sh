LOG_STEP_IN "- Replacing camera blobs"
BLOBS_LIST="
system/lib64/libenn_wrapper_system.so
system/lib64/libpic_best.arcsoft.so
system/lib64/libarcsoft_dualcam_portraitlighting.so
system/lib64/libdualcam_refocus_gallery_54.so
system/lib64/libdualcam_refocus_gallery_50.so
system/lib64/libhybrid_high_dynamic_range.arcsoft.so
system/lib64/libae_bracket_hdr.arcsoft.so
system/lib64/libface_recognition.arcsoft.so
system/lib64/libDualCamBokehCapture.camera.samsung.so
"
for blob in $BLOBS_LIST
do
    DELETE_FROM_WORK_DIR "system" "$blob" &
done

# shellcheck disable=SC2046
wait $(jobs -p) || exit 1

BLOBS_LIST="
system/lib64/libPortraitDistortionCorrectionCali.arcsoft.so
system/lib64/libMultiFrameProcessing20.camera.samsung.so
system/lib64/libMultiFrameProcessing20Core.camera.samsung.so
system/lib64/libMultiFrameProcessing20Day.camera.samsung.so
system/lib64/libMultiFrameProcessing20Tuning.camera.samsung.so
system/lib64/libMultiFrameProcessing30.camera.samsung.so
system/lib64/libMultiFrameProcessing30.snapwrapper.camera.samsung.so
system/lib64/libMultiFrameProcessing30Tuning.camera.samsung.so
system/lib64/libGeoTrans10.so
system/lib64/vendor.samsung_slsi.hardware.geoTransService@1.0.so
system/lib64/libSwIsp_core.camera.samsung.so
system/lib64/libSwIsp_wrapper_v1.camera.samsung.so
"
for blob in $BLOBS_LIST
do
    ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "$blob" 0 0 644 "u:object_r:system_lib_file:s0" &
done

if [[ "$TARGET_CODENAME" == "c1s" || "$TARGET_CODENAME" == "c2s" ]]; then
    BLOBS_LIST="
    system/lib64/libofi_seva.so
    system/lib64/libofi_klm.so
    system/lib64/libofi_plugin.so
    system/lib64/libofi_rt_framework_user.so
    system/lib64/libofi_service_interface.so
    system/lib64/libofi_gc.so
    system/lib64/vendor.samsung_slsi.hardware.ofi@2.0.so
    system/lib64/vendor.samsung_slsi.hardware.ofi@2.1.so
    "
    for blob in $BLOBS_LIST
    do
        ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "$blob" 0 0 644 "u:object_r:system_lib_file:s0" &
    done
fi

# shellcheck disable=SC2046
wait $(jobs -p) || exit 1

LOG_STEP_OUT

LOG_STEP_IN "- Adding libc++_shared.so dependency for __cxa_demangle symbol"
patchelf --add-needed "libc++_shared.so" "$WORK_DIR/system/system/lib64/libMultiFrameProcessing20Core.camera.samsung.so"
LOG_STEP_OUT

LOG_STEP_IN "- Removing HDR10+ check"
if [[ "$SOURCE_PLATFORM_SDK_VERSION" -lt 36 ]]; then
    ADD_TO_WORK_DIR "pa3qzcx" "system" "system/lib64/libstagefright.so" 0 0 644 "u:object_r:system_lib_file:s0"
    HEX_PATCH "$WORK_DIR/system/system/lib64/libstagefright.so" \
        "010140f97069059420510034" \
        "010140f91f2003d51f2003d5"
else
    # Android 16 changed the Camera::connect ABI. Replacing this library with
    # the older pa3qzcx blob makes zygote, cameraserver and the media services
    # fail at link time, so retain the source firmware's matched media stack.
    LOG "Skipping legacy HDR10+ blob on Android 16"
    ADD_TO_WORK_DIR "$SOURCE_FIRMWARE" "system" \
        "system/lib64/libstagefright.so" 0 0 644 \
        "u:object_r:system_lib_file:s0"

    # The Android 16 media stack retained Samsung's background recording API,
    # but MediaCodecSource::suspendRecording(bool) is now a no-op. Exynos 990
    # Super Slow Motion still creates its persistent encoder input suspended
    # and relies on that method to resume it, otherwise the recording finishes
    # with zero encoded frames. Start that input active instead.
    # HEX_PATCH "$WORK_DIR/system/system/lib64/libstagefright.so" \
    #   "010140f90a4d0594604d0034" \
    #   "010140f90a4d05941f2003d5"

    # Android 16 configures temporal SVC for high-frame-rate recordings. The
    # legacy Exynos HEVC OMX encoder does not implement the queried extension
    # and returns ERROR_UNSUPPORTED. Keep the encoder setup going without SVC;
    # AVC encoders that support the extension continue through the same path.
    # (cbz w0 -> b ngay sau bl ACodec::configureSVC). 3 byte "be4d05" là offset của bl
    # configureSVC@plt, phụ thuộc bản build libstagefright.so của firmware nguồn.
    HEX_PATCH "$WORK_DIR/system/system/lib64/libstagefright.so" \
        "e10740b9e22340b9e00313aabe4d059420020034fa03002a" \
        "e10740b9e22340b9e00313aabe4d059411000014fa03002a"
        
    #Patch the backward-in-time check to fall through and adopt the new session's timestamp.
    HEX_PATCH "$WORK_DIR/vendor/lib/libstagefright_bufferqueue_helper_vendor.so" \
        "d7e94601401b71eb060006da" \
        "d7e94601401b71eb060000bf"     
fi
LOG_STEP_OUT

LOG_STEP_IN "- Adding OFI/SEVA libs required by MFP20 (LLHDR/MFHDR)"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libinference_engine.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libofi_gc.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libofi_klm.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libofi_plugin.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libofi_rt_framework_user.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libofi_service_interface.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/libofi_seva.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/vendor.samsung_slsi.hardware.ofi@2.0.so" 0 0 644 "u:object_r:system_lib_file:s0"
ADD_TO_WORK_DIR "$TARGET_FIRMWARE" "system" "system/lib64/vendor.samsung_slsi.hardware.ofi@2.1.so" 0 0 644 "u:object_r:system_lib_file:s0"
LOG_STEP_OUT

LOG_STEP_IN "- Adding prebuilt libs from other devices"
BLOBS_LIST="
system/lib64/libc++_shared.so
"
for blob in $BLOBS_LIST
do
    ADD_TO_WORK_DIR "e2sxxx" "system" "$blob" 0 0 644 "u:object_r:system_lib_file:s0"
done

BLOBS_LIST="
system/lib64/libeden_wrapper_system.so
system/lib64/libhigh_dynamic_range.arcsoft.so
system/lib64/liblow_light_hdr.arcsoft.so
system/lib64/libhigh_res.arcsoft.so
system/lib64/libsnap_aidl.snap.samsung.so
system/lib64/libsuperresolution.arcsoft.so
system/lib64/libsuperresolution_raw.arcsoft.so
system/lib64/libsuperresolution_wrapper_v2.camera.samsung.so
system/lib64/libsuperresolutionraw_wrapper_v2.camera.samsung.so
"
for blob in $BLOBS_LIST
do
    ADD_TO_WORK_DIR "p3sxxx" "system" "$blob" 0 0 644 "u:object_r:system_lib_file:s0" &
done

# shellcheck disable=SC2046
wait $(jobs -p) || exit 1

LOG_STEP_OUT

LOG_STEP_IN "- Passing per-frame EV to ArcSoft LLHDR/MFHDR"
# The ArcSoft LLHDR/MFHDR nodes send samsung.android.sensor.captureEv as the frame EV,
# but the Exynos 990 HAL does not reflect the bracket there, so the p3s ArcSoft libs reject
# every burst (ARC_LLHDR_Process fail(2)). The bracket offset, in the same 1/256 EV units,
# is in samsung.android.sensor.multiFrameEv.
# Both native nodes pass (ref EV - frame EV) to the library, so they get the negated offset.
# Obfuscated key names of this SamsungCamera build: captureEv = u1, multiFrameEv = z1.

SMALI_PATCH "system" "system/priv-app/SamsungCamera/SamsungCamera.apk" \
    "smali_classes3/com/samsung/android/camera/core2/node/llhdr/arcsoft/ArcLlHdrNodeBase.smali" "replace" \
    'setExtraCaptureInfo(Lcom/samsung/android/camera/core2/local/vendorkey/CaptureMetadata;)V' \
    'sget-object v2, Lcom/samsung/android/camera/core2/local/vendorkey/SemCaptureResult;->u1:Landroid/hardware/camera2/CaptureResult$Key;' \
    'sget-object v2, Lcom/samsung/android/camera/core2/local/vendorkey/SemCaptureResult;->z1:Landroid/hardware/camera2/CaptureResult$Key;' \
    > /dev/null
SMALI_PATCH "system" "system/priv-app/SamsungCamera/SamsungCamera.apk" \
    "smali_classes3/com/samsung/android/camera/core2/node/llhdr/arcsoft/ArcLlHdrNodeBase.smali" "replace" \
    'setExtraCaptureInfo(Lcom/samsung/android/camera/core2/local/vendorkey/CaptureMetadata;)V' \
    '.locals 3' \
    '.locals 4' \
    > /dev/null
SMALI_PATCH "system" "system/priv-app/SamsungCamera/SamsungCamera.apk" \
    "smali_classes3/com/samsung/android/camera/core2/node/llhdr/arcsoft/ArcLlHdrNodeBase.smali" "replace" \
    'setExtraCaptureInfo(Lcom/samsung/android/camera/core2/local/vendorkey/CaptureMetadata;)V' \
    'filled-new-array {v0, v1, p1}, [Ljava/lang/Object;' \
    $'invoke-virtual {p1}, Ljava/lang/Integer;->intValue()I\n    move-result v3\n    neg-int v3, v3\n    invoke-static {v3}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;\n    move-result-object v3\n    filled-new-array {v0, v1, v3}, [Ljava/lang/Object;' \
    > /dev/null
SMALI_PATCH "system" "system/priv-app/SamsungCamera/SamsungCamera.apk" \
    "smali_classes3/com/samsung/android/camera/core2/node/mfhdr/arcsoft/v4/ArcMfHdrNode.smali" "replace" \
    'nativeCallSpecificCommand(Lcom/samsung/android/camera/core2/local/vendorkey/CaptureMetadata;)V' \
    'sget-object v0, Lcom/samsung/android/camera/core2/local/vendorkey/SemCaptureResult;->u1:Landroid/hardware/camera2/CaptureResult$Key;' \
    'sget-object v0, Lcom/samsung/android/camera/core2/local/vendorkey/SemCaptureResult;->z1:Landroid/hardware/camera2/CaptureResult$Key;' \
    > /dev/null
SMALI_PATCH "system" "system/priv-app/SamsungCamera/SamsungCamera.apk" \
    "smali_classes3/com/samsung/android/camera/core2/node/mfhdr/arcsoft/v4/ArcMfHdrNode.smali" "replace" \
    'nativeCallSpecificCommand(Lcom/samsung/android/camera/core2/local/vendorkey/CaptureMetadata;)V' \
    'const-string/jumbo v0, "processPicture: captureEv = %d"' \
    $'invoke-virtual {p1}, Ljava/lang/Integer;->intValue()I\n    move-result v0\n    neg-int v0, v0\n    invoke-static {v0}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;\n    move-result-object p1\n    const-string/jumbo v0, "processPicture: -multiFrameEv = %d"' \
    > /dev/null
LOG_STEP_OUT

LOG_STEP_IN "- Enabling scene detection for document scan"
# IntelligentManager.isSceneOptimizerAvailable() feeds enableSceneDetection(). Make it also
# return true when ADDITIONAL_SCENE_DOCUMENT_SCAN is on. p0 (this) is overwritten there, so
# keep the CameraSettings object in v2 (free at that point) for the extra check.
SMALI_PATCH "system" "system/priv-app/SamsungCamera/SamsungCamera.apk" \
    "smali_classes4/com/sec/android/app/camera/shootingmode/photo/intelligentui/IntelligentManager.smali" "replace" \
    'isSceneOptimizerAvailable()Z' \
    'iget-object p0, p0, Lcom/sec/android/app/camera/shootingmode/photo/intelligentui/IntelligentManager;->mCameraSettings:Lcom/sec/android/app/camera/interfaces/CameraSettings;' \
    $'iget-object v2, p0, Lcom/sec/android/app/camera/shootingmode/photo/intelligentui/IntelligentManager;->mCameraSettings:Lcom/sec/android/app/camera/interfaces/CameraSettings;\n\n    move-object p0, v2' \
    > /dev/null
SMALI_PATCH "system" "system/priv-app/SamsungCamera/SamsungCamera.apk" \
    "smali_classes4/com/sec/android/app/camera/shootingmode/photo/intelligentui/IntelligentManager.smali" "replace" \
    'isSceneOptimizerAvailable()Z' \
    'if-ne p0, v0, :cond_3' \
    $'if-eq p0, v0, :cond_doc_ok\n\n    sget-object p0, Lcom/sec/android/app/camera/interfaces/CameraSettings$Key;->ADDITIONAL_SCENE_DOCUMENT_SCAN:Lcom/sec/android/app/camera/interfaces/CameraSettings$Key;\n\n    invoke-interface {v2, p0}, Lcom/sec/android/app/camera/interfaces/CameraSettings;->get(Lcom/sec/android/app/camera/interfaces/CameraSettings$Key;)I\n\n    move-result p0\n\n    if-ne p0, v0, :cond_3\n\n    :cond_doc_ok' \
    > /dev/null
LOG_STEP_OUT

LOG_STEP_IN "- Adding S21 (p3sxxx) SWISP models"
DELETE_FROM_WORK_DIR "vendor" "saiv/swisp_1.0"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "saiv/swisp_1.0"

BLOBS_LIST="
system/lib64/libSwIsp_core.camera.samsung.so
system/lib64/libSwIsp_wrapper_v1.camera.samsung.so
"
for blob in $BLOBS_LIST
do
    ADD_TO_WORK_DIR "p3sxxx" "system" "$blob" 0 0 644 "u:object_r:system_lib_file:s0"
done
LOG_STEP_OUT

LOG_STEP_IN "- Adding S21 (p3sxxx) SingleTake models"
DELETE_FROM_WORK_DIR "vendor" "etc/singletake"
ADD_TO_WORK_DIR "p3sxxx" "vendor" "etc/singletake"

BLOBS_LIST="
system/priv-app/SingleTakeService/SingleTakeService.apk
system/cameradata/singletake/service-feature.xml
"
for blob in $BLOBS_LIST
do
    ADD_TO_WORK_DIR "p3sxxx" "system" "$blob" 0 0 644 "u:object_r:system_file:s0" &
done

# shellcheck disable=SC2046
wait $(jobs -p) || exit 1

LOG_STEP_OUT
