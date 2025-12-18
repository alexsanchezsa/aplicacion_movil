import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/service/map_service.dart';
import 'package:aplicacion_movil/view/screens/MapSample.dart';
import 'package:aplicacion_movil/view/screens/map_download_screen.dart';
import 'package:aplicacion_movil/view/screens/resumenTriaje.dart';
import 'package:aplicacion_movil/view/screens/triajeMedicoScreen.dart';
import 'package:aplicacion_movil/view/components/MainButton.dart';
import 'package:flutter/material.dart';
import 'package:aplicacion_movil/view/components/appbar.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class Mainscreen extends StatelessWidget {
  const Mainscreen({super.key});
  //region widget
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, showHomeAction: false),

      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7DBCF7), Color(0xFF4292CC)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo principal
                Image.asset('assets/images/logo.png', height: 160, width: 160),
                const SizedBox(height: 30),

                // 🔵 Botón: Vista en tiempo real drones
                MainButton(
                  icon: MdiIcons.drone,
                  text: LangService.text('drone_view'),
                  onTap: () {
                    // TODO: Implementar función o navegación
                  },
                ),
                const SizedBox(height: 16),

                //  Botón: Mapa desaparecidos
                MainButton(
                  svgAsset: 'assets/images/icon_location_pin.svg',
                  text: LangService.text('missing_map'),
                  onTap: () {
                    // Verificar si el mapa necesita descarga
                    final mapService = MapService();
                    if (mapService.needsMapDownload) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapDownloadScreen(
                            onDownloadComplete: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MapSample(),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapSample(),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Triaje médico
                MainButton(
                  svgAsset: 'assets/images/usuario_medico.svg',
                  text: LangService.text('medical_triage'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TriajeMedicoScreeen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Resumen Triaje médico
                MainButton(
                  svgAsset: 'assets/images/icon_clipboard_green.svg',
                  text: LangService.text('triage_summary'),
                  textColor: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const Resumentriaje(),
                      ),
                    );
                  },
                ),
                MainButton(
                  icon: Icons.map,
                  text: LangService.text('download_map'),
                  onTap: () {
                    // TODO: Implementar función o navegación
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //endregion
}
