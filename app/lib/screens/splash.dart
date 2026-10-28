import 'package:flutter/material.dart';

import '../core/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.card1, AppTheme.bg, AppTheme.card2],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.style_rounded, size: 84, color: AppTheme.accent),
              SizedBox(height: 18),
              Text(
                'ApplyToAnything',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 6),
              Text(
                'Desliza. Postula. Trabaja.',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
              SizedBox(height: 28),
              SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppTheme.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
