import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const CustomAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRootRoute = ModalRoute.of(context)?.isFirst ?? true;

    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        boxShadow: [BoxShadow(color: theme.shadowColor.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          if (!isRootRoute)
            IconButton(icon: Icon(Icons.arrow_back, color: theme.colorScheme.onPrimary), onPressed: () => Navigator.of(context).maybePop(), tooltip: 'Back')
          else
            const SizedBox(width: 8),

          // Title
          Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold)),

          const Spacer(),

          // Themed actions
          if (actions != null) ...actions!.map((widget) => IconTheme(data: IconThemeData(color: theme.colorScheme.onPrimary), child: widget)),
        ],
      ),
    );
  }
}
