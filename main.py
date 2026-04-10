import sys
import os
import time
import cv2
from PySide6.QtGui import QGuiApplication, QFont, QImage
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QObject, Slot, Property, Signal, QTimer, QThread
from PySide6.QtQuick import QQuickImageProvider
import assets
from i18n import I18n
from settings_store import load_json, save_json

# --- Default settings ---
DEFAULTS = {
    "motion_h": 50, "motion_v": 50, "motion_accel": 40,
    "motion_smooth": 65, "motion_thresh": 25,
    "dwell_click_enabled": True,
    "blink_left_click": True, "blink_right_click": True,
    "click_sound": True, "click_hud": "normal",
    "auto_start": False,
    "theme_id": "cyber", "dark_mode": True,
    "floating": {
        "click": True, "doubleclick": True, "drag": True, "drop": True,
        "screenshot": True, "scroll_up": True, "scroll_down": True,
        "scroll_left": True, "scroll_right": True, "pause": True,
    },
    "dwell_time_ms": 900, "cursor_speed": 50,
    "high_contrast": False, "reduce_motion": False,
    "font_scale": 1.0, "keyboard_layout": "en", "language": "en",
    "fab_enabled": True,
}

FLOAT_IDS = [
    "click", "doubleclick", "drag", "drop", "screenshot",
    "scroll_up", "scroll_down", "scroll_left", "scroll_right", "pause",
]


class CameraProvider(QQuickImageProvider):
    def __init__(self):
        super().__init__(QQuickImageProvider.Image)
        self._image = QImage()

    def requestImage(self, id, size, requestedSize):
        if self._image.isNull():
            return QImage(1, 1, QImage.Format_RGB32)
        return self._image

    def update_image(self, image):
        self._image = image


class CameraWorker(QThread):
    image_ready = Signal(QImage)

    def __init__(self):
        super().__init__()
        self._running = True

    def run(self):
        cap = cv2.VideoCapture(0)
        while self._running:
            ret, frame = cap.read()
            if ret:
                frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                h, w, ch = frame.shape
                bytes_per_line = ch * w
                q_img = QImage(frame.data, w, h, bytes_per_line, QImage.Format_RGB888)
                self.image_ready.emit(q_img.copy())
            self.msleep(30)
        cap.release()

    def stop(self):
        self._running = False
        self.wait()


class CyberStoneLogic(QObject):
    cameraFrameUpdated = Signal()
    screenChanged = Signal()
    notificationsUpdated = Signal()
    keyboardTextChanged = Signal()
    highContrastChanged = Signal()
    reduceMotionChanged = Signal()
    fontScaleChanged = Signal()
    dwellTimeChanged = Signal()
    cursorSpeedChanged = Signal()
    keyboardLayoutChanged = Signal()
    trackingPausedChanged = Signal()
    settingsTabChanged = Signal()
    cameraConnectedChanged = Signal()
    calibrationActiveChanged = Signal()
    calibrationProgressChanged = Signal()
    calibrationStepChanged = Signal()
    trackingQualityChanged = Signal()
    stabilityScoreChanged = Signal()
    calibrationFinished = Signal()
    # Extended properties signals
    motionHorizontalChanged = Signal()
    motionVerticalChanged = Signal()
    motionAccelerationChanged = Signal()
    motionSmoothnessChanged = Signal()
    motionThresholdChanged = Signal()
    dwellClickEnabledChanged = Signal()
    blinkLeftClickEnabledChanged = Signal()
    blinkRightClickEnabledChanged = Signal()
    clickSoundEnabledChanged = Signal()
    clickHudStyleChanged = Signal()
    autoStartOnBootChanged = Signal()
    themeIdChanged = Signal()
    darkModeChanged = Signal()
    appLanguageChanged = Signal()
    floatingActionsModelChanged = Signal()
    fabEnabledChanged = Signal()
    mainUIVisibleChanged = Signal()

    def __init__(self, camera_provider):
        super().__init__()
        self._camera_provider = camera_provider
        self._cfg = load_json(DEFAULTS)
        self._snapshot = {}  # for cancel

        self._screen = "dashboard"
        self._notifications = []
        self._keyboard_text = ""
        self._high_contrast = self._cfg.get("high_contrast", False)
        self._reduce_motion = self._cfg.get("reduce_motion", False)
        self._font_scale = self._cfg.get("font_scale", 1.0)
        self._dwell_time_ms = self._cfg.get("dwell_time_ms", 900)
        self._cursor_speed = self._cfg.get("cursor_speed", 50)
        self._keyboard_layout = self._cfg.get("keyboard_layout", "en")
        self._tracking_paused = False
        self._settings_tab = "motion"
        self._camera_connected = False
        self._last_frame_mono = 0.0
        self._calibration_active = False
        self._calibration_progress = 0
        self._calibration_step = 0
        self._tracking_quality = 36
        self._stability_score = 40

        # Extended settings
        self._motion_h = self._cfg.get("motion_h", 50)
        self._motion_v = self._cfg.get("motion_v", 50)
        self._motion_accel = self._cfg.get("motion_accel", 40)
        self._motion_smooth = self._cfg.get("motion_smooth", 65)
        self._motion_thresh = self._cfg.get("motion_thresh", 25)
        self._dwell_click_enabled = self._cfg.get("dwell_click_enabled", True)
        self._blink_left = self._cfg.get("blink_left_click", True)
        self._blink_right = self._cfg.get("blink_right_click", True)
        self._click_sound = self._cfg.get("click_sound", True)
        self._click_hud = self._cfg.get("click_hud", "normal")
        self._auto_start = self._cfg.get("auto_start", False)
        self._theme_id = self._cfg.get("theme_id", "cyber")
        self._dark_mode = self._cfg.get("dark_mode", True)
        self._app_language = self._cfg.get("language", "en")
        self._fab_enabled = self._cfg.get("fab_enabled", True)
        self._main_ui_visible = True
        fl = self._cfg.get("floating", DEFAULTS["floating"])
        self._floating = {k: fl.get(k, True) for k in FLOAT_IDS}

        self._watch = QTimer()
        self._watch.timeout.connect(self._refresh_camera_state)
        self._watch.start(800)

    # ---- helpers ----
    def _save(self):
        self._cfg.update({
            "motion_h": self._motion_h, "motion_v": self._motion_v,
            "motion_accel": self._motion_accel, "motion_smooth": self._motion_smooth,
            "motion_thresh": self._motion_thresh,
            "dwell_click_enabled": self._dwell_click_enabled,
            "blink_left_click": self._blink_left, "blink_right_click": self._blink_right,
            "click_sound": self._click_sound, "click_hud": self._click_hud,
            "auto_start": self._auto_start, "theme_id": self._theme_id,
            "dark_mode": self._dark_mode,
            "floating": dict(self._floating),
            "dwell_time_ms": self._dwell_time_ms, "cursor_speed": self._cursor_speed,
            "high_contrast": self._high_contrast, "reduce_motion": self._reduce_motion,
            "font_scale": self._font_scale, "keyboard_layout": self._keyboard_layout,
            "language": self._app_language, "fab_enabled": self._fab_enabled,
        })
        save_json(self._cfg)

    def _refresh_camera_state(self):
        alive = (time.monotonic() - self._last_frame_mono) < 2.0
        if alive != self._camera_connected:
            self._camera_connected = alive
            self.cameraConnectedChanged.emit()

    # ===== CORE PROPERTIES =====
    @Property(str, notify=screenChanged)
    def screen(self):
        return self._screen

    @screen.setter
    def screen(self, val):
        if self._screen != val:
            self._screen = val
            self.screenChanged.emit()

    @Property(str, notify=keyboardTextChanged)
    def keyboardText(self):
        return self._keyboard_text

    @Property("QVariantList", notify=notificationsUpdated)
    def notifications(self):
        return self._notifications

    @Property(bool, notify=highContrastChanged)
    def highContrast(self):
        return self._high_contrast

    @highContrast.setter
    def highContrast(self, v):
        if self._high_contrast != v:
            self._high_contrast = v
            self.highContrastChanged.emit()

    @Property(bool, notify=reduceMotionChanged)
    def reduceMotion(self):
        return self._reduce_motion

    @reduceMotion.setter
    def reduceMotion(self, v):
        if self._reduce_motion != v:
            self._reduce_motion = v
            self.reduceMotionChanged.emit()

    @Property(float, notify=fontScaleChanged)
    def fontScale(self):
        return self._font_scale

    @fontScale.setter
    def fontScale(self, v):
        v = max(1.0, min(1.45, float(v)))
        if abs(self._font_scale - v) > 1e-6:
            self._font_scale = v
            self.fontScaleChanged.emit()

    @Property(int, notify=dwellTimeChanged)
    def dwellTimeMs(self):
        return self._dwell_time_ms

    @dwellTimeMs.setter
    def dwellTimeMs(self, v):
        v = max(400, min(2200, int(v)))
        if self._dwell_time_ms != v:
            self._dwell_time_ms = v
            self.dwellTimeChanged.emit()

    @Property(int, notify=cursorSpeedChanged)
    def cursorSpeed(self):
        return self._cursor_speed

    @cursorSpeed.setter
    def cursorSpeed(self, v):
        v = max(10, min(100, int(v)))
        if self._cursor_speed != v:
            self._cursor_speed = v
            self.cursorSpeedChanged.emit()

    @Property(str, notify=keyboardLayoutChanged)
    def keyboardLayout(self):
        return self._keyboard_layout

    @keyboardLayout.setter
    def keyboardLayout(self, v):
        if v in ("en", "ar") and v != self._keyboard_layout:
            self._keyboard_layout = v
            self.keyboardLayoutChanged.emit()

    @Property(bool, notify=trackingPausedChanged)
    def trackingPaused(self):
        return self._tracking_paused

    @trackingPaused.setter
    def trackingPaused(self, v):
        if self._tracking_paused != v:
            self._tracking_paused = v
            self.trackingPausedChanged.emit()

    @Property(str, notify=settingsTabChanged)
    def settingsTab(self):
        return self._settings_tab

    @settingsTab.setter
    def settingsTab(self, v):
        valid = ("motion", "click", "system", "appearance", "floating")
        if v in valid and v != self._settings_tab:
            self._settings_tab = v
            self.settingsTabChanged.emit()

    @Property(bool, notify=cameraConnectedChanged)
    def cameraConnected(self):
        return self._camera_connected

    @Property(bool, notify=calibrationActiveChanged)
    def calibrationActive(self):
        return self._calibration_active

    @Property(int, notify=calibrationProgressChanged)
    def calibrationProgress(self):
        return self._calibration_progress

    @Property(int, notify=calibrationStepChanged)
    def calibrationStep(self):
        return self._calibration_step

    @Property(int, notify=trackingQualityChanged)
    def trackingQuality(self):
        return self._tracking_quality

    @Property(int, notify=stabilityScoreChanged)
    def stabilityScore(self):
        return self._stability_score

    # ===== EXTENDED PROPERTIES =====
    @Property(int, notify=motionHorizontalChanged)
    def motionHorizontal(self):
        return self._motion_h

    @motionHorizontal.setter
    def motionHorizontal(self, v):
        v = max(5, min(100, int(v)))
        if self._motion_h != v:
            self._motion_h = v
            self.motionHorizontalChanged.emit()

    @Property(int, notify=motionVerticalChanged)
    def motionVertical(self):
        return self._motion_v

    @motionVertical.setter
    def motionVertical(self, v):
        v = max(5, min(100, int(v)))
        if self._motion_v != v:
            self._motion_v = v
            self.motionVerticalChanged.emit()

    @Property(int, notify=motionAccelerationChanged)
    def motionAcceleration(self):
        return self._motion_accel

    @motionAcceleration.setter
    def motionAcceleration(self, v):
        v = max(10, min(100, int(v)))
        if self._motion_accel != v:
            self._motion_accel = v
            self.motionAccelerationChanged.emit()

    @Property(int, notify=motionSmoothnessChanged)
    def motionSmoothness(self):
        return self._motion_smooth

    @motionSmoothness.setter
    def motionSmoothness(self, v):
        v = max(0, min(100, int(v)))
        if self._motion_smooth != v:
            self._motion_smooth = v
            self.motionSmoothnessChanged.emit()

    @Property(int, notify=motionThresholdChanged)
    def motionThreshold(self):
        return self._motion_thresh

    @motionThreshold.setter
    def motionThreshold(self, v):
        v = max(0, min(100, int(v)))
        if self._motion_thresh != v:
            self._motion_thresh = v
            self.motionThresholdChanged.emit()

    @Property(bool, notify=dwellClickEnabledChanged)
    def dwellClickEnabled(self):
        return self._dwell_click_enabled

    @dwellClickEnabled.setter
    def dwellClickEnabled(self, v):
        if self._dwell_click_enabled != v:
            self._dwell_click_enabled = v
            self.dwellClickEnabledChanged.emit()

    @Property(bool, notify=blinkLeftClickEnabledChanged)
    def blinkLeftClickEnabled(self):
        return self._blink_left

    @blinkLeftClickEnabled.setter
    def blinkLeftClickEnabled(self, v):
        if self._blink_left != v:
            self._blink_left = v
            self.blinkLeftClickEnabledChanged.emit()

    @Property(bool, notify=blinkRightClickEnabledChanged)
    def blinkRightClickEnabled(self):
        return self._blink_right

    @blinkRightClickEnabled.setter
    def blinkRightClickEnabled(self, v):
        if self._blink_right != v:
            self._blink_right = v
            self.blinkRightClickEnabledChanged.emit()

    @Property(bool, notify=clickSoundEnabledChanged)
    def clickSoundEnabled(self):
        return self._click_sound

    @clickSoundEnabled.setter
    def clickSoundEnabled(self, v):
        if self._click_sound != v:
            self._click_sound = v
            self.clickSoundEnabledChanged.emit()

    @Property(str, notify=clickHudStyleChanged)
    def clickHudStyle(self):
        return self._click_hud

    @clickHudStyle.setter
    def clickHudStyle(self, v):
        if v in ("normal", "slim") and self._click_hud != v:
            self._click_hud = v
            self.clickHudStyleChanged.emit()

    @Property(bool, notify=autoStartOnBootChanged)
    def autoStartOnBoot(self):
        return self._auto_start

    @autoStartOnBoot.setter
    def autoStartOnBoot(self, v):
        if self._auto_start != v:
            self._auto_start = v
            self.autoStartOnBootChanged.emit()

    @Property(str, notify=themeIdChanged)
    def themeId(self):
        return self._theme_id

    @themeId.setter
    def themeId(self, v):
        if v in ("cyber", "soft", "contrast") and self._theme_id != v:
            self._theme_id = v
            self.themeIdChanged.emit()

    @Property(bool, notify=darkModeChanged)
    def darkMode(self):
        return self._dark_mode

    @darkMode.setter
    def darkMode(self, v):
        if self._dark_mode != v:
            self._dark_mode = v
            self.darkModeChanged.emit()

    @Property(str, notify=appLanguageChanged)
    def appLanguage(self):
        return self._app_language

    @appLanguage.setter
    def appLanguage(self, v):
        if v in ("en", "ar") and v != self._app_language:
            self._app_language = v
            self.appLanguageChanged.emit()

    @Property(bool, notify=fabEnabledChanged)
    def fabEnabled(self):
        return self._fab_enabled

    @fabEnabled.setter
    def fabEnabled(self, v):
        if self._fab_enabled != v:
            self._fab_enabled = v
            self.fabEnabledChanged.emit()

    @Property(bool, notify=mainUIVisibleChanged)
    def mainUIVisible(self):
        return self._main_ui_visible

    @mainUIVisible.setter
    def mainUIVisible(self, v):
        if self._main_ui_visible != v:
            self._main_ui_visible = v
            self.mainUIVisibleChanged.emit()

    @Property("QVariantList", notify=floatingActionsModelChanged)
    def floatingActionsModel(self):
        return [{"id": k, "enabled": self._floating.get(k, True)} for k in FLOAT_IDS]

    # ===== SLOTS =====
    @Slot(str)
    def addKeyboardChar(self, char):
        self._keyboard_text += char
        self.keyboardTextChanged.emit()

    @Slot()
    def clearKeyboard(self):
        self._keyboard_text = ""
        self.keyboardTextChanged.emit()

    @Slot()
    def backspaceKeyboard(self):
        self._keyboard_text = self._keyboard_text[:-1]
        self.keyboardTextChanged.emit()

    @Slot(str, str)
    def notify(self, message, type="info"):
        self._notifications.append({"message": message, "type": type})
        self.notificationsUpdated.emit()
        QTimer.singleShot(4500, self.remove_oldest_notification)

    def remove_oldest_notification(self):
        if self._notifications:
            self._notifications.pop(0)
            self.notificationsUpdated.emit()

    @Slot(QImage)
    def on_image_ready(self, image):
        self._last_frame_mono = time.monotonic()
        if not self._camera_connected:
            self._camera_connected = True
            self.cameraConnectedChanged.emit()
        self._camera_provider.update_image(image)
        self.cameraFrameUpdated.emit()

    @Slot(str)
    def triggerAction(self, action):
        """Standard portal for all UI-triggered actions."""
        # Screen switching
        screens = ("dashboard", "tracking", "keyboard", "settings", "info")
        if action in screens:
            self.screen = action
            return

        # Direct actions
        if action == "click":
            self.notify(self.tr("notif_click_fired"), "info")
        elif action == "doubleclick":
            self.notify(self.tr("notif_doubleclick_fired"), "info")
        elif action == "left_click":
            self.notify(self.tr("notif_left_click_fired"), "info")
        elif action == "right_click":
            self.notify(self.tr("notif_right_click_fired"), "info")
        elif action == "drag":
            self.notify(self.tr("notif_drag_mode_on"), "info")
        elif action == "drop":
            self.notify(self.tr("notif_drop_fired"), "success")
        elif action == "magnifier":
            # This is handled in QML mostly, but we can log it
            pass
        elif action == "screenshot_image":
            self.notify(self.tr("notif_screenshot_captured"), "success")
        elif action == "screenshot_video":
            self.notify(self.tr("notif_video_recording_started"), "info")
        elif action == "scroll_up":
            self.notify(self.tr("notif_scroll_up"), "info")
        elif action == "scroll_down":
            self.notify(self.tr("notif_scroll_down"), "info")
        elif action == "scroll_left":
            self.notify(self.tr("notif_scroll_left"), "info")
        elif action == "scroll_right":
            self.notify(self.tr("notif_scroll_right"), "info")
        else:
            self.notify(f"Action '{action}' triggered", "info")

    def tr(self, key):
        """Helper to get translation from I18n class instance."""
        # In a real app we'd access the global i18n instance or pass it
        # Here we rely on the notify mapping being handled or simple fallback
        return key  # QML will handle the actual tr() call usually, we pass the key or msg

    @Slot()
    def toggleTrackingPause(self):
        self.trackingPaused = not self._tracking_paused

    # ---- Calibration ----
    def _advance_calibration(self, step: int) -> None:
        if step > 5:
            self._complete_calibration()
            return
        self._calibration_step = step
        self._calibration_progress = min(100, int(100 * step / 6))
        self.calibrationStepChanged.emit()
        self.calibrationProgressChanged.emit()
        QTimer.singleShot(520, lambda: self._advance_calibration(step + 1))

    def _complete_calibration(self) -> None:
        self._calibration_active = False
        self._calibration_progress = 100
        self._calibration_step = 6
        self._tracking_quality = min(98, self._tracking_quality + 24)
        self._stability_score = min(97, self._stability_score + 20)
        self.calibrationActiveChanged.emit()
        self.calibrationProgressChanged.emit()
        self.calibrationStepChanged.emit()
        self.trackingQualityChanged.emit()
        self.stabilityScoreChanged.emit()
        self.calibrationFinished.emit()

    @Slot()
    def startCalibration(self):
        if self._calibration_active:
            return
        self._calibration_active = True
        self._calibration_progress = 0
        self._calibration_step = 0
        self.calibrationActiveChanged.emit()
        self.calibrationProgressChanged.emit()
        self.calibrationStepChanged.emit()
        self._advance_calibration(0)

    @Slot()
    def cancelCalibration(self):
        if not self._calibration_active:
            return
        self._calibration_active = False
        self._calibration_progress = 0
        self._calibration_step = 0
        self.calibrationActiveChanged.emit()
        self.calibrationProgressChanged.emit()
        self.calibrationStepChanged.emit()

    # ---- Settings group operations ----
    @Slot(str)
    def beginSettingsEdit(self, group):
        """Snapshot current values so cancel can revert."""
        self._snapshot = {
            "motion_h": self._motion_h, "motion_v": self._motion_v,
            "motion_accel": self._motion_accel, "motion_smooth": self._motion_smooth,
            "motion_thresh": self._motion_thresh,
            "dwell_click_enabled": self._dwell_click_enabled,
            "dwell_time_ms": self._dwell_time_ms,
            "blink_left": self._blink_left, "blink_right": self._blink_right,
            "click_sound": self._click_sound, "click_hud": self._click_hud,
            "auto_start": self._auto_start, "theme_id": self._theme_id,
            "dark_mode": self._dark_mode, "high_contrast": self._high_contrast,
            "reduce_motion": self._reduce_motion, "font_scale": self._font_scale,
            "floating": dict(self._floating),
            "fab_enabled": self._fab_enabled,
        }

    @Slot(str)
    def saveSettingsGroup(self, group):
        self._save()

    @Slot(str)
    def cancelSettingsGroup(self, group):
        s = self._snapshot
        if not s:
            return
        self.motionHorizontal = s.get("motion_h", self._motion_h)
        self.motionVertical = s.get("motion_v", self._motion_v)
        self.motionAcceleration = s.get("motion_accel", self._motion_accel)
        self.motionSmoothness = s.get("motion_smooth", self._motion_smooth)
        self.motionThreshold = s.get("motion_thresh", self._motion_thresh)
        self.dwellClickEnabled = s.get("dwell_click_enabled", self._dwell_click_enabled)
        self.dwellTimeMs = s.get("dwell_time_ms", self._dwell_time_ms)
        self.blinkLeftClickEnabled = s.get("blink_left", self._blink_left)
        self.blinkRightClickEnabled = s.get("blink_right", self._blink_right)
        self.clickSoundEnabled = s.get("click_sound", self._click_sound)
        self.clickHudStyle = s.get("click_hud", self._click_hud)
        self.autoStartOnBoot = s.get("auto_start", self._auto_start)
        self.themeId = s.get("theme_id", self._theme_id)
        self.darkMode = s.get("dark_mode", self._dark_mode)
        self.highContrast = s.get("high_contrast", self._high_contrast)
        self.reduceMotion = s.get("reduce_motion", self._reduce_motion)
        self.fontScale = s.get("font_scale", self._font_scale)
        old_fl = s.get("floating", {})
        for k in FLOAT_IDS:
            self._floating[k] = old_fl.get(k, True)
        self.floatingActionsModelChanged.emit()
        self.fabEnabled = s.get("fab_enabled", self._fab_enabled)

    @Slot(str)
    def resetSettingsGroupDefaults(self, group):
        if group == "motion":
            self.motionHorizontal = DEFAULTS["motion_h"]
            self.motionVertical = DEFAULTS["motion_v"]
            self.motionAcceleration = DEFAULTS["motion_accel"]
            self.motionSmoothness = DEFAULTS["motion_smooth"]
            self.motionThreshold = DEFAULTS["motion_thresh"]
        elif group == "click":
            self.dwellClickEnabled = DEFAULTS["dwell_click_enabled"]
            self.dwellTimeMs = DEFAULTS["dwell_time_ms"]
            self.blinkLeftClickEnabled = DEFAULTS["blink_left_click"]
            self.blinkRightClickEnabled = DEFAULTS["blink_right_click"]
            self.clickSoundEnabled = DEFAULTS["click_sound"]
            self.clickHudStyle = DEFAULTS["click_hud"]
        elif group == "system":
            self.autoStartOnBoot = DEFAULTS["auto_start"]
        elif group == "appearance":
            self.themeId = DEFAULTS["theme_id"]
            self.darkMode = DEFAULTS["dark_mode"]
            self.highContrast = DEFAULTS["high_contrast"]
            self.reduceMotion = DEFAULTS["reduce_motion"]
            self.fontScale = DEFAULTS["font_scale"]
        elif group == "floating":
            for k in FLOAT_IDS:
                self._floating[k] = True
            self.fabEnabled = True
            self.floatingActionsModelChanged.emit()

    @Slot()
    def refreshWindowsIcons(self):
        pass  # placeholder for Windows desktop icon refresh

    @Slot(str, bool)
    def setFloatingActionEnabled(self, action_id, enabled):
        if action_id in self._floating:
            self._floating[action_id] = enabled
            self.floatingActionsModelChanged.emit()


def run():
    app = QGuiApplication(sys.argv)
    app.setFont(QFont("Segoe UI", 11))

    engine = QQmlApplicationEngine()
    camera_provider = CameraProvider()
    engine.addImageProvider("camera", camera_provider)

    logic = CyberStoneLogic(camera_provider)
    i18n = I18n()

    # Sync language from settings
    if logic.appLanguage == "ar":
        i18n.setLanguage("ar")

    engine.rootContext().setContextProperty("cyberLogic", logic)
    engine.rootContext().setContextProperty("i18n", i18n)
    engine.rootContext().setContextProperty("icons", assets.ICONS)

    camera_worker = CameraWorker()
    camera_worker.image_ready.connect(logic.on_image_ready)
    camera_worker.start()

    qml_file = os.path.join(os.path.dirname(__file__), "main.qml")
    engine.load(qml_file)

    if not engine.rootObjects():
        camera_worker.stop()
        sys.exit(-1)

    exit_code = app.exec()
    camera_worker.stop()
    sys.exit(exit_code)


if __name__ == "__main__":
    run()
