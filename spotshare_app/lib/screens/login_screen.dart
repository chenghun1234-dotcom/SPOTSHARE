import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/error_handler.dart';
import 'map_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isLoginMode = true;

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
        await _authService.signUpWithEmail(_email, _password, _name, _carNumber);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MapScreen()),
        );
      }
    } catch (e) {
      ErrorHandler.showError('${_isLoginMode ? '로그인' : '회원가입'} 실패:\n$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.share_location_rounded, size: 80, color: Colors.white),
                      const SizedBox(height: 16),
                      const Text(
                        'SpotShare',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 40),

                      if (!_isLoginMode)
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '이름(닉네임)',
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                            prefixIcon: const Icon(Icons.person, color: Colors.white70),
                          ),
                          validator: (val) => val == null || val.isEmpty ? '이름을 입력하세요' : null,
                          onSaved: (val) => _name = val!.trim(),
                        ),
                      if (!_isLoginMode) const SizedBox(height: 16),

                      if (!_isLoginMode)
                        TextFormField(
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: '차량 번호 (예: 12가 3456)',
                            labelStyle: const TextStyle(color: Colors.white70),
                            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                            prefixIcon: const Icon(Icons.directions_car, color: Colors.white70),
                          ),
                          validator: (val) => val == null || val.isEmpty ? '차량 번호(등록 번호)를 입력하세요' : null,
                          onSaved: (val) => _carNumber = val!.trim(),
                        ),
                      if (!_isLoginMode) const SizedBox(height: 16),

                      TextFormField(
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '이메일 주소',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          prefixIcon: const Icon(Icons.email, color: Colors.white70),
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
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: '비밀번호',
                          labelStyle: const TextStyle(color: Colors.white70),
                          enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return '비밀번호를 입력하세요';
                          if (val.length < 6) return '비밀번호는 6자리 이상이어야 합니다';
                          return null;
                        },
                        onSaved: (val) => _password = val!.trim(),
                      ),
                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _isLoading 
                            ? const SizedBox(
                                width: 24, height: 24, 
                                child: CircularProgressIndicator(strokeWidth: 2)
                              )
                            : Text(
                                _isLoginMode ? '로그인' : '회원가입',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextButton(
                        onPressed: _toggleMode,
                        child: Text(
                          _isLoginMode ? '계정이 없으신가요? 회원가입' : '이미 계정이 있으신가요? 로그인',
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
