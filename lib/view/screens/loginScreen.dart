import 'dart:async';

import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/service/map_service.dart';
import 'package:aplicacion_movil/view/screens/mainScreen.dart';
import 'package:aplicacion_movil/view/components/appbar.dart';
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
      appBar: buildAppBar(context, showHomeAction: false),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF7DBCF7), // azul claro
                Color(0xFF4292CC), // azul medio
              ],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 24, left: 24, top: 80),
            child: Column(
              children: [
                // Logo
                Image.asset('assets/images/logo.png', height: 200, width: 200),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Spacer(),
                    //mostrar dropdown de idiomas junto a una foto de la bandera
                    DropdownButton2(
                      items: LangService.supportedLanguages()
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Row(
                                children: [
                                  Image.asset(
                                    'assets/images/flags/$e.png',
                                    height: 20,
                                    width: 20,
                                  ),
                                  Text(e),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        _changeLanguage(value!);
                      },
                    ),
                  ],
                ),
                // Campo correo electrónico
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.person, color: Colors.grey),
                    hintText: LangService.text('email'),
                    hintStyle: const TextStyle(color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Campo contraseña
                TextField(
                  controller: _passwordController,
                  obscureText: _showPassword,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.lock, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: _togglePassword,
                    ),
                    hintText: LangService.text('password'),
                    hintStyle: const TextStyle(color: Colors.black54),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Botón de Login
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A73E8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 3,
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            LangService.text('login'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
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
        MapService().initialize();

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
            MapService().initialize();

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
