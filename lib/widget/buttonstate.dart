import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../bloc/home_bloc.dart';

bool isAnimating = true;
//enum to declare 3 state of buttonenum ButtonState { init, submitting, completed }
enum ButtonState { init, submitting, completed }

class ButtonStates extends StatefulWidget {
  const ButtonStates(
      {Key key, @required this.onPressed, @required this.homeBloc})
      : super(key: key);
  final void Function() onPressed;
  final HomeBloc homeBloc;

  @override
  _ButtonStatesState createState() => _ButtonStatesState();
}

class _ButtonStatesState extends State<ButtonStates> {
  ButtonState state = ButtonState.init;

  @override
  void didChangeDependencies() {
    final message = this.widget.homeBloc.wallpaper;
    message.listen((value) async {
      setState(() {
        state = ButtonState.completed;
      });
      Fluttertoast.showToast(
          msg: value,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM);
      await Future.delayed(Duration(seconds: 2));
      setState(() {
        state = ButtonState.init;
      });
    });
    super.didChangeDependencies();
  }

  @override
  Widget build(BuildContext context) {
    final buttonWidth = MediaQuery.of(context).size.width;

    // update the UI depending on below variable values
    final isInit = state == ButtonState.init;
    final isDone = state == ButtonState.completed;

    return AnimatedContainer(
        duration: Duration(milliseconds: 300),
        width: 70,
        height: 60,
        alignment: Alignment.bottomRight,
        // If Button State is Submiting or Completed  show 'buttonCircular' widget as below
        child: isInit
            ? SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: buildButton())
            : SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: circularContainer(isDone)));
  }

  // If Button State is init : show Normal submit button
  Widget buildButton() => Container(
        child: FloatingActionButton(
          elevation: 0.0,
          child: new Icon(Icons.wallpaper),
          backgroundColor: Colors.lightBlue,
          onPressed: () async {
            setState(() {
              state = ButtonState.submitting;
            });
            await Future.delayed(Duration(milliseconds: 300));

            this.widget.onPressed();
          },
        ),
      );

  // this is custom Widget to show rounded container
  // here is state is submitting, we are showing loading indicator on container then.
  // if it completed then showing a Icon.

  Widget circularContainer(bool done) {
    final color = done ? Colors.green : Colors.blue;
    return Container(
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
