import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const FinansysApp());
}

String formatearDinero(double monto) {
  double montoCerrado = (monto / 1000).floor() * 1000.0;
  final formato = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  return formato.format(montoCerrado);
}

double limpiarYConvertir(String texto) {
  String textoLimpio = texto.replaceAll('.', '').replaceAll(',', '');
  return double.tryParse(textoLimpio) ?? 0;
}

int diasRestantesDelMes() {
  DateTime ahora = DateTime.now();
  int ultimoDiaDelMes = DateTime(ahora.year, ahora.month + 1, 0).day;
  return ultimoDiaDelMes - ahora.day + 1;
}

class FinansysApp extends StatelessWidget {
  const FinansysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Finansys",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}


class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  final ingresosBaseController = TextEditingController();
  final gastosFijosController = TextEditingController();

  double ingresoBase = 0;
  double gastosFijos = 0;

  @override
  void initState() {
    super.initState();
    cargarDatosPrevios();
  }

  Future cargarDatosPrevios() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      ingresoBase = prefs.getDouble("ingresoBase") ?? 0;
      gastosFijos = prefs.getDouble("gastosFijos") ?? 0;
      
      if (ingresoBase > 0) ingresosBaseController.text = ingresoBase.toInt().toString();
      if (gastosFijos > 0) gastosFijosController.text = gastosFijos.toInt().toString();
    });
  }

  Future guardarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      ingresoBase = limpiarYConvertir(ingresosBaseController.text);
      gastosFijos = limpiarYConvertir(gastosFijosController.text);
    });

    await prefs.setDouble("ingresoBase", ingresoBase);
    await prefs.setDouble("gastosFijos", gastosFijos);

    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const DashboardPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Configuración Finansys"),
        backgroundColor: Colors.green.shade100,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.account_balance_wallet, size: 80, color: Colors.green),
            const SizedBox(height: 20),
            const Text(
              "Empecemos con tus datos fijos del mes",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            TextField(
              controller: ingresosBaseController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Salario Base Mensual",
                prefixIcon: Icon(Icons.attach_money),
                hintText: "Ej: 1300000",
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: gastosFijosController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Gastos Fijos (Arriendo, Servicios...)",
                prefixIcon: Icon(Icons.money_off),
                hintText: "Ej: 800000",
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: guardarDatos,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
              ),
              child: const Text("Entrar al Dashboard", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}


class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  double ingresoBaseMensual = 0;
  double gastosFijosMensuales = 0;
  
  double ingresosExtraDelMes = 0;
  double gastosVariablesDelMes = 0;

  double balanceDisponible = 0;
  double gastoDiarioPermitido = 0;

  String estadoFinanciero = "Equilibrio"; 
  Color colorEstado = Colors.grey; 
  double cuantoGenerarHoy = 0;

  List<Map<String, dynamic>> historialMes = [];
  List<Map<String, dynamic>> historialHoy = [];

  final List<String> categoriasGasto = ['Transporte', 'Comida', 'Ocio', 'Compras', 'Otros'];
  final List<String> categoriasIngreso = ['Salario', 'Comisión', 'Extra'];

  @override
  void initState() {
    super.initState();
    cargarDatos();
  }

  Future cargarDatos() async {
    final prefs = await SharedPreferences.getInstance();
    ingresoBaseMensual = prefs.getDouble("ingresoBase") ?? 0;
    gastosFijosMensuales = prefs.getDouble("gastosFijos") ?? 0;

    String? historialGuardado = prefs.getString("historial_movimientos");
    if (historialGuardado != null) {
      List<dynamic> decodificado = jsonDecode(historialGuardado);
      DateTime ahora = DateTime.now();
      
      historialMes = decodificado.map((e) => e as Map<String, dynamic>).where((mov) {
        DateTime fechaMov = DateTime.parse(mov['fecha']);
        return fechaMov.year == ahora.year && fechaMov.month == ahora.month;
      }).toList();

      historialHoy = historialMes.where((mov) {
        DateTime fechaMov = DateTime.parse(mov['fecha']);
        return fechaMov.day == ahora.day;
      }).toList();
    }

    recalcularDashboard();
  }

void recalcularDashboard() {
    ingresosExtraDelMes = 0;
    gastosVariablesDelMes = 0;

    double gastosAnteriores = 0;
    double ingresosAnteriores = 0;
    double gastosHoy = 0;
    double ingresosHoy = 0;

    DateTime ahora = DateTime.now();

    for (var mov in historialMes) {
      DateTime fechaMov = DateTime.parse(mov['fecha']);
      bool esHoy = fechaMov.year == ahora.year && 
                   fechaMov.month == ahora.month && 
                   fechaMov.day == ahora.day;

      if (mov['esGasto']) {
        gastosVariablesDelMes += mov['monto'];
        if (esHoy) {
          gastosHoy += mov['monto'];
        } else {
          gastosAnteriores += mov['monto'];
        }
      } else {
        ingresosExtraDelMes += mov['monto'];
        if (esHoy) {
          ingresosHoy += mov['monto'];
        } else {
          ingresosAnteriores += mov['monto'];
        }
      }
    }

    setState(() {
      // 1. CÁLCULO DEL BALANCE MENSUAL (REQ 9)
      double ingresosTotales = ingresoBaseMensual + ingresosExtraDelMes;
      double gastosTotales = gastosFijosMensuales + gastosVariablesDelMes;
      balanceDisponible = ingresosTotales - gastosTotales; // REQ 12 (Tiempo real)

      // 2. IDENTIFICAR ESTADO (REQ 10 y 15)
      if (balanceDisponible < 0) {
        estadoFinanciero = "Descuadre";
        colorEstado = Colors.red;
      } else if (balanceDisponible == 0) {
        estadoFinanciero = "Equilibrio";
        colorEstado = Colors.orange;
      } else {
        estadoFinanciero = "Excedente";
        colorEstado = Colors.green;
      }

      // 3. CÁLCULO DIARIO (REQ 11 y 14)
      int dias = diasRestantesDelMes();
      
      // Balance que había antes de los movimientos de hoy (Acumulación implícita REQ 13)
      double balanceAlDespertar = (ingresoBaseMensual + ingresosAnteriores) - (gastosFijosMensuales + gastosAnteriores);

      if (balanceDisponible < 0) {
        // En DESCUADRE: Calculamos cuánto debe generar (REQ 11)
        gastoDiarioPermitido = 0;
        // Dividimos la deuda total entre los días que quedan para que sepa cuánto "camellar" diario
        cuantoGenerarHoy = (balanceAlDespertar.abs() / dias) + gastosHoy - ingresosHoy;
        if (cuantoGenerarHoy < 0) cuantoGenerarHoy = 0;
      } else {
        // En EXCEDENTE: Calculamos cuánto puede gastar (REQ 11)
        cuantoGenerarHoy = 0;
        double baseDiaria = balanceAlDespertar / dias;
        // El ajuste automático (REQ 14) ocurre porque 'baseDiaria' cambia cada día que 'dias' disminuye
        gastoDiarioPermitido = baseDiaria - gastosHoy + ingresosHoy;
      }
    });
  }

 Future<void> eliminarMovimiento(String fechaEliminar) async {
    bool? confirmar = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar registro"),
        content: const Text("¿Estás seguro de que quieres borrar este movimiento?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      setState(() {
        historialMes.removeWhere((mov) => mov['fecha'] == fechaEliminar);
        historialHoy.removeWhere((mov) => mov['fecha'] == fechaEliminar);
      });

      final prefs = await SharedPreferences.getInstance();
      String? historialGuardado = prefs.getString("historial_movimientos");
      
      if (historialGuardado != null) {
        List<dynamic> todoElHistorial = jsonDecode(historialGuardado);
        todoElHistorial.removeWhere((mov) => mov['fecha'] == fechaEliminar);
        await prefs.setString("historial_movimientos", jsonEncode(todoElHistorial));
      }

      recalcularDashboard();
    }
  }
  Future<void> registrarMovimiento(bool esGasto) async {
    final montoController = TextEditingController();
    final descripcionController = TextEditingController();
    String categoriaSeleccionada = esGasto ? categoriasGasto.first : categoriasIngreso.first;
    
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(esGasto ? "Registrar Nuevo Gasto" : "Registrar Nuevo Ingreso"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: montoController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Monto (\$)", hintText: "Ej: 15000"),
                  ),
                  const SizedBox(height: 10),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Categoría'),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: categoriaSeleccionada,
                        isExpanded: true,
                        items: (esGasto ? categoriasGasto : categoriasIngreso).map((String cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (String? nuevaCat) {
                          setStateDialog(() {
                            categoriaSeleccionada = nuevaCat!;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descripcionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: "Descripción (Opcional)"),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'monto': montoController.text,
                      'categoria': categoriaSeleccionada,
                      'descripcion': descripcionController.text
                    });
                  },
                  child: const Text("Guardar"),
                )
              ],
            );
          },
        );
      },
    ).then((resultado) async {
      if (resultado != null) {
        double monto = limpiarYConvertir(resultado['monto']);
        String descripcion = resultado['descripcion'].toString().trim();
        String categoria = resultado['categoria'];
        
        if (descripcion.isEmpty) descripcion = categoria;

        if (monto > 0) {
          Map<String, dynamic> nuevoMovimiento = {
            'monto': monto,
            'esGasto': esGasto,
            'categoria': categoria,
            'descripcion': descripcion,
            'fecha': DateTime.now().toIso8601String(),
          };

          historialMes.insert(0, nuevoMovimiento);
          historialHoy.insert(0, nuevoMovimiento);

          final prefs = await SharedPreferences.getInstance();
          String? historialAnterior = prefs.getString("historial_movimientos");
          List<dynamic> todoElHistorial = historialAnterior != null ? jsonDecode(historialAnterior) : [];
          todoElHistorial.add(nuevoMovimiento);
          await prefs.setString("historial_movimientos", jsonEncode(todoElHistorial));

          recalcularDashboard();
        }
      }
    });
  }
@override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Finansys - Dashboard"),
        backgroundColor: Colors.green.shade100,
        actions: [
          // 1. Botón de Configuración (El que ya tenías)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ConfigPage()),
              );
            },
          ),
          // 2. ¡NUEVO! Botón de Cerrar Sesión
          IconButton(
            icon: Icon(Icons.logout, color: Colors.red.shade700),
            tooltip: "Cerrar sesión",
            onPressed: () async {
              // Le decimos a Firebase que cierre la sesión actual
              await FirebaseAuth.instance.signOut();
              
              if (!context.mounted) return;
              
              // Mandamos al usuario de vuelta a la pantalla de Login y borramos el historial
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const AuthGate()),
                (route) => false, 
              );
            },
          )
        ],
      ),
// ... De aquí para abajo sigue tu body: SingleChildScrollView normal
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
  child: Container(
    margin: const EdgeInsets.symmetric(vertical: 10),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    decoration: BoxDecoration(
      color: colorEstado.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: colorEstado, width: 2),
    ),
    child: Text(
      "ESTADO: ${estadoFinanciero.toUpperCase()}",
      style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold, fontSize: 18),
    ),
  ),
),
            const Text("Resumen del Mes", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Ingresos del mes:"), Text(formatearDinero(ingresoBaseMensual + ingresosExtraDelMes), style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
                  ]),
                  const SizedBox(height: 5),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Gastos fijos:"), Text("-${formatearDinero(gastosFijosMensuales)}", style: const TextStyle(color: Colors.red))
                  ]),
                  const SizedBox(height: 5),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Gastos registrados:"), Text("-${formatearDinero(gastosVariablesDelMes)}", style: const TextStyle(color: Colors.red))
                  ]),
                  const Divider(),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text("Balance Disponible:", style: TextStyle(fontWeight: FontWeight.bold)), 
                    Text(formatearDinero(balanceDisponible), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 25),

            Card(
              elevation: 4,
              // Aquí la magia: usa el color que calculamos en recalcularDashboard
              color: colorEstado.withOpacity(0.15), 
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      estadoFinanciero == "Descuadre" 
                          ? "Debes generar hoy para equilibrarte:" 
                          : "Dinero que puedes gastar hoy",
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                    ),
                    Text("(Quedan ${diasRestantesDelMes()} días en el mes)", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 10),
                    Text(
  // Si el gasto permitido es negativo, mostramos 0 $ para no confundir al usuario
  formatearDinero(
    estadoFinanciero == "Descuadre" 
      ? cuantoGenerarHoy 
      : (gastoDiarioPermitido < 0 ? 0 : gastoDiarioPermitido)
  ),
  style: TextStyle(
    fontSize: 38, 
    fontWeight: FontWeight.bold, 
    color: estadoFinanciero == "Descuadre" ? Colors.red : Colors.green.shade800
  ),
),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 25),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => registrarMovimiento(false),
                    icon: const Icon(Icons.add),
                    label: const Text("Ingreso"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => registrarMovimiento(true),
                    icon: const Icon(Icons.remove),
                    label: const Text("Gasto"),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15), backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text("Transacciones de Hoy", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            if (historialHoy.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No hay movimientos hoy.", style: TextStyle(color: Colors.grey))))
            else
              ...historialHoy.map((mov) {
                bool esGasto = mov['esGasto'];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: esGasto ? Colors.red.shade50 : Colors.blue.shade50,
                      child: Icon(esGasto ? Icons.money_off : Icons.attach_money, color: esGasto ? Colors.red : Colors.blue, size: 20),
                    ),
                    title: Text(mov['descripcion'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(mov['categoria']),
                    
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${esGasto ? '-' : '+'}${formatearDinero(mov['monto'])}",
                          style: TextStyle(fontWeight: FontWeight.bold, color: esGasto ? Colors.red : Colors.blue, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.grey),
                          onPressed: () => eliminarMovimiento(mov['fecha']),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
    
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
      
        if (snapshot.hasData) {
          return const DashboardPage(); 
        }
       
        return const LoginPage();
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}
class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;


  Future<void> iniciarSesion() async {
    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: Verifica tu correo y contraseña. (${e.code})")),
      );
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  
  Future<void> registrarse() async {
    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      if (!mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Cuenta creada con éxito!", style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return; 
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al registrarse: ${e.code}")),
      );
    }
    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 100, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                "Finansys",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const Text("Controla tu dinero hoy"),
              const SizedBox(height: 40),
              
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              
              TextField(
                controller: passwordController,
                obscureText: true, 
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: Icon(Icons.key),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),

              
              isLoading 
                ? const CircularProgressIndicator(color: Colors.green)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        onPressed: iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: Colors.green.shade700,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Iniciar Sesión", style: TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(height: 15),
                      TextButton(
                        onPressed: registrarse,
                        child: const Text(
                          "¿No tienes cuenta? Regístrate aquí",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
