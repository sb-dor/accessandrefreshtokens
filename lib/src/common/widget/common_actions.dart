import 'dart:collection';

import 'package:accessandrefreshtoken/src/common/widget/history_button.dart';
import 'package:accessandrefreshtoken/src/features/account/widget/profile_icon_button.dart';
import 'package:accessandrefreshtoken/src/features/authentication/widget/log_out_button.dart';
import 'package:accessandrefreshtoken/src/features/developer/widget/developer_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class CommonActions extends ListBase<Widget> {
  CommonActions([List<Widget>? actions])
    : _actions = <Widget>[
        ...?actions,
        if (!kReleaseMode) const DeveloperButton(),
        const HistoryButton(),
        const ProfileIconButton(),
        const LogOutButton(),
      ];

  final List<Widget> _actions;

  @override
  int get length => _actions.length;

  @override
  set length(int newLength) => _actions.length = newLength;

  @override
  Widget operator [](int index) => _actions[index];

  @override
  void operator []=(int index, Widget value) => _actions[index] = value;
}
