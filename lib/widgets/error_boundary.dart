import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class ErrorBoundary extends StatefulWidget {
  final Widget child;

  const ErrorBoundary({super.key, required this.child});

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  @override
  void initState() {
    super.initState();
    // This is a simplified boundary. Flutter mostly handles errors at widget tree level via ErrorWidget.builder.
    // For a true boundary, we rely on ErrorWidget.builder globally, or use runZonedGuarded.
    // But specific widget-level boundaries are tricky in Flutter without external packages.
    // We'll define a custom ErrorWidget builder here to be used by the app.
  }

  @override
  Widget build(BuildContext context) {
    // If we could catch build errors here we would.
    // Instead, this widget acts as a provider of error UI style or a localized trap if we used a FutureBuilder/StreamBuilder that failed.
    // Since we can't easily trap render errors in a parent widget in Flutter, 
    // we will return the child. The global error builder should be set in main.dart.
    return widget.child;
  }
}

// Global error builder to replace the "Red Screen of Death"
Widget errorWidgetBuilder(FlutterErrorDetails details) {
  return Material(
    color: AppColors.background,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Rendering Error',
              style: GoogleFonts.inter(fontSize: 18, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              details.exception.toString(),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: AppColors.textDim),
            ),
          ],
        ),
      ),
    ),
  );
}
