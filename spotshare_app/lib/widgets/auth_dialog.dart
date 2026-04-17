import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/error_handler.dart';

class AuthDialog extends StatefulWidget {
  const AuthDialog({super.key});

  @override
  State<AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<AuthDialog> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isLoginMode = true;
  String _role = 'driver'; // 'driver' or 'host'

  String _email = '';
  String _password = '';
  String _name = '';
  String _carNumber = '';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await _authService.signInWithEmail(_email, _password);
      } else {
        await _authService.signUpWithEmail(_email, _password, _name, _role, carNumber: _role == 'driver' ? _carNumber : null);
      }
      if (mounted) {
        Navigator.of(context).pop(true); // Return true on success
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError('${_isLoginMode ? '로그인' : '회원가입'} 실패:\n$e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLoginMode ? Icons.login : Icons.person_add,
                  size: 48,
                  color: Colors.blueAccent,
                ),
                const SizedBox(height: 16),
                Text(
                  _isLoginMode ? '로그인' : '회원가입',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),

                if (!_isLoginMode) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Radio<String>(
                        value: 'driver',
                        groupValue: _role,
                        onChanged: (val) => setState(() => _role = val!),
                      ),
                      const Text('운전자'),
                      const SizedBox(width: 16),
                      Radio<String>(
                        value: 'host',
                        groupValue: _role,
                        onChanged: (val) => setState(() => _role = val!),
                      ),
                      const Text('주차장 호스트'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    decoration: const InputDecoration(
                      labelText: '이름(닉네임)',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty ? '이름을 입력하세요' : null,
                    onSaved: (val) => _name = val!.trim(),
                  ),
                  const SizedBox(height: 16),
                  if (_role == 'driver') ...[
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '차량 번호 (예: 12가 3456)',
                        prefixIcon: Icon(Icons.directions_car),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) => val == null || val.isEmpty ? '차량 번호를 입력하세요' : null,
                      onSaved: (val) => _carNumber = val!.trim(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],

                TextFormField(
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: '이메일 주소',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return '이메일을 입력하세요';
                    if (!val.contains('@')) return '유효한 이메일 형식이 아닙니다';
                    return null;
                  },
                  onSaved: (val) => _email = val!.trim(),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) return '비밀번호를 입력하세요';
                    if (val.length < 6) return '비밀번호는 6자리 이상이어야 합니다';
                    return null;
                  },
                  onSaved: (val) => _password = val!.trim(),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isLoginMode ? '로그인' : '회원가입 완료',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoginMode = !_isLoginMode;
                    });
                  },
                  child: Text(
                    _isLoginMode ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                    style: const TextStyle(color: Colors.blueGrey),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
