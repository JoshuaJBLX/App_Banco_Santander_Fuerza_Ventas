import '../../../core/network/api_client.dart';
import '../domain/asesor_model.dart';

/// Resultado del login: token + asesor.
class LoginResult {
  final String token;
  final AsesorModel asesor;
  const LoginResult(this.token, this.asesor);
}

/// Fuente remota de autenticacion contra el backend FastAPI (POST /auth/login).
class AuthRemoteDataSource {
  final ApiClient _api;
  AuthRemoteDataSource(this._api);

  Future<LoginResult> login({
    required String codigoEmpleado,
    required String password,
  }) async {
    final data = await _api.post('/auth/login', {
      'codigo_empleado': codigoEmpleado,
      'password': password,
    });
    final token = data['access_token'] as String;
    final asesor = AsesorModel.fromJson(data['asesor'] as Map<String, dynamic>);
    _api.setToken(token);
    return LoginResult(token, asesor);
  }
}
