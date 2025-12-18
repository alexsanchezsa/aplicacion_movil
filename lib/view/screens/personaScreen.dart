import 'package:aplicacion_movil/service/idiom_service.dart';
import 'package:aplicacion_movil/view/components/appbar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aplicacion_movil/models/dao/remote/pacientes_dao.dart';
import 'package:flutter/material.dart';

class Personascreen extends StatefulWidget {
  const Personascreen({super.key});

  @override
  State<Personascreen> createState() => _PersonascreenState();
}

class _PersonascreenState extends State<Personascreen> {
  final PacientesDao _pacientesDao = PacientesDao();
  Stream<QuerySnapshot> _getPacientes() {
    return _pacientesDao.streamPacientes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context),

      // 🎨 Fondo degradado
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7DBCF7), Color(0xFF4292CC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
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
                  LangService.text('no_patients'),
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

                  // Lista de tarjetas por paciente
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: pacientes.length,
                    itemBuilder: (context, index) {
                      final data =
                          pacientes[index].data() as Map<String, dynamic>;

                      final herida =
                          data['herida'] ?? LangService.text('no_description');
                      final ubicacion = data['location'] != null
                          ? 'Lat: ${(data['location'] as GeoPoint).latitude.toStringAsFixed(4)}\nLng: ${(data['location'] as GeoPoint).longitude.toStringAsFixed(4)}'
                          : LangService.text('location_unavailable');
                      final gravedad =
                          data['estado'] ?? LangService.text('not_specified');
                      final recomendacion =
                          data['recomendacion'] ??
                          LangService.text('no_recommendations');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🩹 Herida
                              Row(
                                children: [
                                  const Icon(
                                    Icons.healing,
                                    color: Color(0xFF1A73E8),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
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
                                herida,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // 📍 Localización
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: Color(0xFF2AA6A6),
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    LangService.text('location'),
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
                                ubicacion,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ⚠️ Gravedad
                              Row(
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: Colors.orange,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    LangService.text('patient_severity'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                gravedad,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),

                              const SizedBox(height: 14),

                              // 💊 Recomendación médica
                              Row(
                                children: [
                                  const Icon(
                                    Icons.medical_services,
                                    color: Colors.green,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    LangService.text('medical_recommendation'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
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
