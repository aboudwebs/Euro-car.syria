// The top bar of screens that are opened on top of the tabs (part details, special request, registration): the
// web app's glass bar - a translucent fill with a hairline underneath. Put the screen inside an AppBackdrop and make
// its Scaffold transparent so the glass sits on the page background.

import 'package:flutter/material.dart';

import '../theme/palette.dart';

PreferredSizeWidget buildScreenBar(
  BuildContext context,
  String title, {
  List<Widget> actions = const <Widget>[],
}) {
  final Palette p = Palette.of(context);
  return AppBar(
    title: Text(
      title,
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 19, color: p.text),
    ),
    backgroundColor: p.barBg,
    foregroundColor: p.text,
    surfaceTintColor: Colors.transparent,
    scrolledUnderElevation: 0,
    elevation: 0,
    shape: Border(bottom: BorderSide(color: p.barLine)),
    centerTitle: false,
    actions: actions,
  );
}
