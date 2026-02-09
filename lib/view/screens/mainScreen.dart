import 'dart:math' as math;
import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/service/maplibre_service.dart';
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

// CustomPainter para el fondo con iconos médicos
class MedicalBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Fondo base claro con tinte azul suave
    final backgroundPaint = Paint()
      ..color = const Color(0xFFF0F7FC);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Configuración de iconos
    final iconPaint = Paint()
      ..color = const Color(0xFF2196F3).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final fillPaint = Paint()
      ..color = const Color(0xFF2196F3).withOpacity(0.04)
      ..style = PaintingStyle.fill;

    // Dibujar iconos médicos distribuidos
    _drawMedicalIcons(canvas, size, iconPaint, fillPaint);
  }

  void _drawMedicalIcons(Canvas canvas, Size size, Paint strokePaint, Paint fillPaint) {
    final random = math.Random(42); // Seed fijo para consistencia

    // Posiciones predefinidas para los iconos
    final positions = [
      Offset(size.width * 0.1, size.height * 0.05),
      Offset(size.width * 0.88, size.height * 0.08),
      Offset(size.width * 0.05, size.height * 0.18),
      Offset(size.width * 0.92, size.height * 0.22),
      Offset(size.width * 0.12, size.height * 0.35),
      Offset(size.width * 0.85, size.height * 0.4),
      Offset(size.width * 0.08, size.height * 0.55),
      Offset(size.width * 0.9, size.height * 0.58),
      Offset(size.width * 0.1, size.height * 0.72),
      Offset(size.width * 0.88, size.height * 0.75),
      Offset(size.width * 0.06, size.height * 0.88),
      Offset(size.width * 0.92, size.height * 0.92),
    ];

    for (int i = 0; i < positions.length; i++) {
      final pos = positions[i];
      final iconType = i % 4;
      final iconSize = 25.0 + random.nextDouble() * 15;

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate((random.nextDouble() - 0.5) * 0.3);

      switch (iconType) {
        case 0:
          _drawCross(canvas, iconSize, strokePaint, fillPaint);
          break;
        case 1:
          _drawHeart(canvas, iconSize, strokePaint, fillPaint);
          break;
        case 2:
          _drawStethoscope(canvas, iconSize, strokePaint);
          break;
        case 3:
          _drawPlusSign(canvas, iconSize, strokePaint);
          break;
      }

      canvas.restore();
    }
  }

  void _drawCross(Canvas canvas, double size, Paint strokePaint, Paint fillPaint) {
    final path = Path();
    final armWidth = size * 0.35;
    final armLength = size;

    path.moveTo(-armWidth / 2, -armLength / 2);
    path.lineTo(armWidth / 2, -armLength / 2);
    path.lineTo(armWidth / 2, -armWidth / 2);
    path.lineTo(armLength / 2, -armWidth / 2);
    path.lineTo(armLength / 2, armWidth / 2);
    path.lineTo(armWidth / 2, armWidth / 2);
    path.lineTo(armWidth / 2, armLength / 2);
    path.lineTo(-armWidth / 2, armLength / 2);
    path.lineTo(-armWidth / 2, armWidth / 2);
    path.lineTo(-armLength / 2, armWidth / 2);
    path.lineTo(-armLength / 2, -armWidth / 2);
    path.lineTo(-armWidth / 2, -armWidth / 2);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawHeart(Canvas canvas, double size, Paint strokePaint, Paint fillPaint) {
    final path = Path();
    final halfSize = size / 2;

    path.moveTo(0, halfSize * 0.8);
    path.cubicTo(
      -halfSize * 1.2, halfSize * 0.2,
      -halfSize * 1.2, -halfSize * 0.6,
      0, -halfSize * 0.2,
    );
    path.cubicTo(
      halfSize * 1.2, -halfSize * 0.6,
      halfSize * 1.2, halfSize * 0.2,
      0, halfSize * 0.8,
    );

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawStethoscope(Canvas canvas, double size, Paint strokePaint) {
    final path = Path();
    path.addOval(Rect.fromCircle(center: Offset(-size * 0.3, -size * 0.4), radius: size * 0.15));
    path.addOval(Rect.fromCircle(center: Offset(size * 0.3, -size * 0.4), radius: size * 0.15));
    canvas.drawPath(path, strokePaint);

    final tubePath = Path();
    tubePath.moveTo(-size * 0.2, -size * 0.3);
    tubePath.quadraticBezierTo(0, 0, 0, size * 0.3);
    tubePath.moveTo(size * 0.2, -size * 0.3);
    tubePath.quadraticBezierTo(0, 0, 0, size * 0.3);
    canvas.drawPath(tubePath, strokePaint);

    canvas.drawCircle(Offset(0, size * 0.4), size * 0.2, strokePaint);
  }

  void _drawPlusSign(Canvas canvas, double size, Paint strokePaint) {
    canvas.drawLine(
      Offset(-size / 2, 0),
      Offset(size / 2, 0),
      strokePaint..strokeWidth = 3,
    );
    canvas.drawLine(
      Offset(0, -size / 2),
      Offset(0, size / 2),
      strokePaint..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
