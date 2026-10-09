import 'package:flutter/widgets.dart';

import 'admin_store.dart';

/// Makes the AdminStore available to Admin pages (rebuild on change).
class AdminScope extends InheritedNotifier<AdminStore> {
  const AdminScope({super.key, required super.notifier, required super.child});

  static AdminStore of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AdminScope>()!.notifier!;

  static AdminStore read(BuildContext context) => context.getInheritedWidgetOfExactType<AdminScope>()!.notifier!;
}
