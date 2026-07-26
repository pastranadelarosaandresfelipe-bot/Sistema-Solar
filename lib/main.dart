import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main(List<String> args) {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Consola de Vuelo",
      theme: ThemeData.dark(),
      home: PantallaConsola(),
    );
  }
}

// =====================================================
// COLORES DEL TEMA
// =====================================================

const Color fondoApp = Color(0xFF050807);
const Color fondoPanel = Color(0xFF0A120E);
const Color bordeColor = Color(0xFF1A2E22);
const Color bordeOrbita = Color(0xFF1F3A2A);
const Color colorVerde = Color(0xFF4ADE80);
const Color colorAmarillo = Color(0xFFFACC15);

// =====================================================
// MODELO Y DATOS BASE DE CADA PLANETA
// El id coincide con el que usa la API le-systeme-solaire.net
// (los nombres allí están en francés). radioOrbita, tamano y
// duracionGiro son valores de referencia (no a escala real);
// la vista los reescala según el espacio disponible en pantalla.
// =====================================================

class Planeta {
  final String id;
  final String nombre;
  final String nombreWiki;
  final Color color;
  final double radioOrbita;
  final double tamano;
  final int duracionSegundos;
  final double anguloInicial;

  Planeta({
    required this.id,
    required this.nombre,
    required this.nombreWiki,
    required this.color,
    required this.radioOrbita,
    required this.tamano,
    required this.duracionSegundos,
    required this.anguloInicial,
  });
}

// -----------------------------------------------------
// Cálculo aproximado de la posición orbital real según la
// fecha actual. Se basa en la longitud media en la época
// J2000 y el período orbital de cada planeta (valores
// astronómicos de referencia estándar). No considera la
// excentricidad completa de cada órbita, por lo que es una
// aproximación con fines ilustrativos, no de precisión
// científica.
// -----------------------------------------------------
double _anguloRealActual(double longitudJ2000Grados, double periodoDias) {
  final epocaJ2000 = DateTime.utc(2000, 1, 1, 12, 0, 0);
  final diasTranscurridos =
      DateTime.now().toUtc().difference(epocaJ2000).inHours / 24.0;
  final grados =
      (longitudJ2000Grados + (360 / periodoDias) * diasTranscurridos) % 360;
  return grados * pi / 180;
}

// Longitud media J2000 (°) y período orbital (días) de referencia
// para cada planeta, usados solo para ubicar la posición inicial.
List<Planeta> construirPlanetas() {
  return [
    // NOTA sobre duracionSegundos: no son proporcionales al período orbital
    // real (eso haría que Neptuno tardara horas en dar una vuelta en pantalla).
    // Se usa una progresión comprimida pero ordenada: cada planeta más lejano
    // gira más lento que el anterior, igual que en la realidad, solo que a
    // una escala de tiempo utilizable para una interfaz.
    Planeta(
      id: "mercure",
      nombre: "Mercurio",
      nombreWiki: "Mercurio (planeta)",
      color: Color(0xFF9C9C9C),
      radioOrbita: 60,
      tamano: 8,
      duracionSegundos: 18,
      anguloInicial: _anguloRealActual(252.25, 87.969),
    ),
    Planeta(
      id: "venus",
      nombre: "Venus",
      nombreWiki: "Venus (planeta)",
      color: Color(0xFFE8CDA2),
      radioOrbita: 85,
      tamano: 11,
      duracionSegundos: 26,
      anguloInicial: _anguloRealActual(181.98, 224.701),
    ),
    Planeta(
      id: "terre",
      nombre: "Tierra",
      nombreWiki: "Tierra",
      color: Color(0xFF4A90D9),
      radioOrbita: 110,
      tamano: 12,
      duracionSegundos: 34,
      anguloInicial: _anguloRealActual(100.46, 365.256),
    ),
    Planeta(
      id: "mars",
      nombre: "Marte",
      nombreWiki: "Marte (planeta)",
      color: Color(0xFFC1440E),
      radioOrbita: 135,
      tamano: 9,
      duracionSegundos: 50,
      anguloInicial: _anguloRealActual(355.45, 686.980),
    ),
    Planeta(
      id: "jupiter",
      nombre: "Júpiter",
      nombreWiki: "Júpiter (planeta)",
      color: Color(0xFFD9A066),
      radioOrbita: 165,
      tamano: 18,
      duracionSegundos: 90,
      anguloInicial: _anguloRealActual(34.40, 4332.59),
    ),
    Planeta(
      id: "saturne",
      nombre: "Saturno",
      nombreWiki: "Saturno (planeta)",
      color: Color(0xFFE3C16F),
      radioOrbita: 195,
      tamano: 16,
      duracionSegundos: 120,
      anguloInicial: _anguloRealActual(49.94, 10759.22),
    ),
    Planeta(
      id: "uranus",
      nombre: "Urano",
      nombreWiki: "Urano (planeta)",
      color: Color(0xFF9FE0E0),
      radioOrbita: 220,
      tamano: 13,
      duracionSegundos: 160,
      anguloInicial: _anguloRealActual(313.23, 30685.4),
    ),
    Planeta(
      id: "neptune",
      nombre: "Neptuno",
      nombreWiki: "Neptuno (planeta)",
      color: Color(0xFF4169E1),
      radioOrbita: 245,
      tamano: 13,
      duracionSegundos: 200,
      anguloInicial: _anguloRealActual(304.88, 60189),
    ),
  ];
}

final List<Planeta> PLANETAS = construirPlanetas();

// Radio orbital de referencia usado para diseñar los valores de arriba.
// Sirve para calcular el factor de escala según el espacio disponible.
const double RADIO_ORBITA_MAXIMO_REFERENCIA = 245;

// Valores de referencia de la órbita de la Tierra (km), usados para
// estimar distancias aproximadas sin tener que pedirlos por API cada vez.
const double TIERRA_PERIHELIO_KM = 147095000;
const double TIERRA_AFELIO_KM = 152100000;

// Velocidad de referencia para estimar tiempos de viaje (km/s), similar
// a la de una sonda interplanetaria real. Es solo ilustrativa.
const double VELOCIDAD_REFERENCIA_KMS = 17;

// =====================================================
// SERVICIOS (llamadas a las 3 APIs)
// =====================================================

// =====================================================
// DATOS FIJOS DE CADA PLANETA
// La API le-systeme-solaire.net ahora exige un header
// "Authorization: Bearer <token>", y su servidor no responde
// correctamente al preflight CORS que ese header obliga a
// enviar desde un navegador. Resultado: funciona desde apps
// nativas o backends, pero nunca desde Flutter Web (ni con
// una key válida). Como estos son datos físicos que no cambian,
// se guardan aquí localmente en vez de pedirlos por red.
// Valores de referencia astronómica estándar.
// =====================================================

const Map<String, Map<String, dynamic>> _DATOS_PLANETAS = {
  "mercure": {
    "gravity": 3.7,
    "meanRadius": 2439.7,
    "avgTemp": 340,
    "semimajorAxis": 57909050,
    "inclination": 7.0,
    "perihelion": 46001200,
    "aphelion": 69816900,
    "discoveredBy": null,
    "discoveryDate": null,
  },
  "venus": {
    "gravity": 8.87,
    "meanRadius": 6051.8,
    "avgTemp": 737,
    "semimajorAxis": 108208000,
    "inclination": 3.39,
    "perihelion": 107477000,
    "aphelion": 108939000,
    "discoveredBy": null,
    "discoveryDate": null,
  },
  "terre": {
    "gravity": 9.8,
    "meanRadius": 6371.0,
    "avgTemp": 288,
    "semimajorAxis": 149598023,
    "inclination": 0.0,
    "perihelion": 147095000,
    "aphelion": 152100000,
    "discoveredBy": null,
    "discoveryDate": null,
  },
  "mars": {
    "gravity": 3.71,
    "meanRadius": 3389.5,
    "avgTemp": 210,
    "semimajorAxis": 227939200,
    "inclination": 1.85,
    "perihelion": 206700000,
    "aphelion": 249200000,
    "discoveredBy": null,
    "discoveryDate": null,
  },
  "jupiter": {
    "gravity": 24.79,
    "meanRadius": 69911.0,
    "avgTemp": 165,
    "semimajorAxis": 778570000,
    "inclination": 1.3,
    "perihelion": 740520000,
    "aphelion": 816620000,
    "discoveredBy": null,
    "discoveryDate": null,
  },
  "saturne": {
    "gravity": 10.44,
    "meanRadius": 58232.0,
    "avgTemp": 134,
    "semimajorAxis": 1433530000,
    "inclination": 2.49,
    "perihelion": 1352550000,
    "aphelion": 1514500000,
    "discoveredBy": null,
    "discoveryDate": null,
  },
  "uranus": {
    "gravity": 8.69,
    "meanRadius": 25362.0,
    "avgTemp": 76,
    "semimajorAxis": 2875040000,
    "inclination": 0.77,
    "perihelion": 2741300000,
    "aphelion": 3008000000,
    "discoveredBy": "William Herschel",
    "discoveryDate": "1781",
  },
  "neptune": {
    "gravity": 11.15,
    "meanRadius": 24622.0,
    "avgTemp": 72,
    "semimajorAxis": 4500000000,
    "inclination": 1.77,
    "perihelion": 4459630000,
    "aphelion": 4537000000,
    "discoveredBy": "Johann Galle",
    "discoveryDate": "1846",
  },
};

class ServicioDatosSolar {
  static final Map<String, String> _cacheWikipedia = {};

  static Future<Map<String, dynamic>> obtenerDatosPlaneta(String id) async {
    // Simula una pequeña espera para que el indicador de carga se vea,
    // pero los datos vienen de memoria, no de red.
    await Future.delayed(Duration(milliseconds: 200));
    final datos = _DATOS_PLANETAS[id];
    if (datos == null) {
      throw Exception("No hay datos locales para el planeta '$id'");
    }
    return datos;
  }

  // Igual que con los departamentos: se prueban varios títulos porque
  // algunos nombres de planeta apuntan a páginas de desambiguación.
  static Future<String?> obtenerResumenWikipedia(
      String nombreWiki, String nombreSimple) async {
    if (_cacheWikipedia.containsKey(nombreWiki))
      return _cacheWikipedia[nombreWiki];

    final candidatos = [nombreWiki, nombreSimple];

    for (final candidato in candidatos) {
      try {
        final url = Uri.parse(
          "https://es.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(candidato.replaceAll(' ', '_'))}",
        );
        final respuesta = await http.get(url);

        if (respuesta.statusCode == 200) {
          final datos = jsonDecode(respuesta.body);
          final tipo = datos["type"];
          final extracto = datos["extract"];

          final esValido = tipo != "disambiguation" &&
              extracto != null &&
              extracto.toString().trim().isNotEmpty;

          if (esValido) {
            _cacheWikipedia[nombreWiki] = extracto;
            return extracto;
          }
        }
      } catch (error) {
        print(error);
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> obtenerPosicionISS() async {
    final url = Uri.parse("https://api.wheretheiss.at/v1/satellites/25544");
    final respuesta = await http.get(url);

    if (respuesta.statusCode == 200) {
      return jsonDecode(respuesta.body) as Map<String, dynamic>;
    } else {
      throw Exception("No se pudo obtener la posición de la ISS");
    }
  }
}

// =====================================================
// PANTALLA PRINCIPAL: VISTA ORBITAL + PANEL HUD
// =====================================================

class PantallaConsola extends StatefulWidget {
  const PantallaConsola({Key? key}) : super(key: key);

  @override
  State<PantallaConsola> createState() => _PantallaConsolaState();
}

class _PantallaConsolaState extends State<PantallaConsola>
    with TickerProviderStateMixin {
  final Map<String, AnimationController> _controladores = {};
  Offset _posicionNave = Offset(60, 60);

  Planeta? _planetaSeleccionado;
  Map<String, dynamic>? _datosPlaneta;
  bool _cargandoDatos = false;
  bool _errorDatos = false;

  String? _historia;
  bool _cargandoHistoria = false;

  Map<String, dynamic>? _posicionISS;
  bool _cargandoISS = false;
  bool _errorISS = false;

  @override
  void initState() {
    super.initState();
    for (final planeta in PLANETAS) {
      final controlador = AnimationController(
        duration: Duration(seconds: planeta.duracionSegundos),
        vsync: this,
      )..repeat();
      _controladores[planeta.id] = controlador;
    }
  }

  @override
  void dispose() {
    for (final controlador in _controladores.values) {
      controlador.dispose();
    }
    super.dispose();
  }

  Future<void> _seleccionarPlaneta(Planeta planeta) async {
    setState(() {
      _planetaSeleccionado = planeta;
      _cargandoDatos = true;
      _errorDatos = false;
      _datosPlaneta = null;
      _historia = null;
      _posicionISS = null;
    });

    try {
      final datos = await ServicioDatosSolar.obtenerDatosPlaneta(planeta.id);
      setState(() {
        _datosPlaneta = datos;
        _cargandoDatos = false;
      });

      if (planeta.id == "terre") {
        _actualizarPosicionISS();
      } else {
        _cargarHistoria(planeta);
      }
    } catch (e) {
      print("Error datos: $e");
      setState(() {
        _errorDatos = true;
        _cargandoDatos = false;
      });
    }
  }

  Future<void> _cargarHistoria(Planeta planeta) async {
    setState(() => _cargandoHistoria = true);
    final resumen = await ServicioDatosSolar.obtenerResumenWikipedia(
        planeta.nombreWiki, planeta.nombre);
    setState(() {
      _historia = resumen;
      _cargandoHistoria = false;
    });
  }

  Future<void> _actualizarPosicionISS() async {
    setState(() {
      _cargandoISS = true;
      _errorISS = false;
    });

    try {
      final posicion = await ServicioDatosSolar.obtenerPosicionISS();
      setState(() {
        _posicionISS = posicion;
        _cargandoISS = false;
      });
    } catch (e) {
      setState(() {
        _errorISS = true;
        _cargandoISS = false;
      });
    }

    if (_historia == null && !_cargandoHistoria) {
      _cargarHistoriaTierra();
    }
  }

  Future<void> _cargarHistoriaTierra() async {
    setState(() => _cargandoHistoria = true);
    final resumen =
        await ServicioDatosSolar.obtenerResumenWikipedia("Tierra", "Tierra");
    setState(() {
      _historia = resumen;
      _cargandoHistoria = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: fondoApp,
      appBar: AppBar(
        title: Text(
          "Consola de Vuelo",
          style: TextStyle(fontFamily: 'monospace', letterSpacing: 0.6),
        ),
        centerTitle: true,
        backgroundColor: fondoPanel,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool esAncho = constraints.maxWidth > 700;

          final vista = _vistaOrbital();
          final panel = _panelHud();

          if (esAncho) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: vista),
                Container(width: 300, child: panel),
              ],
            );
          }

          return Column(
            children: [
              SizedBox(height: 320, child: vista),
              Expanded(child: panel),
            ],
          );
        },
      ),
    );
  }

  // =====================================================
  // VISTA ORBITAL
  // =====================================================

  Widget _vistaOrbital() {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          colors: [fondoPanel, fondoApp],
          radius: 0.9,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double ancho = constraints.maxWidth;
          final double alto = constraints.maxHeight;
          final Offset centro = Offset(ancho / 2, alto / 2);

          // Factor de escala: la vista se ajusta al espacio disponible
          // en vez de usar un tamaño fijo, para no sobredimensionar en
          // pantallas de celular.
          final double espacioDisponible = min(ancho, alto) / 2;
          // Margen de seguridad (0.85) para que el planeta más externo
          // y su área táctil no queden pegados al borde del contenedor:
          // eso es lo que causaba que se vieran "salir" de la vista.
          final double escala =
              (espacioDisponible * 0.85 / RADIO_ORBITA_MAXIMO_REFERENCIA)
                  .clamp(0.30, 1.3);

          return MouseRegion(
            // Oculta el cursor nativo del sistema dentro de la vista
            // orbital, para que solo se vea la nave siguiendo el puntero.
            cursor: SystemMouseCursors.none,
            child: Listener(
              onPointerHover: (evento) =>
                  setState(() => _posicionNave = evento.localPosition),
              onPointerMove: (evento) =>
                  setState(() => _posicionNave = evento.localPosition),
              child: ClipRect(
                // Evita que planetas o la nave se dibujen visualmente
                // fuera de los límites de la vista orbital.
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Sol
                    Positioned(
                      left: centro.dx - (13 * escala),
                      top: centro.dy - (13 * escala),
                      child: Container(
                        width: 26 * escala,
                        height: 26 * escala,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorVerde,
                          boxShadow: [
                            BoxShadow(
                                color: colorVerde.withOpacity(0.45),
                                blurRadius: 18,
                                spreadRadius: 2),
                          ],
                        ),
                      ),
                    ),

                    // Anillos de órbita (decorativos)
                    ...PLANETAS.map((planeta) {
                      final double radio = planeta.radioOrbita * escala;
                      return Positioned(
                        left: centro.dx - radio,
                        top: centro.dy - radio,
                        child: Container(
                          width: radio * 2,
                          height: radio * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: bordeOrbita, width: 1),
                          ),
                        ),
                      );
                    }),

                    // Planetas en movimiento
                    ...PLANETAS.map((planeta) {
                      final controlador = _controladores[planeta.id]!;
                      final double radio = planeta.radioOrbita * escala;
                      final double tamano = max(planeta.tamano * escala, 8);
                      final bool seleccionado =
                          _planetaSeleccionado?.id == planeta.id;

                      return AnimatedBuilder(
                        animation: controlador,
                        builder: (context, _) {
                          final double angulo = planeta.anguloInicial +
                              (controlador.value * 2 * pi);
                          final double dx =
                              centro.dx + radio * cos(angulo) - (tamano / 2);
                          final double dy =
                              centro.dy + radio * sin(angulo) - (tamano / 2);

                          return Positioned(
                            left: dx,
                            top: dy,
                            child: GestureDetector(
                              onTap: () => _seleccionarPlaneta(planeta),
                              child: Container(
                                // Área táctil un poco más grande que el
                                // círculo visible, para que sea fácil de tocar
                                width: tamano + 14,
                                height: tamano + 14,
                                alignment: Alignment.center,
                                child: Container(
                                  width: tamano,
                                  height: tamano,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: planeta.color,
                                    border: seleccionado
                                        ? Border.all(
                                            color: Colors.white, width: 2)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),

                    // Nave (sigue el dedo/mouse dentro de la vista orbital)
                    Positioned(
                      left: _posicionNave.dx - 12,
                      top: _posicionNave.dy - 12,
                      child: IgnorePointer(
                        child: Icon(Icons.rocket_launch,
                            color: colorAmarillo, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =====================================================
  // PANEL HUD
  // =====================================================

  Widget _panelHud() {
    return Container(
      color: fondoPanel,
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "OBJETIVO SELECCIONADO",
              style: TextStyle(
                  fontSize: 9,
                  fontFamily: 'monospace',
                  color: colorVerde,
                  letterSpacing: 0.6),
            ),
            SizedBox(height: 4),
            Text(
              _planetaSeleccionado?.nombre ?? "Ningún objetivo",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
            Divider(color: bordeColor, height: 22),
            _contenidoPanel(),
            _avisoAproximacion(),
          ],
        ),
      ),
    );
  }

  Widget _avisoAproximacion() {
    return Container(
      margin: EdgeInsets.only(top: 16),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF1A1A0A),
        border: Border.all(color: colorAmarillo.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "⚠ Las posiciones y velocidades orbitales mostradas son aproximadas (no consideran la excentricidad completa de cada órbita ni el período real de traslación) y sirven solo con fines ilustrativos.",
        style: TextStyle(
            fontSize: 10, color: colorAmarillo.withOpacity(0.85), height: 1.4),
      ),
    );
  }

  Widget _contenidoPanel() {
    if (_planetaSeleccionado == null) {
      return Text(
        "Toca cualquier planeta en la vista orbital para ver su información, curiosidades y distancia aproximada desde la Tierra.\n\nSi seleccionas la Tierra, verás la posición actual de la Estación Espacial Internacional.",
        style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.6),
      );
    }

    if (_cargandoDatos) {
      return Center(
          child: Padding(
              padding: EdgeInsets.only(top: 20),
              child: CircularProgressIndicator(color: colorVerde)));
    }

    if (_errorDatos) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("No se pudo cargar la información. Verifica tu conexión.",
              style: TextStyle(fontSize: 12, color: Colors.white70)),
          SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => _seleccionarPlaneta(_planetaSeleccionado!),
            child: Text("Reintentar"),
          ),
        ],
      );
    }

    if (_planetaSeleccionado!.id == "terre") {
      return _panelTierra();
    }

    return _panelPlaneta();
  }

  Widget _bloque(String titulo, Widget valor) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo,
              style: TextStyle(
                  fontSize: 9, color: Colors.white38, letterSpacing: 0.5)),
          SizedBox(height: 3),
          valor,
        ],
      ),
    );
  }

  Widget _textoValor(String texto) {
    return Text(texto, style: TextStyle(fontSize: 12, color: Colors.white));
  }

  String _formatearNumero(num valor) {
    final entero = valor.round().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < entero.length; i++) {
      if (i > 0 && (entero.length - i) % 3 == 0) buffer.write(".");
      buffer.write(entero[i]);
    }
    return buffer.toString();
  }

  Map<String, double> _calcularDistanciaAproximada(Map<String, dynamic> datos) {
    final double perihelio = (datos["perihelion"] as num).toDouble();
    final double afelio = (datos["aphelion"] as num).toDouble();
    final double min = (perihelio - TIERRA_PERIHELIO_KM).abs();
    final double max = afelio + TIERRA_AFELIO_KM;
    return {"min": min, "max": max};
  }

  String _estimarTiempoDeViaje(double distanciaKm) {
    final double segundos = distanciaKm / VELOCIDAD_REFERENCIA_KMS;
    final double dias = segundos / 86400;
    if (dias < 1) return "${(segundos / 3600).round()} horas";
    if (dias < 365) return "${dias.round()} días";
    return "${(dias / 365.25).toStringAsFixed(1)} años";
  }

  Widget _panelPlaneta() {
    final datos = _datosPlaneta!;
    final distancias = _calcularDistanciaAproximada(datos);
    final double promedio = (distancias["min"]! + distancias["max"]!) / 2;
    final double? tempK = (datos["avgTemp"] as num?)?.toDouble();
    final int? tempC =
        tempK != null && tempK > 0 ? (tempK - 273.15).round() : null;
    final String? descubridor = datos["discoveredBy"] as String?;
    final String conocidoDesde = (descubridor != null &&
            descubridor.trim().isNotEmpty)
        ? "Descubierto por $descubridor${(datos["discoveryDate"] ?? "").toString().isNotEmpty ? " (${datos["discoveryDate"]})" : ""}"
        : "Conocido desde la Antigüedad";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bloque("GRAVEDAD", _textoValor("${datos["gravity"] ?? "N/D"} m/s²")),
        _bloque("RADIO MEDIO",
            _textoValor("${_formatearNumero(datos["meanRadius"])} km")),
        _bloque("TEMPERATURA PROMEDIO",
            _textoValor(tempC != null ? "$tempC °C (aprox.)" : "N/D")),
        _bloque(
          "ELEMENTOS ORBITALES",
          _textoValor(
              "Radio orbital medio: ${_formatearNumero(datos["semimajorAxis"])} km\nInclinación: ${datos["inclination"]}°"),
        ),
        _bloque(
          "DISTANCIA DESDE LA TIERRA (APROX.)",
          _textoValor(
              "${_formatearNumero(distancias["min"]!)} – ${_formatearNumero(distancias["max"]!)} km"),
        ),
        _bloque(
          "TIEMPO DE VIAJE ESTIMADO",
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _textoValor(_estimarTiempoDeViaje(promedio)),
              SizedBox(height: 3),
              Text(
                "A ${VELOCIDAD_REFERENCIA_KMS.toInt()} km/s, velocidad de referencia de una sonda interplanetaria. El tiempo real varía según la trayectoria y la misión.",
                style: TextStyle(fontSize: 9, color: Colors.white38),
              ),
            ],
          ),
        ),
        _bloque("DATO", _textoValor(conocidoDesde)),
        _bloque(
          "CURIOSIDAD",
          _cargandoHistoria
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colorVerde))
              : _textoValor(_historia ??
                  "No se encontró información adicional para este planeta."),
        ),
      ],
    );
  }

  Widget _panelTierra() {
    final datos = _datosPlaneta!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bloque("GRAVEDAD", _textoValor("${datos["gravity"]} m/s²")),
        Text("POSICIÓN ACTUAL DE LA ISS",
            style: TextStyle(
                fontSize: 9, color: Colors.white38, letterSpacing: 0.5)),
        SizedBox(height: 6),
        _mapaTierra(),
        SizedBox(height: 8),
        _cargandoISS
            ? _textoValor("Actualizando...")
            : _errorISS
                ? _textoValor("No se pudo obtener la posición de la ISS.")
                : _posicionISS != null
                    ? _textoValor(
                        "Latitud: ${(_posicionISS!["latitude"] as num).toStringAsFixed(2)}°   Longitud: ${(_posicionISS!["longitude"] as num).toStringAsFixed(2)}°\n"
                        "Altitud: ${(_posicionISS!["altitude"] as num).round()} km · Velocidad: ${_formatearNumero(_posicionISS!["velocity"])} km/h",
                      )
                    : SizedBox.shrink(),
        SizedBox(height: 12),
        GestureDetector(
          onTap: _actualizarPosicionISS,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Color(0xFF132018),
              border: Border.all(color: bordeOrbita),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              "↻ ACTUALIZAR POSICIÓN",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: colorVerde),
            ),
          ),
        ),
        SizedBox(height: 18),
        _bloque(
          "CURIOSIDAD",
          _cargandoHistoria
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colorVerde))
              : _textoValor(
                  _historia ?? "No se encontró información adicional."),
        ),
      ],
    );
  }

  Widget _mapaTierra() {
    return AspectRatio(
      aspectRatio: 2,
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF081018),
          border: Border.all(color: bordeColor),
          borderRadius: BorderRadius.circular(6),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double ancho = constraints.maxWidth;
            final double alto = constraints.maxHeight;

            final double? lat = (_posicionISS?["latitude"] as num?)?.toDouble();
            final double? lon =
                (_posicionISS?["longitude"] as num?)?.toDouble();

            return Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: alto / 2,
                  child:
                      Container(height: 1, color: colorVerde.withOpacity(0.3)),
                ),
                Positioned(
                  top: 0,
                  bottom: 0,
                  left: ancho / 2,
                  child:
                      Container(width: 1, color: colorVerde.withOpacity(0.3)),
                ),
                if (lat != null && lon != null)
                  Positioned(
                    left: ((lon + 180) / 360) * ancho - 5,
                    top: ((90 - lat) / 180) * alto - 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorAmarillo,
                        boxShadow: [
                          BoxShadow(
                              color: colorAmarillo.withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 2)
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
