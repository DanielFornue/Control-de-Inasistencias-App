import 'dart:convert';
import 'dart:io'; // Para detectar si es Windows
import 'dart:async'; // Para el reloj (Timer)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// --- CONFIGURACIÓN GLOBAL ---
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  // --- CORRECCIÓN AQUÍ: Usamos 'launcher_icon' en lugar de 'ic_launcher' ---
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/launcher_icon');

  const LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(defaultActionName: 'Open notification');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    linux: initializationSettingsLinux,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (details) {
      print("Tocaron la notificación: ${details.payload}");
    },
  );

  // --- PEDIR PERMISOS (Android 13+) ---
  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  if (androidImplementation != null) {
    await androidImplementation.requestNotificationsPermission();
  }

  runApp(const AsistenciasApp());
}

// --- CLASE MATERIA ---
class Materia {
  String nombre;
  int limiteFaltas;
  int faltasActuales;

  Materia({
    required this.nombre,
    required this.limiteFaltas,
    this.faltasActuales = 0,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'limiteFaltas': limiteFaltas,
    'faltasActuales': faltasActuales,
  };

  factory Materia.fromJson(Map<String, dynamic> json) {
    return Materia(
      nombre: json['nombre'],
      limiteFaltas: json['limiteFaltas'],
      faltasActuales: json['faltasActuales'],
    );
  }
}

class AsistenciasApp extends StatelessWidget {
  const AsistenciasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF80DEEA),
          onPrimary: Colors.black,
          surface: Color(0xFF1E1E1E),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _indicePestana = 0;
  List<Materia> misMaterias = [];
  DateTime _fechaSeleccionada = DateTime.now();
  Map<DateTime, List<String>> _historialEventos = {};

  // --- TUS FRASES NUEVAS ---
  final List<String> _mensajesGraciosos = [
    "¿Tienes ganas de faltar? Hazlo, pero regístralo.",
    "Fúgate, pero regístralo.",
    "Es hora de irse.",
    "¿Clase aburrida? Vete, pero regístralo.",
    "¿Hoy toca ese profesor? No vayas.",
    "La vida es corta, sáltate la clase (y anótalo).",
  ];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _iniciarSistemaNotificaciones();
  }

  void _iniciarSistemaNotificaciones() {
    if (!Platform.isWindows) {
      _programarAndroid();
    } else {
      _iniciarVigilanteWindows();
    }
  }

  // Lógica Android: Alarma a las 8:00 AM
  Future<void> _programarAndroid() async {
    String mensajeAzar =
        _mensajesGraciosos[Random().nextInt(_mensajesGraciosos.length)];
    final now = tz.TZDateTime.now(tz.local);

    // Configurar para las 8:00 AM
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      8,
      00,
    );

    // Si ya pasaron las 8 AM, programar para mañana
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'canal_asistencias_diarias',
          'Notificaciones Diarias',
          channelDescription: 'Recordatorios a las 8 AM',
          importance: Importance.max,
          priority: Priority.high,
        );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      888, // ID fijo
      'Asistencias', // Título simple
      mensajeAzar, // Tu frase
      scheduledDate,
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repetir diario
    );
  }

  // Lógica Windows
  void _iniciarVigilanteWindows() {
    Timer.periodic(const Duration(seconds: 60), (timer) {
      final ahora = DateTime.now();
      if (ahora.hour == 8 && ahora.minute == 0) {
        String mensajeAzar =
            _mensajesGraciosos[Random().nextInt(_mensajesGraciosos.length)];
        _lanzarNotificacionAhora("Asistencias", mensajeAzar);
      }
    });
  }

  Future<void> _lanzarNotificacionAhora(String titulo, String cuerpo) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'canal_test',
          'Alertas',
          importance: Importance.max,
          priority: Priority.high,
        );

    await flutterLocalNotificationsPlugin.show(
      Random().nextInt(1000),
      titulo,
      cuerpo,
      const NotificationDetails(android: androidDetails),
    );
  }

  // --- PERSISTENCIA Y LÓGICA DE MATERIAS (Igual que antes) ---
  Future<void> _guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> materiasJson = misMaterias
        .map((m) => jsonEncode(m.toJson()))
        .toList();
    await prefs.setStringList('mis_materias', materiasJson);

    Map<String, dynamic> historialJson = {};
    _historialEventos.forEach((key, value) {
      historialJson[key.toIso8601String()] = value;
    });
    await prefs.setString('mi_historial', jsonEncode(historialJson));
  }

  Future<void> _cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      List<String>? materiasGuardadas = prefs.getStringList('mis_materias');
      if (materiasGuardadas != null) {
        misMaterias = materiasGuardadas
            .map((item) => Materia.fromJson(jsonDecode(item)))
            .toList();
      }
      String? historialGuardado = prefs.getString('mi_historial');
      if (historialGuardado != null) {
        Map<String, dynamic> mapaTemporal = jsonDecode(historialGuardado);
        _historialEventos = {};
        mapaTemporal.forEach((key, value) {
          DateTime fechaReal = DateTime.parse(key);
          _historialEventos[fechaReal] = List<String>.from(value);
        });
      }
    });
  }

  DateTime _normalizarFecha(DateTime fecha) {
    return DateTime(fecha.year, fecha.month, fecha.day);
  }

  void _agregarMateria(String nombre, int limite, int actuales) {
    setState(() {
      misMaterias.add(
        Materia(nombre: nombre, limiteFaltas: limite, faltasActuales: actuales),
      );
      _guardarDatos();
    });
  }

  void _eliminarMateria(int indice) {
    setState(() {
      String nombreMateria = misMaterias[indice].nombre;
      _historialEventos.forEach((fecha, listaDeEventos) {
        listaDeEventos.removeWhere(
          (evento) => evento.startsWith("$nombreMateria -"),
        );
      });
      misMaterias.removeAt(indice);
      _guardarDatos();
    });
  }

  void _sumarFalta(int indice) {
    setState(() {
      Materia materia = misMaterias[indice];
      if (materia.faltasActuales < materia.limiteFaltas + 5) {
        materia.faltasActuales++;
        DateTime hoy = _normalizarFecha(DateTime.now());
        String evento =
            "${materia.nombre} - Inasistencia ${materia.faltasActuales}";
        if (_historialEventos[hoy] == null) {
          _historialEventos[hoy] = [];
        }
        _historialEventos[hoy]!.add(evento);
        _guardarDatos();
      }
    });
  }

  void _restarFalta(int indice) {
    setState(() {
      if (misMaterias[indice].faltasActuales > 0) {
        misMaterias[indice].faltasActuales--;
        _guardarDatos();
      }
    });
  }

  void _mostrarDialogoAgregar() {
    String nombreTemp = "";
    String limiteTemp = "";
    String actualesTemp = "0";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text(
            "Nueva Materia",
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Nombre",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                onChanged: (value) => nombreTemp = value,
              ),
              TextField(
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Límite de faltas",
                  labelStyle: TextStyle(color: Colors.grey),
                ),
                keyboardType: TextInputType.number,
                onChanged: (value) => limiteTemp = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.red),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF80DEEA),
              ),
              onPressed: () {
                if (nombreTemp.isNotEmpty && limiteTemp.isNotEmpty) {
                  int limite = int.parse(limiteTemp);
                  int actuales = int.tryParse(actualesTemp) ?? 0;
                  _agregarMateria(nombreTemp, limite, actuales);
                  Navigator.pop(context);
                }
              },
              child: const Text(
                "Guardar",
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _vistaMaterias() {
    if (misMaterias.isEmpty) {
      return const Center(
        child: Text(
          "Sin materias.\nUsa el botón +",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }
    return ListView.builder(
      itemCount: misMaterias.length,
      itemBuilder: (context, index) {
        return CourseCard(
          materiaObj: misMaterias[index],
          onDelete: () => _eliminarMateria(index),
          onAdd: () => _sumarFalta(index),
          onRemove: () => _restarFalta(index),
        );
      },
    );
  }

  Widget _vistaCalendario() {
    DateTime fechaNormalizada = _normalizarFecha(_fechaSeleccionada);
    List<String> eventosDelDia = _historialEventos[fechaNormalizada] ?? [];
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(20),
          ),
          child: CalendarDatePicker(
            initialDate: _fechaSeleccionada,
            firstDate: DateTime(2020),
            lastDate: DateTime(2030),
            onDateChanged: (nuevaFecha) {
              setState(() {
                _fechaSeleccionada = nuevaFecha;
              });
            },
          ),
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "Registro del día:",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: eventosDelDia.isEmpty
              ? const Center(
                  child: Text(
                    "No registraste faltas este día",
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: eventosDelDia.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey[800]!),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFF80DEEA),
                          ),
                          const SizedBox(width: 15),
                          Text(
                            eventosDelDia[index],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _indicePestana == 0 ? 'Mis Inasistencias' : 'Calendario',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        // ¡ICONO DE NOTIFICACIÓN ELIMINADO!
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _indicePestana == 0 ? _vistaMaterias() : _vistaCalendario(),
      ),
      floatingActionButton: _indicePestana == 0
          ? FloatingActionButton(
              onPressed: _mostrarDialogoAgregar,
              backgroundColor: const Color(0xFF80DEEA),
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color(0xFF1E1E1E),
        selectedItemColor: const Color(0xFF80DEEA),
        unselectedItemColor: Colors.grey,
        currentIndex: _indicePestana,
        onTap: (index) => setState(() => _indicePestana = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
        ],
      ),
    );
  }
}

class CourseCard extends StatelessWidget {
  final Materia materiaObj;
  final VoidCallback onDelete;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const CourseCard({
    super.key,
    required this.materiaObj,
    required this.onDelete,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    double porcentaje = 0.0;
    if (materiaObj.limiteFaltas > 0)
      porcentaje = materiaObj.faltasActuales / materiaObj.limiteFaltas;
    double porcentajeBarra = porcentaje > 1.0 ? 1.0 : porcentaje;
    Color colorEstado = const Color(0xFF69F0AE);
    String textoEstado = "Seguro";
    if (porcentaje >= 0.5) {
      colorEstado = const Color(0xFFFFD740);
      textoEstado = "Cuidado";
    }
    if (porcentaje >= 0.8) {
      colorEstado = const Color(0xFFFF5252);
      textoEstado = "Peligro";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  materiaObj.nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: onDelete,
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: porcentajeBarra,
              backgroundColor: Colors.grey[800],
              color: colorEstado,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _BotonChico(icon: Icons.remove, onTap: onRemove),
                  const SizedBox(width: 12),
                  Text(
                    "${materiaObj.faltasActuales}/${materiaObj.limiteFaltas}",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _BotonChico(icon: Icons.add, onTap: onAdd),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colorEstado.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  textoEstado,
                  style: TextStyle(
                    color: colorEstado,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonChico extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _BotonChico({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}
