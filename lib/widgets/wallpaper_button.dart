import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

enum ButtonState { init, submitting, completed }

/// Generic wallpaper button widget that can work with any bloc that has a wallpaper stream
class WallpaperButton extends StatefulWidget {
  const WallpaperButton({
    Key? key,
    required this.onPressed,
    required this.wallpaperStream,
  }) : super(key: key);

  final void Function() onPressed;
  final Stream<String> wallpaperStream;

  @override
  _WallpaperButtonState createState() => _WallpaperButtonState();
}

class _WallpaperButtonState extends State<WallpaperButton> {
  ButtonState state = ButtonState.init;

  @override
  void didChangeDependencies() {
    widget.wallpaperStream.listen((value) async {
      setState(() {
        state = ButtonState.completed;
      });
      Fluttertoast.showToast(
        msg: value,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        state = ButtonState.init;
      });
    });
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    // update the UI depending on below variable values
    final isInit = state == ButtonState.init;
    final isDone = state == ButtonState.completed;

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: 70,
      height: 60,
      alignment: Alignment.bottomRight,
      // If Button State is Submiting or Completed show 'buttonCircular' widget as below
      child: isInit
          ? SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: buildButton(),
            )
          : SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: circularContainer(isDone),
            ),
    );
  }

  // If Button State is init : show Normal submit button
  Widget buildButton() => Container(
        child: FloatingActionButton(
          elevation: 0.0,
          child: Icon(Icons.wallpaper),
          backgroundColor: Colors.lightBlue,
          onPressed: () async {
            setState(() {
              state = ButtonState.submitting;
            });
            await Future.delayed(Duration(milliseconds: 300));
            widget.onPressed();
          },
        ),
      );

  // this is custom Widget to show rounded container
  // here is state is submitting, we are showing loading indicator on container then.
  // if it completed then showing a Icon.
  Widget circularContainer(bool done) {
    final color = done ? Colors.green : Colors.blue;
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: Center(
        child: done
            ? const Icon(Icons.done, size: 50, color: Colors.white)
            : const CircularProgressIndicator(
                color: Colors.white,
              ),
      ),
    );
  }
}
