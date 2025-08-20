import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/core/theme/roda_colors.dart';

class CleanMapPage extends ConsumerWidget {
  const CleanMapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Map'),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.map,
              size: 64,
              color: RodaColors.systemGrey,
            ),
            SizedBox(height: 16),
            Text(
              'Map Coming Soon',
              style: TextStyle(
                fontSize: 18,
                color: RodaColors.systemGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}