import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/view/components/medical_background.dart';
import 'package:aplicacion_movil/view/screens/personaScreen.dart';
import 'package:aplicacion_movil/view/components/appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplicacion_movil/models/dao/remote/pacientes_dao.dart';
import 'package:flutter/material.dart';

class Resumentriaje extends StatefulWidget {
  const Resumentriaje({super.key});

  @override
  State<Resumentriaje> createState() => _ResumentriajeState();
}

class _ResumentriajeState extends State<Resumentriaje> {
  final PacientesDao _pacientesDao = PacientesDao();
  Stream<QuerySnapshot> _getPacientes() {
    return _pacientesDao.streamPacientes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),

      body: MedicalBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: _getPacientes(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  LangService.text('error_loading_data'),
                  style: const TextStyle(color: Colors.white),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Text(
                  LangService.text('no_triages'),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }

            final pacientes = snapshot.data!.docs;

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  // Logo superior
                  Image.asset('assets/images/logo.png', height: 120),
                  const SizedBox(height: 20),

                  // Lista de tarjetas
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: pacientes.length,
                    itemBuilder: (context, index) {
                      final data =
                          pacientes[index].data() as Map<String, dynamic>;

                      final descripcion =
                          data['herida'] ?? LangService.text('no_description');
                      final recomendacion =
                          data['recomendacion'] ??
                          LangService.text('no_recommendations');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🩹 Descripción de la herida
                              Row(
                                children: [
                                  const Icon(
                                    Icons.healing,
                                    color: Color(0xFF1A73E8),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    LangService.text('wound_description'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A73E8),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                descripcion,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 💊 Recomendación médica
                              Row(
                                children: [
                                  const Icon(
                                    Icons.medical_services,
                                    color: Color(0xFF2AA6A6),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    LangService.text('medical_recommendation'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF2AA6A6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                recomendacion,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 🔘 Botón de navegación
                              Align(
                                alignment: Alignment.centerRight,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const Personascreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.arrow_forward_rounded),
                                  label: Text(
                                    LangService.text('view_details'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2DA8E2),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
