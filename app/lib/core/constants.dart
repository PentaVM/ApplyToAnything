class AppConstants {
  AppConstants._();

  /// URL del backend. 10.0.2.2 = localhost del PC desde el emulador Android.
  /// En dispositivo físico usa la IP LAN de tu PC, ej. http://192.168.1.10:8000
  static const String defaultBackendUrl = 'http://10.0.2.2:8000';

  /// OmniRoute por defecto (gateway de IA gratuito que corre en tu PC).
  static const String defaultOmniBase = 'http://localhost:20128/v1';
  static const String defaultOmniModel = 'glm/glm-4.7';

  static const List<Map<String, String>> countries = [
    {'code': 'xx', 'name': 'Remoto (Global)'},
    {'code': 'ar', 'name': 'Argentina'},
    {'code': 'au', 'name': 'Australia'},
    {'code': 'bo', 'name': 'Bolivia'},
    {'code': 'br', 'name': 'Brasil'},
    {'code': 'ca', 'name': 'Canadá'},
    {'code': 'cl', 'name': 'Chile'},
    {'code': 'co', 'name': 'Colombia'},
    {'code': 'cr', 'name': 'Costa Rica'},
    {'code': 'de', 'name': 'Alemania'},
    {'code': 'do', 'name': 'Rep. Dominicana'},
    {'code': 'ec', 'name': 'Ecuador'},
    {'code': 'es', 'name': 'España'},
    {'code': 'fr', 'name': 'Francia'},
    {'code': 'gb', 'name': 'Reino Unido'},
    {'code': 'gt', 'name': 'Guatemala'},
    {'code': 'ie', 'name': 'Irlanda'},
    {'code': 'in', 'name': 'India'},
    {'code': 'it', 'name': 'Italia'},
    {'code': 'mx', 'name': 'México'},
    {'code': 'nl', 'name': 'Países Bajos'},
    {'code': 'pe', 'name': 'Perú'},
    {'code': 'pl', 'name': 'Polonia'},
    {'code': 'pt', 'name': 'Portugal'},
    {'code': 'py', 'name': 'Paraguay'},
    {'code': 'sv', 'name': 'El Salvador'},
    {'code': 'uy', 'name': 'Uruguay'},
    {'code': 'us', 'name': 'Estados Unidos'},
    {'code': 've', 'name': 'Venezuela'},
    {'code': 'za', 'name': 'Sudáfrica'},
  ];

  static const List<String> modalities = [
    'Cualquiera', 'Remoto', 'Presencial', 'Híbrido',
  ];

  static const List<String> seniorities = [
    'Sin experiencia', 'Junior', 'Semi-senior', 'Senior', 'Lead / Manager',
  ];

  static const List<String> currencies = [
    'USD', 'EUR', 'MXN', 'COP', 'ARS', 'CLP', 'PEN', 'BRL', 'GBP', 'CAD',
  ];

  static String countryName(String code) {
    for (final c in countries) {
      if (c['code'] == code) return c['name']!;
    }
    return code.toUpperCase();
  }
}
