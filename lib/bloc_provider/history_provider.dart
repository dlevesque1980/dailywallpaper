import 'package:dailywallpaper/bloc/history_bloc.dart';
import 'package:flutter/widgets.dart';

class HistoryProvider extends InheritedWidget {
  final HistoryBloc historyBloc;
  HistoryProvider(
      {Key? key, required HistoryBloc historyBloc, required Widget child})
      : this.historyBloc = historyBloc,
        super(child: child, key: key);

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => true;

  static HistoryBloc of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<HistoryProvider>())!
          .historyBloc;
}
