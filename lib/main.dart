import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coffee_detail_page.dart';
import 'cart_manager.dart';
import 'models.dart';
import 'theme_helpers.dart';

// --- MODEL & MANAGER ---

class CoffeeProvider extends ChangeNotifier {
  final List<Coffee> _coffeeList = [
    Coffee(
      id: '0',
      name: 'Americano',
      price: 25000,
      description: 'Kopi kuat, hitam, dan pas untuk pagi yang sibuk.',
      imageUrl: 'lib/images/amerikano.jpg',
      stock: 12,
    ),
    Coffee(
      id: '1',
      name: 'Latte',
      price: 30000,
      description: 'Kopi susu lembut dengan busa krim yang halus.',
      imageUrl: 'lib/images/latte.jpg',
      stock: 8,
    ),
    Coffee(
      id: '2',
      name: 'Kopi Tubruk',
      price: 18000,
      description: 'Cita rasa angkringan asli, pekat, dan berani.',
      imageUrl: 'lib/images/kopitubruk.png',
      stock: 15,
    ),
  ];

  List<Coffee> get coffeeList => _coffeeList;

  void addCoffee({
    required String name,
    required int price,
    required String description,
    required int stock,
    String imageUrl = '',
  }) {
    _coffeeList.add(
      Coffee(
        id: DateTime.now().toString(),
        name: name,
        price: price,
        description: description,
        imageUrl: imageUrl,
        stock: stock,
      ),
    );
    notifyListeners();
  }

  bool reduceStock(String id, int amount) {
    final index = _coffeeList.indexWhere((coffee) => coffee.id == id);
    if (index == -1) return false;
    final coffee = _coffeeList[index];
    if (coffee.stock < amount) return false;
    _coffeeList[index] = coffee.copyWith(stock: coffee.stock - amount);
    notifyListeners();
    return true;
  }

  void updateStock(String id, int stock) {
    final index = _coffeeList.indexWhere((coffee) => coffee.id == id);
    if (index == -1) return;
    final coffee = _coffeeList[index];
    _coffeeList[index] = coffee.copyWith(stock: stock);
    notifyListeners();
  }
}

class TransactionProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final List<TransactionRecord> _records = [];

  TransactionProvider._(this._prefs) {
    _loadFromPreferences();
  }

  static Future<TransactionProvider> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return TransactionProvider._(prefs);
  }

  List<TransactionRecord> get records => List.unmodifiable(_records);

  int get totalIncome => _records
      .where((record) => record.type == 'income')
      .fold(0, (sum, record) => sum + record.total);

  int get totalExpense => _records
      .where((record) => record.type == 'expense')
      .fold(0, (sum, record) => sum + record.total);

  int get netProfit => totalIncome - totalExpense;

  void _loadFromPreferences() {
    final raw = _prefs.getString('kopishop_transactions');
    if (raw != null) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _records.addAll(
        decoded
            .map(
              (item) =>
                  TransactionRecord.fromJson(item as Map<String, dynamic>),
            )
            .toList(),
      );
    }
  }

  void _saveToPreferences() {
    _prefs.setString(
      'kopishop_transactions',
      jsonEncode(_records.map((record) => record.toJson()).toList()),
    );
  }

  void addTransaction(TransactionRecord record) {
    _records.insert(0, record);
    _saveToPreferences();
    notifyListeners();
  }
}

class UserAccount {
  final String name;
  final String email;
  final String password;

  UserAccount({
    required this.name,
    required this.email,
    required this.password,
  });

  Map<String, String> toJson() {
    return {'name': name, 'email': email, 'password': password};
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
    );
  }
}

class AuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final List<UserAccount> _accounts = [];
  UserAccount? _currentUser;

  AuthProvider._(this._prefs) {
    _loadFromPreferences();
  }

  static Future<AuthProvider> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthProvider._(prefs);
  }

  bool get isLoggedIn => _currentUser != null;
  UserAccount? get currentUser => _currentUser;

  void _loadFromPreferences() {
    final rawAccounts = _prefs.getString('kopishop_accounts');
    if (rawAccounts != null) {
      final decoded = jsonDecode(rawAccounts) as List<dynamic>;
      _accounts.addAll(
        decoded
            .map((item) => UserAccount.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    final email = _prefs.getString('kopishop_logged_email');
    if (email != null) {
      try {
        _currentUser = _accounts.firstWhere((user) => user.email == email);
      } catch (_) {
        _currentUser = null;
      }
    }
  }

  void _saveAccounts() {
    _prefs.setString(
      'kopishop_accounts',
      jsonEncode(_accounts.map((user) => user.toJson()).toList()),
    );
  }

  void _saveLoggedUser() {
    if (_currentUser != null) {
      _prefs.setString('kopishop_logged_email', _currentUser!.email);
    } else {
      _prefs.remove('kopishop_logged_email');
    }
  }

  String? register({
    required String name,
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim().toLowerCase();
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      return 'Semua bidang harus diisi.';
    }
    if (_accounts.any((account) => account.email == normalizedEmail)) {
      return 'Email sudah terdaftar.';
    }
    _accounts.add(
      UserAccount(
        name: name.trim(),
        email: normalizedEmail,
        password: password,
      ),
    );
    _saveAccounts();
    notifyListeners();
    return null;
  }

  String? login({required String email, required String password}) {
    final normalizedEmail = email.trim().toLowerCase();
    final account = _accounts.firstWhere(
      (item) => item.email == normalizedEmail,
      orElse: () => UserAccount(name: '', email: '', password: ''),
    );
    if (account.email.isEmpty) {
      return 'Akun tidak ditemukan. Silakan daftar terlebih dahulu.';
    }
    if (account.password != password) {
      return 'Kata sandi salah.';
    }
    _currentUser = account;
    _saveLoggedUser();
    notifyListeners();
    return null;
  }

  void logout() {
    _currentUser = null;
    _saveLoggedUser();
    notifyListeners();
  }

  String? updatePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    if (_currentUser == null) {
      return 'Akun tidak ditemukan.';
    }
    if (_currentUser!.password != currentPassword) {
      return 'Kata sandi saat ini salah.';
    }
    final updated = UserAccount(
      name: _currentUser!.name,
      email: _currentUser!.email,
      password: newPassword,
    );
    final index = _accounts.indexWhere((user) => user.email == updated.email);
    if (index != -1) {
      _accounts[index] = updated;
      _currentUser = updated;
      _saveAccounts();
      _saveLoggedUser();
      notifyListeners();
      return null;
    }
    return 'Terjadi kesalahan saat memperbarui kata sandi.';
  }

  String? deleteCurrentAccount() {
    if (_currentUser == null) {
      return 'Tidak ada akun untuk dihapus.';
    }
    _accounts.removeWhere((user) => user.email == _currentUser!.email);
    _currentUser = null;
    _saveAccounts();
    _saveLoggedUser();
    notifyListeners();
    return null;
  }
}

String formatRupiah(dynamic harga) {
  try {
    final price = harga is int ? harga : int.tryParse(harga.toString()) ?? 0;
    return 'Rp ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  } catch (e) {
    return 'Rp $harga';
  }
}

String formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  final day = local.day.toString().padLeft(2, '0');
  final month = monthNames[local.month - 1];
  final year = local.year;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $month $year $hour:$minute';
}

const Color kKopiBackground = Color(0xFFF5EFE6);
const Color kKopiPrimary = Color(0xFF4A3728);
const BorderRadius kKopiCardRadius = BorderRadius.all(Radius.circular(16.0));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final authProvider = await AuthProvider.initialize();
  final transactionProvider = await TransactionProvider.initialize();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => authProvider),
        ChangeNotifierProvider(create: (_) => CoffeeProvider()),
        ChangeNotifierProvider(create: (_) => transactionProvider),
      ],
      child: KopiApp(),
    ),
  );
}

class KopiApp extends StatelessWidget {
  const KopiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KopiShop Kilat',
      theme: ThemeData(
        primaryColor: kKopiPrimary,
        scaffoldBackgroundColor: kKopiBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kKopiPrimary,
          primary: kKopiPrimary,
          secondary: kKopiPrimary,
          surface: Colors.white,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: kKopiPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          surfaceTintColor: kKopiPrimary,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 6,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kKopiPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
            elevation: 4,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: kKopiPrimary,
            side: BorderSide(color: kKopiPrimary.withAlpha(217)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
            ),
          ),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          fontFamily: 'Inter',
          bodyColor: kKopiPrimary,
          displayColor: kKopiPrimary,
        ),
        useMaterial3: true,
      ),
      routes: {
        '/': (_) => SplashPage(),
        '/login': (_) => LoginPage(),
        '/register': (_) => RegisterPage(),
        '/home': (_) => HomePage(),
        '/account': (_) => AccountPage(),
        '/cart': (_) => CartPage(),
        '/history': (_) => HistoryPage(),
      },
      initialRoute: '/',
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 2), _navigateNext);
  }

  void _navigateNext() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: backgroundDecoration(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(180),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Image.asset(
                  'lib/images/logodepan.png',
                  width: 96,
                  height: 96,
                ),
              ),
              SizedBox(height: 20),
              Text(
                'KopiShop Kilat',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Sistem pesanan kopi untuk suasana angkringan.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              SizedBox(height: 30),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _onLogin() {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = authProvider.login(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.brown[700]),
      );
      return;
    }
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(decoration: backgroundDecoration()),
          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 24),
                  Icon(Icons.coffee, color: Colors.white, size: 42),
                  SizedBox(height: 24),
                  Text(
                    'Halo Kopi Lovers',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Masuk untuk menikmati suasana angkringan dan menu kopi terbaik.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  SizedBox(height: 30),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            style: TextStyle(color: Colors.brown[900]),
                            decoration: formInputDecoration(
                              label: 'Email',
                              icon: Icons.email_outlined,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Email wajib diisi';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 18),
                          TextFormField(
                            controller: _passwordController,
                            style: TextStyle(color: Colors.brown[900]),
                            decoration: formInputDecoration(
                              label: 'Kata Sandi',
                              icon: Icons.lock_outline,
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Kata sandi wajib diisi';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _onLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.brown[800],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                'Masuk',
                                style: TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/register');
                            },
                            child: Text(
                              'Belum punya akun? Daftar sekarang',
                              style: TextStyle(color: Colors.brown[800]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  void _onRegister() {
    if (!_formKey.currentState!.validate()) return;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final error = authProvider.register(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.brown[700]),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Akun berhasil dibuat. Silakan masuk.'),
        backgroundColor: Colors.brown[700],
      ),
    );
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Akun'),
        backgroundColor: Colors.brown[800],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            elevation: 10,
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buat Akun Baru',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Masukkan data agar bisa login dan menyimpan status pengguna.',
                    style: TextStyle(color: Colors.brown[700]),
                  ),
                  SizedBox(height: 24),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Lengkap',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Nama wajib diisi';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email wajib diisi';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Kata Sandi',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Kata sandi wajib diisi';
                            }
                            if (value.length < 6) {
                              return 'Kata sandi minimal 6 karakter';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _onRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.brown[800],
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              'Daftar Sekarang',
                              style: TextStyle(fontSize: 16),
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
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final coffeeProvider = Provider.of<CoffeeProvider>(context);
    final userName = authProvider.currentUser?.name ?? 'Pecinta Kopi';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.brown[800],
        title: Text('KopiShop Kilat'),
        actions: [
          IconButton(
            icon: Icon(Icons.receipt_long_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/history');
            },
          ),
          IconButton(
            icon: Icon(Icons.account_circle_outlined),
            onPressed: () {
              Navigator.pushNamed(context, '/account');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown[700],
        child: Icon(Icons.shopping_cart_outlined),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CartPage()),
          );
        },
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 16),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hai, $userName',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Temukan cita rasa kopi angkringan dan pesan cepat.',
                  style: TextStyle(fontSize: 16, color: Colors.brown[700]),
                ),
                SizedBox(height: 24),
              ],
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 24),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [Color(0xFF3E2723), Color(0xFFD7CCC8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aroma Kopi Terbaik',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Pesan menu kopi favoritmu dengan sekali ketuk.',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                Icon(
                  Icons.coffee,
                  color: Colors.white.withOpacity(0.9),
                  size: 68,
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Menu Unggulan',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(height: 16),
          ...coffeeProvider.coffeeList.map((coffee) {
            final imageAsset = coffee.imageUrl.isNotEmpty
                ? coffee.imageUrl
                : 'lib/images/kopitubruk.png';
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CoffeeDetailPage(coffee: coffee),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 18,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                      ),
                      child: Image.asset(
                        imageAsset,
                        width: 110,
                        height: 110,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              coffee.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              coffee.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.brown[700]),
                            ),
                            SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatRupiah(coffee.price),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown[800],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: coffee.stock > 0
                                        ? Colors.green[100]
                                        : Colors.red[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    coffee.stock > 0 ? 'Tersedia' : 'Habis',
                                    style: TextStyle(
                                      color: coffee.stock > 0
                                          ? Colors.green[800]
                                          : Colors.red[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          SizedBox(height: 24),
        ],
      ),
    );
  }
}

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  void _showChangePasswordDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Ubah Kata Sandi'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Kata Sandi Saat Ini'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Kata Sandi Baru'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[800],
              ),
              onPressed: () {
                final error = authProvider.updatePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error),
                      backgroundColor: Colors.brown[700],
                    ),
                  );
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Kata sandi berhasil diperbarui.')),
                );
                Navigator.pop(context);
              },
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Akun Saya'),
        backgroundColor: Colors.brown[800],
      ),
      body: user == null
          ? Center(child: Text('Tidak ada pengguna aktif.'))
          : Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${user.name}',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Email: ${user.email}',
                    style: TextStyle(fontSize: 16, color: Colors.brown[700]),
                  ),
                  SizedBox(height: 28),
                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 5,
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pengaturan Akun',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 16),
                          ListTile(
                            leading: Icon(
                              Icons.lock_outline,
                              color: Colors.brown[800],
                            ),
                            title: Text('Ubah kata sandi'),
                            onTap: _showChangePasswordDialog,
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.logout,
                              color: Colors.brown[800],
                            ),
                            title: Text('Keluar'),
                            onTap: () {
                              authProvider.logout();
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) => false,
                              );
                            },
                          ),
                          ListTile(
                            leading: Icon(
                              Icons.delete_forever,
                              color: Colors.red[700],
                            ),
                            title: Text(
                              'Hapus akun',
                              style: TextStyle(color: Colors.red[700]),
                            ),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (_) {
                                  return AlertDialog(
                                    title: Text('Hapus Akun'),
                                    content: Text(
                                      'Apakah Anda yakin ingin menghapus akun ini?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Batal'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red[700],
                                        ),
                                        onPressed: () {
                                          final error = authProvider
                                              .deleteCurrentAccount();
                                          Navigator.pop(context);
                                          if (error != null) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(error),
                                                backgroundColor:
                                                    Colors.brown[700],
                                              ),
                                            );
                                            return;
                                          }
                                          Navigator.pushNamedAndRemoveUntil(
                                            context,
                                            '/login',
                                            (route) => false,
                                          );
                                        },
                                        child: Text('Hapus'),
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  void _removeItem(String id) {
    setState(() {
      CartManager.removeFromCart(id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = CartManager.cartItems;
    final total = CartManager.totalPrice();

    return Scaffold(
      appBar: AppBar(
        title: Text('Keranjang'),
        backgroundColor: Colors.brown[800],
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Keranjang kosong. Tambahkan dulu menu kopi favoritmu.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.brown[700]),
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.only(top: 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return Card(
                        margin: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: Colors.brown[200],
                            child: Icon(
                              Icons.local_cafe,
                              color: Colors.brown[800],
                            ),
                          ),
                          title: Text(
                            item['name'] as String,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${item['quantity']} x ${formatRupiah(item['price'])}',
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              color: Colors.red[700],
                            ),
                            onPressed: () => _removeItem(item['id'] as String),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 12,
                        offset: Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total',
                            style: TextStyle(
                              color: Colors.brown[700],
                              fontSize: 14,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            formatRupiah(total),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown[800],
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PaymentPage(total: total),
                            ),
                          );
                        },
                        child: Text('Bayar', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class PaymentPage extends StatelessWidget {
  final int total;

  const PaymentPage({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode({
      'type': 'payment',
      'amount': total,
      'note': 'Pembayaran pesanan KopiShop Kilat',
      'timestamp': DateTime.now().toIso8601String(),
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Pembayaran QR'),
        backgroundColor: Colors.brown[800],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scan QR berikut untuk membayar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Center(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 240,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nominal Pembayaran',
                        style: TextStyle(
                          color: Colors.brown[700],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        formatRupiah(total),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown[900],
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Bayar melalui aplikasi bank atau e-wallet yang mendukung QRIS.',
                        style: TextStyle(color: Colors.brown[700]),
                      ),
                    ],
                  ),
                ),
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[800],
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    final items = CartManager.cartItems
                        .map(
                          (item) => TransactionItem(
                            id: item['id'] as String,
                            name: item['name'] as String,
                            price: item['price'] as int,
                            quantity: item['quantity'] as int,
                            imageUrl: item['imageUrl'] as String,
                          ),
                        )
                        .toList();

                    final coffeeProvider = Provider.of<CoffeeProvider>(
                      context,
                      listen: false,
                    );
                    final transactionProvider =
                        Provider.of<TransactionProvider>(
                          context,
                          listen: false,
                        );

                    for (var item in items) {
                      coffeeProvider.reduceStock(item.id, item.quantity);
                    }

                    final record = TransactionRecord(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      dateTime: DateTime.now(),
                      total: total,
                      type: 'income',
                      paymentMethod: 'QR Payment',
                      note: 'Pembayaran otomatis lewat QR',
                      items: items,
                    );

                    transactionProvider.addTransaction(record);
                    CartManager.clearCart();

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionSuccessPage(record: record),
                      ),
                    );
                  },
                  child: Text('Bayar Sekarang', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TransactionSuccessPage extends StatefulWidget {
  final TransactionRecord record;

  const TransactionSuccessPage({super.key, required this.record});

  @override
  State<TransactionSuccessPage> createState() => _TransactionSuccessPageState();
}

class _TransactionSuccessPageState extends State<TransactionSuccessPage> {
  final GlobalKey _receiptKey = GlobalKey();

  Future<void> _saveReceiptImage(BuildContext context) async {
    try {
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null)
        throw Exception('Gagal menangkap struk. Silakan coba lagi.');

      final ui.Image image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null) throw Exception('Gagal membentuk gambar struk.');

      final directory = await getApplicationDocumentsDirectory();
      final receiptFolder = Directory('${directory.path}/receipts');
      if (!receiptFolder.existsSync())
        receiptFolder.createSync(recursive: true);

      final file = File(
        '${receiptFolder.path}/receipt-${widget.record.id}.png',
      );
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Struk berhasil disimpan: ${file.path}'),
          backgroundColor: kKopiPrimary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan struk: ${e.toString()}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildReceiptLine(
    String label,
    String value, {
    TextStyle? valueStyle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: kKopiPrimary.withAlpha(204),
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: valueStyle ?? TextStyle(fontSize: 14, color: kKopiPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dashCount = (constraints.maxWidth / 12).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              dashCount,
              (_) => Container(
                width: 6,
                height: 1,
                color: kKopiPrimary.withAlpha(89),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Pembayaran Berhasil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transaksi berhasil disimpan.',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: kKopiPrimary,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Terima kasih telah menggunakan KopiShop Kilat. Struk transaksi Anda siap dilihat.',
                style: TextStyle(
                  fontSize: 15,
                  color: kKopiPrimary.withAlpha(204),
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24),

              RepaintBoundary(
                key: _receiptKey,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Struk',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kKopiPrimary,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'KopiShop Kilat',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: kKopiPrimary.withAlpha(191),
                        ),
                      ),
                      SizedBox(height: 18),
                      _buildReceiptLine('Nomor Transaksi', widget.record.id),
                      _buildReceiptLine(
                        'Metode Pembayaran',
                        widget.record.paymentMethod,
                      ),
                      _buildReceiptLine(
                        'Jumlah Item',
                        widget.record.items.length.toString(),
                      ),
                      _buildDashedDivider(),
                      _buildReceiptLine(
                        'Total Bayar',
                        formatRupiah(widget.record.total),
                        valueStyle: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: kKopiPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        formatRupiah(widget.record.total),
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: kKopiPrimary,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Terbit: ${formatDateTime(widget.record.dateTime)}',
                        style: TextStyle(
                          fontSize: 13,
                          color: kKopiPrimary.withAlpha(179),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 24),
              Text(
                'Detail Item',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: kKopiPrimary,
                ),
              ),
              SizedBox(height: 12),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 14,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: widget.record.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18.0,
                        vertical: 14.0,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: kKopiPrimary,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '${item.quantity} x ${formatRupiah(item.price)}',
                                  style: TextStyle(
                                    color: kKopiPrimary.withAlpha(179),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            formatRupiah(item.total),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: kKopiPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.download),
                      label: Text('Unduh Struk'),
                      onPressed: () => _saveReceiptImage(context),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/history',
                        (route) => false,
                      ),
                      child: Text('Lihat Histori'),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: kKopiPrimary,
                  side: BorderSide(color: kKopiPrimary.withAlpha(38)),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                ),
                child: Text('Kembali ke Menu Utama'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _expenseController = TextEditingController();
  final _noteController = TextEditingController();

  void _showAddExpenseDialog(TransactionProvider provider) {
    _expenseController.clear();
    _noteController.clear();

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Catat Pengeluaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _expenseController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Nominal Pengeluaran'),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(labelText: 'Catatan'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.brown[800],
              ),
              onPressed: () {
                final amount =
                    int.tryParse(_expenseController.text.replaceAll('.', '')) ??
                    0;
                final note = _noteController.text.trim();
                if (amount <= 0) return;

                provider.addTransaction(
                  TransactionRecord(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    dateTime: DateTime.now(),
                    total: amount,
                    type: 'expense',
                    paymentMethod: 'Manual',
                    note: note.isEmpty ? 'Pengeluaran toko' : note,
                    items: [],
                  ),
                );
                Navigator.pop(context);
              },
              child: Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final records = provider.records;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Histori Transaksi'),
        backgroundColor: Colors.brown[800],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.brown[800],
        child: Icon(Icons.add),
        onPressed: () => _showAddExpenseDialog(provider),
      ),
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.brown[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.brown[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ringkasan',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pendapatan',
                        style: TextStyle(color: Colors.brown[700]),
                      ),
                      Text(
                        formatRupiah(provider.totalIncome),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pengeluaran',
                        style: TextStyle(color: Colors.brown[700]),
                      ),
                      Text(
                        formatRupiah(provider.totalExpense),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Divider(color: Colors.brown[200]),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Laba Bersih',
                        style: TextStyle(
                          color: Colors.brown[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        formatRupiah(provider.netProfit),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[800],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Expanded(
              child: records.isEmpty
                  ? Center(child: Text('Belum ada transaksi.'))
                  : ListView.builder(
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.all(16),
                            title: Text(
                              '${record.type == 'income' ? 'Penjualan' : 'Pengeluaran'} - ${formatRupiah(record.total)}',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 8),
                                Text(record.note),
                                SizedBox(height: 4),
                                Text('Metode: ${record.paymentMethod}'),
                                SizedBox(height: 4),
                                Text('Tanggal: ${record.dateTime.toLocal()}'),
                              ],
                            ),
                            trailing: CircleAvatar(
                              backgroundColor: record.type == 'income'
                                  ? Colors.green[100]
                                  : Colors.red[100],
                              child: Icon(
                                record.type == 'income'
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color: record.type == 'income'
                                    ? Colors.green[800]
                                    : Colors.red[800],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
