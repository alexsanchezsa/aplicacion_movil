import 'package:aplicacion_movil/view/screens/Settings_Screen.dart';
import 'package:flutter/material.dart';
import 'package:aplicacion_movil/view/screens/mainScreen.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context, {
  bool showHomeAction = true,
}) {
  return AppBar(
    toolbarHeight: 70, // Altura cómoda
    automaticallyImplyLeading: false,
    titleSpacing: 0,
    centerTitle: false,
    backgroundColor: const Color(0xFF2DA8E2),
    foregroundColor: Colors.white,
    elevation: 0,

    // Aquí está la magia para tu imagen específica
    title: Container(
      height: 70, // Debe coincidir con toolbarHeight
      // Limitamos el ancho para que no choque con los iconos
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 250),
      padding: const EdgeInsets.only(left: 5, right: 20),
      child: ClipRect(
        // Asegura que lo que sobra no se pinte fuera
        child: Image.asset(
          'assets/images/Logo_AppBar.png',
          // 'cover' hará zoom hasta llenar el ancho, cortando lo que sobra arriba/abajo
          fit: BoxFit.contain,
          // Asegura que el zoom se centre en el medio (donde está tu logo)
          alignment: Alignment.center,
        ),
      ),
    ),

    actions: [
      IconButton(
        iconSize: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsScreen()),
          );
        },
        icon: const Icon(Icons.supervised_user_circle_outlined),
      ),
      if (showHomeAction)
        IconButton(
          iconSize: 32,
          padding: const EdgeInsets.only(left: 8, right: 16),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Mainscreen()),
            );
          },
          icon: const Icon(Icons.home),
        ),
    ],
  );
}
