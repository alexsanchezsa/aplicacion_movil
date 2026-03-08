import 'package:aplicacion_movil/service/idiom_service.dart';
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
  final TextEditingController _oxigenoController = TextEditingController();
  final TextEditingController _frecuenciaController = TextEditingController();

  @override
  void dispose() {
    _descripcionController.dispose();
    _oxigenoController.dispose();
    _frecuenciaController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final location = await InputLocation.getCurrentLocation();
    final ImagePicker picker = ImagePicker();
    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
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
              // Logo superior
              Image.asset('assets/images/logo.png', height: 200),
              const SizedBox(height: 20),

              // Tarjeta blanca principal
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Campo descripción
                    TextField(
                      controller: _descripcionController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: LangService.text('enter_wound_description'),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dos campos lado a lado
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _oxigenoController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: LangService.text('enter_blood_oxygen'),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _frecuenciaController,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              hintText: LangService.text('enter_heart_rate'),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                  width: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Botón "Generar recomendación" y cámara
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2AA6A6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 16.0,
                              ),
                            ),
                            child: Text(
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
                    const SizedBox(height: 20),

                    // Texto dinámico
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7E9FF),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        LangService.text('dynamic_recommendation_text'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Gravedad y prevenciones (ahora en columna)
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7E9FF),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            LangService.text('dynamic_severity'),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD7E9FF),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            LangService.text('dynamic_precautions'),
                            style: const TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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
}
