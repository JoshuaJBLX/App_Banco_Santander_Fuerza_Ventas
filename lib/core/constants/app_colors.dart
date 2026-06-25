import 'package:flutter/material.dart';

/// Paleta de marca - Banco Santander Consumer Perú (rojo puro y blanco).
class AppColors {
  AppColors._();

  // Marca principal
  static const Color primary = Color(0xFFFF0000); // rojo puro #FF0000
  static const Color primaryDark = Color(0xFFCC0000);
  static const Color primaryLight = Color(0xFFFF4D4D);
  static const Color secondary = Color(0xFFFF0000);
  static const Color accent = Color(0xFFFF0000);

  // Logo - rojo y blanco
  static const Color logoMagenta = Color(0xFFFF0000);
  static const Color logoRojo = Color(0xFFFF0000);
  static const Color logoNaranja = Color(0xFFE60000);
  static const Color logoAmarillo = Color(0xFFFFCCCC);
  static const Color logoVerde = Color(0xFFFF6666);
  static const Color logoRosa = Color(0xFFFF9999);

  /// Degradado rojo (oscuro -> puro). Texto sobre el degradado: blanco.
  static const List<Color> brandGradient = [
    Color(0xFFCC0000),
    Color(0xFFFF0000),
  ];

  // Superficies
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Colors.white;
  static const Color visitedTile = Color(0xFFFFE5E5);

  // Texto
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF757575);
  static const Color onPrimary = Colors.white;

  // Estados / semaforo (escala de rojos sobre fondo blanco)
  static const Color success = Color(0xFFCC0000);
  static const Color warning = Color(0xFFFF3333);
  static const Color danger = Color(0xFFFF0000);
  static const Color info = Color(0xFFB30000);
  static const Color neutral = Color(0xFF9E9E9E);

  // Tipos de gestion - variaciones de rojo
  static const Color renovacion = Color(0xFFFF0000);
  static const Color ampliacion = Color(0xFFCC0000);
  static const Color nuevaSolicitud = Color(0xFFE60000);
  static const Color seguimiento = Color(0xFF999999);
  static const Color recuperacionMora = Color(0xFFB30000);
  static const Color desertor = Color(0xFF990000);

  // Prioridad
  static const Color prioridadAlta = Color(0xFFFF0000);
  static const Color prioridadMedia = Color(0xFFFF6666);
  static const Color prioridadNormal = Color(0xFFBDBDBD);
}
