import 'dart:ui' as ui;
import 'dart:typed_data';

class FakeImage implements ui.Image {
  @override
  final int width;
  @override
  final int height;

  FakeImage({required this.width, required this.height});

  @override
  void dispose() {}

  @override
  bool get debugDisposed => false;

  @override
  ui.Image clone() => this;

  @override
  bool isCloneOf(ui.Image other) => other == this;

  @override
  List<StackTrace>? get debugStackTraces => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  
  @override
  Future<ByteData?> toByteData({ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) async => null;
}
