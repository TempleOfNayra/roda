import 'package:flutter/cupertino.dart';

/// Simple wrapper that adds SafeArea to all CupertinoPageScaffolds
class SafeScaffold extends StatelessWidget {
  final ObstructingPreferredSizeWidget? navigationBar;
  final Widget body;
  final Color? backgroundColor;
  
  const SafeScaffold({
    super.key,
    this.navigationBar,
    required this.body,
    this.backgroundColor,
  });
  
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: navigationBar,
      backgroundColor: backgroundColor,
      child: SafeArea(
        top: navigationBar == null,
        child: body,
      ),
    );
  }
}