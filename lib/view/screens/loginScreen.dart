import 'dart:async';

import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/service/maplibre_service.dart';
import 'package:aplicacion_movil/view/components/medical_background.dart';
import 'package:aplicacion_movil/view/screens/mainScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class Loginscreen extends StatefulWidget {
  const Loginscreen({super.key});

  @override
  State<Loginscreen> createState() => _LoginscreenState();
}

class _LoginscreenState extends State<Loginscreen> {
  //region variables
  LangService langService = LangService();
  String _selectedLanguage = 'es';
  bool _showPassword = true;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _loading = false;
  String? _error;

  //endregion

  //region lifecicle
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    LangService.load(_selectedLanguage);
    _checkConnectivity();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      List<ConnectivityResult> result,
    ) {
      _checkConnectivity();
    });
  }
  //endregion

  //region widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Fondo con iconos médicos
            CustomPaint(
              size: Size(
                MediaQuery.of(context).size.width,
                MediaQuery.of(context).size.height,
              ),
              painter: MedicalBackgroundPainter(),
            ),
            // Contenido principal
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const SizedBox(height: 60),
                    // Logo
                    Image.asset(
                      'assets/images/logo.png',
                      height: 250,
                      width: 250,
                    ),
                    const SizedBox(height: 8),
                    // Selector de idioma
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          child: DropdownButton2<String>(
                            value: _selectedLanguage,
                            underline: const SizedBox(),
                            hint: Row(
                              children: [
                                Image.asset(
                                  'assets/images/flags/$_selectedLanguage.png',
                                  height: 20,
                                  width: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedLanguage.toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            items: LangService.supportedLanguages()
                                .map(
                                  (e) => DropdownMenuItem<String>(
                                    value: e,
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/images/flags/$e.png',
                                          height: 20,
                                          width: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          e.toUpperCase(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              _changeLanguage(value!);
                            },
                            buttonStyleData: const ButtonStyleData(
                              height: 40,
                              padding: EdgeInsets.symmetric(horizontal: 8),
                            ),
                            iconStyleData: const IconStyleData(
                              icon: Icon(Icons.arrow_drop_down),
                              iconSize: 24,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    // Campo correo electrónico
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.mail_outline,
                            color: Color(0xFF2196F3),
                          ),
                          hintText: LangService.text('email'),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Campo contraseña
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _showPassword,
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Color(0xFF2196F3),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: Colors.grey.shade500,
                            ),
                            onPressed: _togglePassword,
                          ),
                          hintText: LangService.text('password'),
                          hintStyle: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 18,
                            horizontal: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Mensaje de error
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Botón de Login
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A3A5C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          elevation: 4,
                          shadowColor: const Color(0xFF1A3A5C).withOpacity(0.4),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                LangService.text('login').toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  //endregion
  //region functions
  void _togglePassword() {
    setState(() {
      _showPassword = !_showPassword;
    });
  }

  void _checkConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    setState(() {
      // Check if ANY of the connectivity results are not 'none'
      // Recent versions of connectivity_plus return a List<ConnectivityResult>
      bool isConnected = result.any((r) => r != ConnectivityResult.none);

      if (!isConnected) {
        _error = LangService.text('no_internet'); // Optional: warning message
      } else {
        // Clear error if we regained connection (optional, depending on UX preference)
        if (_error == LangService.text('no_internet')) {
          _error = null;
        }
      }
    });
  }

  void _changeLanguage(String languageCode) {
    setState(() {
      _selectedLanguage = languageCode;
      LangService.load(languageCode);
    });
  }

  //endregion
  //region api calls
  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      bool isOnline = connectivityResult.any(
        (r) => r != ConnectivityResult.none,
      );

      final prefs = await SharedPreferences.getInstance();
      final inputEmail = _emailController.text.trim();
      final inputPassword = _passwordController.text.trim();

      if (isOnline) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: inputEmail,
          password: inputPassword,
        );

        await prefs.setString('email', inputEmail);
        await prefs.setString('password', inputPassword);
        await prefs.setBool('isLoggedIn', true);

        // 🚀 Iniciar precarga del mapa en segundo plano ANTES de navegar
        MapLibreService().initialize();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Mainscreen()),
          );
        }
      } else {
        String? storedEmail = prefs.getString('email');
        String? storedPassword = prefs.getString('password');
        bool? isLoggedIn = prefs.getBool('isLoggedIn');

        if (storedEmail != null &&
            storedPassword != null &&
            isLoggedIn == true) {
          if (inputEmail == storedEmail && inputPassword == storedPassword) {
            // 🚀 Iniciar precarga del mapa en segundo plano
            MapLibreService().initialize();

            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const Mainscreen()),
              );
            }
          } else {
            setState(() {
              _error = LangService.text('invalid_credentials_offline');
            });
          }
        } else {
          // No stored credentials found
          setState(() {
            _error = LangService.text('no_offline_login_data');
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  //endregion
}

