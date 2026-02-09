import 'package:flutter/material.dart';
import 'package:aplicacion_movil/view/screens/mainScreen.dart';

PreferredSizeWidget buildAppBar(
  BuildContext context, {
  bool showHomeAction = true,
}) {
  return AppBar(
    leadingWidth: 80,
    leading: const Padding(
      padding: EdgeInsets.only(left: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.shield), Icon(Icons.favorite)],
      ),
    ),
    title: Image.asset('assets/images/Logo_AppBar.png'),
    centerTitle: true,

    backgroundColor: const Color(0xFF2DA8E2),
    foregroundColor: Colors.white,
    elevation: 0,
    actions: [
      if (showHomeAction)
        IconButton(
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

