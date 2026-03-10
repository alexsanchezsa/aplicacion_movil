import 'package:aplicacion_movil/models/dao/remote/pacientes_dao.dart';
import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/service/triage_api_service.dart';
import 'package:aplicacion_movil/view/components/appbar.dart';
import 'package:aplicacion_movil/view/components/input_location.dart';
import 'package:aplicacion_movil/view/components/medical_background.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class TriajeMedicoScreeen extends StatefulWidget {
  const TriajeMedicoScreeen({super.key});

  @override
  State<TriajeMedicoScreeen> createState() => _TriajeMedicoScreen();
}

class _TriajeMedicoScreen extends State<TriajeMedicoScreeen> {
  final TextEditingController _descripcionController = TextEditingController();
  final PacientesDao _pacientesDao = PacientesDao();

  bool _isLoading = false;
  String _recommendationText = '';
  String _severityText = '';
  String _precautionsText = '';

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final location = await InputLocation.getCurrentLocation();
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
  }

  Future<void> _generateRecommendation() async {
    final descripcion = _descripcionController.text.trim();
    if (descripcion.isEmpty) return;

    setState(() {
      _isLoading = true;
      _recommendationText = '';
      _severityText = '';
      _precautionsText = '';
    });

    try {
      final response = await TriageApiService.getRecommendation(
        descripcion,
      );

      String severity = '';
      String precautions = '';
      final answer = response.answer;

      if (answer.contains('🔴')) {
        severity = '🔴 EMERGENCIA VITAL';
      } else if (answer.contains('🟠')) {
        severity = '🟠 URGENTE';
      } else if (answer.contains('🟡')) {
        severity = '🟡 MODERADO';
      } else if (answer.contains('🟢')) {
        severity = '🟢 LEVE';
      }

      final alarmIdx = answer.indexOf('SEÑALES DE ALARMA');
      final whileIdx = answer.indexOf('MIENTRAS ESPERAS');
      if (alarmIdx != -1) {
        final end = whileIdx != -1 ? whileIdx : answer.length;
        precautions = answer.substring(alarmIdx, end).trim();
      }

      setState(() {
        _recommendationText = answer;
        _severityText = severity;
        _precautionsText = precautions;
      });

      double? lat;
      double? lng;
      try {
        final location = await InputLocation.getCurrentLocation();
        if (location != null) {
          lat = location.latitude;
          lng = location.longitude;
        }
      } catch (_) {
        // Handle location error
      }

      await _pacientesDao.saveTriage(
        herida: descripcion,
        recomendacion: answer,
        gravedad: severity.isNotEmpty ? severity : 'Sin clasificar',
        latitude: lat,
        longitude: lng,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LangService.text('triage_saved')),
            backgroundColor: const Color(0xFF2AA6A6),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _recommendationText =
            'Error al obtener la recomendación. Verifica tu conexión e inténtalo de nuevo.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),
      body: MedicalBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', height: 150),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        LangService.text('enter_wound_description'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _descripcionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: LangService.text('dynamic_recommendation_text'),
                          filled: true,
                          fillColor: const Color(0xFFF7F7F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _generateRecommendation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2AA6A6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      LangService.text('generate_recommendation'),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          InkWell(
                            onTap: _takePicture,
                            borderRadius: BorderRadius.circular(50),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: const BoxDecoration(
                                color: Color(0xFF2AA6A6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_recommendationText.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: _getSeverityColor().withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _severityText.isEmpty ? LangService.text('dynamic_severity') : _severityText,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _getSeverityColor(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SelectableText(
                          _recommendationText,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.5,
                          ),
                        ),
                        if (_precautionsText.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 15),
                            child: SelectableText(
                              _precautionsText,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getSeverityColor() {
    if (_severityText.contains('🔴')) return Colors.red.shade700;
    if (_severityText.contains('🟠')) return Colors.orange.shade700;
    if (_severityText.contains('🟡')) return Colors.yellow.shade800;
    if (_severityText.contains('🟢')) return Colors.green.shade700;
    return const Color(0xFF2AA6A6);
  }
}
