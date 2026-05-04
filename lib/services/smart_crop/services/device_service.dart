import 'dart:ui' as ui;
import 'dart:io' as io;
import 'dart:math' as math;
import 'package:dailywallpaper/services/smart_crop/utils/device_capability_detector.dart';

class DeviceService {
  DeviceCapability? _deviceCapability;

  Future<DeviceCapability> getDeviceCapability() async {
    _deviceCapability ??= await DeviceCapabilityDetector.getDeviceCapability();
    return _deviceCapability!;
  }

  bool isUnderMemoryPressure(ui.Image image, ui.Size targetSize) {
    final estimatedMemory = estimateMemoryUsage(image, targetSize);
    final memoryMB = estimatedMemory / (1024 * 1024);

    if (memoryMB > 150) return true; // Critical

    if (io.Platform.isAndroid || io.Platform.isIOS) {
      return memoryMB > 100;
    }
    return memoryMB > 200;
  }

  int estimateMemoryUsage(ui.Image image, ui.Size targetSize) {
    const bytesPerPixel = 4;
    final sourceMemory = image.width * image.height * bytesPerPixel;
    final targetMemory =
        targetSize.width.round() * targetSize.height.round() * bytesPerPixel;
    final analysisMemory = (sourceMemory / 4) * 3;
    final canvasMemory = math.max(sourceMemory, targetMemory);

    return sourceMemory + targetMemory + analysisMemory.round() + canvasMemory;
  }

  void clearCache() {
    _deviceCapability = null;
    DeviceCapabilityDetector.clearCache();
  }
}
