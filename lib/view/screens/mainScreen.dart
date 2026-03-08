import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/service/maplibre_service.dart';
import 'package:aplicacion_movil/view/components/medical_background.dart';
import 'package:aplicacion_movil/view/screens/MapSample.dart';
import 'package:aplicacion_movil/view/screens/drone_camera_list_screen.dart';
import 'package:aplicacion_movil/view/screens/map_download_screen.dart';
import 'package:aplicacion_movil/view/screens/resumenTriaje.dart';
import 'package:aplicacion_movil/view/screens/triajeMedicoScreen.dart';
import 'package:aplicacion_movil/view/components/MainButton.dart';
import 'package:aplicacion_movil/view/components/appbar.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class Mainscreen extends StatelessWidget {
  const Mainscreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, showHomeAction: false),
      body: Stack(
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 🔵 Botón: Vista en tiempo real drones
                  MainButton(
                    icon: MdiIcons.quadcopter,
                    text: LangService.text('drone_view'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DroneCameraListScreen(),
                        ),
                      );
                    },
                  ),

                  // Botón: Mapa desaparecidos
                  MainButton(
                    icon: MdiIcons.mapSearchOutline,
                    text: LangService.text('missing_map'),
                    onTap: () {
                      final mapService = MapLibreService();
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

                  // Triaje médico
                  MainButton(
                    icon: MdiIcons.clipboardPulseOutline,
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

                  // Resumen Triaje médico
                  MainButton(
                    icon: MdiIcons.chartBoxOutline,
                    text: LangService.text('triage_summary'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const Resumentriaje(),
                        ),
                      );
                    },
                  ),

                  // Descargar mapas
                  MainButton(
                    icon: MdiIcons.cloudDownloadOutline,
                    text: LangService.text('download_maps'),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapDownloadScreen(
                            onDownloadComplete: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

