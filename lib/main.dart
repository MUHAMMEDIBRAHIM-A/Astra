// main.dart - Complete ASTRA App with Fixed Employee Addition
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'dart:async';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart' show Uuid;
// ============================================================
// THEME CONFIGURATION
// ============================================================
class AppTheme {
  static const Color primaryGreen = Color(0xFF1B8A3D);
  static const Color lightGreen = Color(0xFF4CAF50);
  static const Color softGreen = Color(0xFFE8F5E9);
  static const Color darkGreen = Color(0xFF0D5C2E);
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF7FAF7);
  static const Color greyText = Color(0xFF6B7A6B);
  static const Color darkText = Color(0xFF1A2E1A);
  static const Color golden = Color(0xFFFFD700);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: primaryGreen,
    scaffoldBackgroundColor: offWhite,
    fontFamily: 'Poppins',
    colorScheme: const ColorScheme.light(
      primary: primaryGreen,
      secondary: lightGreen,
      surface: white,
      error: Color(0xFFD32F2F),
      onPrimary: white,
      onSecondary: white,
      onSurface: darkText,
      onError: white,
    ),
  );
}

// ============================================================
// MODELS
// ============================================================
class Product {
  final String id;
  final String name;
  final double price;
  final double? originalPrice;
  final String unit;
  final String imageUrl;
  final String farmerName;
  final String farmerId;
  final double rating;
  final int reviews;
  final bool isOrganic;
  final bool isFresh;
  final bool isFeatured;
  final bool isOnSale;
  final int stock;
  final String description;
  final String category;
  final List<String>? images;

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.unit,
    required this.imageUrl,
    required this.farmerName,
    required this.farmerId,
    required this.rating,
    required this.reviews,
    required this.isOrganic,
    required this.isFresh,
    this.isFeatured = false,
    this.isOnSale = false,
    required this.stock,
    required this.description,
    this.category = 'Vegetables',
    this.images,
  });

  double get discountPercentage {
    if (originalPrice == null || originalPrice! <= price) return 0;
    return ((originalPrice! - price) / originalPrice! * 100).roundToDouble();
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      originalPrice: map['original_price']?.toDouble(),
      unit: map['unit'] ?? 'kg',
      imageUrl: map['image_path'] ?? map['imageUrl'] ?? '',
      farmerName: map['farmer_name'] ?? map['farmerName'] ?? '',
      farmerId: map['farmer_id'] ?? map['farmerId'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      reviews: map['reviews'] ?? 0,
      isOrganic: map['is_organic'] == 1 || map['isOrganic'] == true,
      isFresh: map['is_fresh'] == 1 || map['isFresh'] == true,
      isFeatured: map['is_featured'] == 1 || map['isFeatured'] == true,
      isOnSale: map['is_on_sale'] == 1 || map['isOnSale'] == true,
      stock: map['stock'] ?? 0,
      description: map['description'] ?? '',
      category: map['category'] ?? 'Vegetables',
      images: map['images'] != null ? List<String>.from(map['images']) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'original_price': originalPrice,
      'unit': unit,
      'image_path': imageUrl,
      'farmer_name': farmerName,
      'farmer_id': farmerId,
      'rating': rating,
      'reviews': reviews,
      'is_organic': isOrganic ? 1 : 0,
      'is_fresh': isFresh ? 1 : 0,
      'is_featured': isFeatured ? 1 : 0,
      'is_on_sale': isOnSale ? 1 : 0,
      'stock': stock,
      'description': description,
      'category': category,
      'images': images,
    };
  }
}

class CartItem {
  final String productId;
  final String productName;
  final double price;
  int quantity;
  final String unit;
  final String imageUrl;
  final bool isOrganic;

  CartItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.unit,
    required this.imageUrl,
    this.isOrganic = false,
  });

  double get total => price * quantity;

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'unit': unit,
      'image_path': imageUrl,
      'is_organic': isOrganic ? 1 : 0,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['product_id'] ?? '',
      productName: map['product_name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      quantity: map['quantity'] ?? 1,
      unit: map['unit'] ?? 'kg',
      imageUrl: map['image_path'] ?? '',
      isOrganic: map['is_organic'] == 1,
    );
  }
}

// ============================================================
// DATABASE HELPER
// ============================================================
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = path.join(documentsDirectory.path, 'astra_products.db');

    return await openDatabase(
      dbPath,
      version: 6,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        original_price REAL,
        unit TEXT NOT NULL,
        category TEXT NOT NULL,
        description TEXT,
        farmer_name TEXT NOT NULL,
        farmer_id TEXT NOT NULL,
        rating REAL DEFAULT 0,
        reviews INTEGER DEFAULT 0,
        is_organic INTEGER DEFAULT 0,
        is_fresh INTEGER DEFAULT 1,
        is_featured INTEGER DEFAULT 0,
        is_on_sale INTEGER DEFAULT 0,
        stock INTEGER DEFAULT 0,
        image_path TEXT,
        images TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL UNIQUE,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        image_path TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE cart (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER DEFAULT 1,
        unit TEXT NOT NULL,
        image_path TEXT,
        is_organic INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT DEFAULT 'Pending',
        delivery_address TEXT,
        payment_method TEXT,
        order_date TEXT,
        items TEXT,
        delivery_notes TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS favorites (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          product_id TEXT NOT NULL UNIQUE,
          product_name TEXT NOT NULL,
          price REAL NOT NULL,
          image_path TEXT
        )
      ''');
    } catch (e) {
      debugPrint('Error with favorites table: $e');
    }

    if (oldVersion < 2) {
      await db.execute('ALTER TABLE products ADD COLUMN is_fresh INTEGER DEFAULT 1');
    }
    if (oldVersion < 4) {
      try {
        await db.execute('ALTER TABLE products ADD COLUMN is_featured INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE products ADD COLUMN is_on_sale INTEGER DEFAULT 0');
        await db.execute('ALTER TABLE products ADD COLUMN original_price REAL');
        await db.execute('ALTER TABLE products ADD COLUMN images TEXT');
      } catch (e) {
        debugPrint('Error upgrading to version 4: $e');
      }
    }
  }

  // ==================== FAVORITES ====================
  Future<int> addFavorite(Map<String, dynamic> favorite) async {
    final db = await database;
    try {
      final existing = await db.query(
        'favorites',
        where: 'product_id = ?',
        whereArgs: [favorite['product_id']],
      );
      if (existing.isNotEmpty) return 0;
      return await db.insert('favorites', favorite);
    } catch (e) {
      debugPrint('Error adding favorite: $e');
      return 0;
    }
  }

  Future<int> removeFavorite(String productId) async {
    final db = await database;
    try {
      return await db.delete(
        'favorites',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    try {
      return await db.query('favorites', orderBy: 'product_name');
    } catch (e) {
      debugPrint('Error getting favorites: $e');
      return [];
    }
  }

  Future<bool> isFavorite(String productId) async {
    final db = await database;
    try {
      final result = await db.query(
        'favorites',
        where: 'product_id = ?',
        whereArgs: [productId],
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      return false;
    }
  }

  // ==================== PRODUCTS ====================
  Future<int> insertProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.insert('products', product,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getAllProducts() async {
    final db = await database;
    return await db.query('products', orderBy: 'name');
  }

  Future<List<Map<String, dynamic>>> getFeaturedProducts() async {
    final db = await database;
    return await db.query(
      'products',
      where: 'is_featured = 1',
      orderBy: 'rating DESC',
      limit: 6,
    );
  }

  Future<Map<String, dynamic>?> getProduct(String id) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    return result.isNotEmpty ? result.first : null;
  }

  Future<int> deleteProduct(String id) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateProduct(Map<String, dynamic> product) async {
    final db = await database;
    return await db.update(
      'products',
      product,
      where: 'id = ?',
      whereArgs: [product['id']],
    );
  }

  // ==================== CART ====================
  Future<int> addToCart(Map<String, dynamic> cartItem) async {
    final db = await database;
    final existing = await db.query(
      'cart',
      where: 'product_id = ?',
      whereArgs: [cartItem['product_id']],
    );
    if (existing.isNotEmpty) {
      int newQuantity = (existing.first['quantity'] as int) + 1;
      return await db.update(
        'cart',
        {'quantity': newQuantity},
        where: 'product_id = ?',
        whereArgs: [cartItem['product_id']],
      );
    }
    return await db.insert('cart', cartItem);
  }

  Future<List<Map<String, dynamic>>> getCartItems() async {
    final db = await database;
    return await db.query('cart', orderBy: 'product_name');
  }

  Future<int> updateCartQuantity(String productId, int quantity) async {
    final db = await database;
    if (quantity <= 0) {
      return await removeFromCart(productId);
    }
    return await db.update(
      'cart',
      {'quantity': quantity},
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> removeFromCart(String productId) async {
    final db = await database;
    return await db.delete(
      'cart',
      where: 'product_id = ?',
      whereArgs: [productId],
    );
  }

  Future<int> clearCart() async {
    final db = await database;
    return await db.delete('cart');
  }

  Future<double> getCartTotal() async {
    final items = await getCartItems();
    double total = 0;
    for (var item in items) {
      total += (item['price'] as double) * (item['quantity'] as int);
    }
    return total;
  }

  // ==================== ORDERS ====================
  Future<int> insertOrder(Map<String, dynamic> order) async {
    final db = await database;
    return await db.insert('orders', order);
  }

  Future<List<Map<String, dynamic>>> getAllOrders() async {
    final db = await database;
    return await db.query('orders', orderBy: 'order_date DESC');
  }

  Future<List<Map<String, dynamic>>> getOrdersByUser(String userId) async {
    final db = await database;
    return await db.query(
      'orders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'order_date DESC',
    );
  }

  Future<int> updateOrderStatus(String orderId, String status) async {
    final db = await database;
    return await db.update(
      'orders',
      {'status': status},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  // ==================== SAMPLE DATA ====================
  Future<void> insertSampleData() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products')
    );
    if (count != null && count > 0) return;

    final products = [
      {
        'id': 'p1',
        'name': 'Fresh Organic Tomatoes',
        'price': 40.0,
        'original_price': 50.0,
        'unit': 'kg',
        'category': 'Vegetables',
        'description': 'Fresh farm tomatoes grown organically without pesticides.',
        'farmer_name': 'Green Valley Farms',
        'farmer_id': 'f1',
        'rating': 4.8,
        'reviews': 156,
        'is_organic': 1,
        'is_fresh': 1,
        'is_featured': 1,
        'is_on_sale': 1,
        'stock': 50,
        'image_path': '',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'p2',
        'name': 'Premium Organic Carrots',
        'price': 35.0,
        'unit': 'kg',
        'category': 'Vegetables',
        'description': 'Sweet and crunchy carrots from organic farms.',
        'farmer_name': 'Sunshine Organics',
        'farmer_id': 'f2',
        'rating': 4.7,
        'reviews': 89,
        'is_organic': 1,
        'is_fresh': 1,
        'is_featured': 1,
        'is_on_sale': 0,
        'stock': 30,
        'image_path': '',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'p3',
        'name': 'Fresh Spinach Bundle',
        'price': 25.0,
        'unit': 'bunch',
        'category': 'Vegetables',
        'description': 'Fresh spinach leaves, perfect for salads.',
        'farmer_name': 'Green Leaf Farms',
        'farmer_id': 'f1',
        'rating': 4.6,
        'reviews': 67,
        'is_organic': 0,
        'is_fresh': 1,
        'is_featured': 0,
        'is_on_sale': 0,
        'stock': 20,
        'image_path': '',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'p4',
        'name': 'Organic Apples',
        'price': 120.0,
        'original_price': 150.0,
        'unit': 'kg',
        'category': 'Fruits',
        'description': 'Crisp and juicy organic apples.',
        'farmer_name': 'Apple Orchard Co.',
        'farmer_id': 'f2',
        'rating': 4.9,
        'reviews': 234,
        'is_organic': 1,
        'is_fresh': 1,
        'is_featured': 1,
        'is_on_sale': 1,
        'stock': 80,
        'image_path': '',
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'p5',
        'name': 'Fresh Broccoli',
        'price': 60.0,
        'unit': 'kg',
        'category': 'Vegetables',
        'description': 'Fresh broccoli heads, rich in nutrients.',
        'farmer_name': 'Fresh Harvest Co.',
        'farmer_id': 'f3',
        'rating': 4.5,
        'reviews': 45,
        'is_organic': 0,
        'is_fresh': 1,
        'is_featured': 0,
        'is_on_sale': 0,
        'stock': 40,
        'image_path': '',
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (var product in products) {
      await insertProduct(product);
    }
  }
}

// ============================================================
// AUTH SERVICE - FIXED EMPLOYEE ADDITION
// ============================================================
// ============================================================
// AUTH SERVICE - FULLY FIXED
// ============================================================
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ✅ FIXED signIn
  Future<UserData?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // Pigeon bug — login succeeded but result.user crashes
      // Check if actually logged in
      if (!e.toString().contains('PigeonUserDetails') &&
          !e.toString().contains('List<Object?>')) {
        rethrow; // Real error — rethrow
      }
    }

    // currentUser use பண்ணு — result.user இல்ல
    await Future.delayed(const Duration(milliseconds: 500));
    final user = _auth.currentUser;
    if (user == null) throw Exception('Login failed. Try again.');

    String role = await _getUserRole(user);
    return UserData(user: user, role: role);
  }

  // ✅ FIXED signUp
  Future<UserData?> signUp(
      String email, String password, String name, String phone) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (!e.toString().contains('PigeonUserDetails') &&
          !e.toString().contains('List<Object?>')) {
        rethrow;
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    final user = _auth.currentUser;
    if (user == null) throw Exception('Registration failed. Try again.');

    try {
      await user.updateDisplayName(name);
    } catch (_) {}

    String role = 'user';
    if (email == 'admin@astra.com' || email == '123@gmail.com') {
      role = 'admin';
    }

    await _firestore.collection('users').doc(user.uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
      'profileImage': '',
      'bio': '',
      'address': '',
      'isVerified': false,
    });

    return UserData(user: user, role: role);
  }

  // ✅ FIXED addEmployee
  Future<bool> addEmployee(
      String email, String password, String name, String phone) async {
    // Save current admin user uid before creating employee
    final adminUid = _auth.currentUser?.uid;

    try {
      // Check already exists
      final snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();
      if (snapshot.docs.isNotEmpty) {
        debugPrint('Employee already exists');
        return false;
      }
    } catch (_) {}

    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return false;
      rethrow;
    } catch (e) {
      if (!e.toString().contains('PigeonUserDetails') &&
          !e.toString().contains('List<Object?>')) {
        rethrow;
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));
    final newUser = _auth.currentUser;
    if (newUser == null) return false;

    try {
      await newUser.updateDisplayName(name);
    } catch (_) {}

    // Save employee to Firestore
    await _firestore.collection('users').doc(newUser.uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'role': 'employee',
      'status': 'active',
      'created_at': DateTime.now().toIso8601String(),
      'profileImage': '',
      'bio': '',
      'address': '',
      'isVerified': true,
      'addedBy': adminUid ?? 'admin',
    });

    // ⚠️ IMPORTANT: Employee add பண்ணிட்டா
    // admin logout ஆயிடுவாங்க — admin-ஐ மீண்டும் login பண்ணு
    // Admin credentials store பண்ணி re-login பண்ண option கொடு
    debugPrint('Employee added: $email');
    return true;
  }

  Future<String> _getUserRole(User user) async {
    try {
      final doc =
      await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['role'] ?? 'user';
      }
      // Email based fallback
      if (user.email == 'admin@astra.com' ||
          user.email == '123@gmail.com') {
        return 'admin';
      }
      return 'user';
    } catch (_) {
      return 'user';
    }
  }

  Future<List<Map<String, dynamic>>> getEmployees() async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {'id': doc.id, ...data};
      }).toList();
    } catch (e) {
      debugPrint('Error getting employees: $e');
      return [];
    }
  }

  Future<bool> deleteEmployee(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting employee: $e');
      return false;
    }
  }

  Future<bool> updateProfile(
      String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(userId).update(data);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final doc =
      await _firestore.collection('users').doc(userId).get();
      if (doc.exists) return doc.data() as Map<String, dynamic>;
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async => await _auth.signOut();
  User? get currentUser => _auth.currentUser;
}
class UserData {
  final User? user;
  final String role;
  UserData({required this.user, required this.role});
}

bool isAdmin() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final email = user.email ?? '';
  return email == 'admin@astra.com' || email == '123@gmail.com';
}

bool isEmployee() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final email = user.email ?? '';
  return email.contains('@') && !isAdmin() && user.email != 'admin@astra.com' && user.email != '123@gmail.com';
}

// ============================================================
// WIDGETS
// ============================================================
class GlassmorphismCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const GlassmorphismCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isLoading;
  final double? width;

  const GradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white,
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              text,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  color: Colors.white
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductImageWidget extends StatelessWidget {
  final String imagePath;
  final double width;
  final double height;
  final BoxFit fit;

  const ProductImageWidget({
    super.key,
    required this.imagePath,
    this.width = double.infinity,
    this.height = 120,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: AppTheme.softGreen,
        child: const Icon(
          Icons.agriculture,
          size: 40,
          color: AppTheme.primaryGreen,
        ),
      );
    }
    if (imagePath.startsWith('assets/')) {
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => Container(
          width: width,
          height: height,
          color: AppTheme.softGreen,
          child: const Icon(Icons.image_not_supported, size: 30, color: AppTheme.greyText),
        ),
      );
    }
    return Image.file(
      File(imagePath),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: AppTheme.softGreen,
        child: const Icon(Icons.image_not_supported, size: 30, color: AppTheme.greyText),
      ),
    );
  }
}

// ============================================================
// SPLASH SCREEN
// ============================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..forward();

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, '/welcome');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primaryGreen, AppTheme.lightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                    ),
                    child: const Icon(Icons.eco, size: 70, color: Colors.white),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'ASTRA',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Fresh from Farm to Table',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        letterSpacing: 1,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
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

// ============================================================
// WELCOME SCREEN
// ============================================================
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkGreen, AppTheme.primaryGreen, AppTheme.lightGreen],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
                    ),
                  child: const Icon(Icons.eco, size: 72, color: Colors.white),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to ASTRA',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fresh Vegetables & Fruits\nDirectly from Farmers to Your Table',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontFamily: 'Poppins',
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 48),
                GradientButton(
                  text: 'Get Started',
                  icon: Icons.arrow_forward,
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: const Text(
                    'Create New Account',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5),
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ...List.generate(3, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == 0 ? Colors.white : Colors.white.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// LOGIN SCREEN
// ============================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      UserData? userData = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (userData != null) {
        final role = userData.role;
        if (role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else if (role == 'employee') {
          Navigator.pushReplacementNamed(context, '/employee');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Welcome Back',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.darkText),
              ),
              const SizedBox(height: 6),
              const Text(
                'Login to continue your fresh journey',
                style: TextStyle(fontSize: 15, color: AppTheme.greyText),
              ),
              const SizedBox(height: 32),
              GlassmorphismCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'you@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text('Forgot Password?', style: TextStyle(color: AppTheme.primaryGreen)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(text: 'Login', isLoading: _isLoading, onPressed: _login),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?", style: TextStyle(fontFamily: 'Poppins')),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/signup'),
                    child: const Text('Sign Up', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
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

// ============================================================
// SIGNUP SCREEN
// ============================================================
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _agreeTerms = false;

  void _signup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields'), backgroundColor: AppTheme.primaryGreen),
      );
      return;
    }
    if (!_agreeTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the terms'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      UserData? userData = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text.trim(),
        _nameController.text.trim(),
        _phoneController.text.trim(),
      );
      if (userData != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully!'), backgroundColor: AppTheme.primaryGreen),
        );
        if (userData.role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin');
        } else {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signup failed: ${e.toString()}'), backgroundColor: Colors.red.shade400),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.darkText),
              ),
              const SizedBox(height: 6),
              const Text(
                'Join the ASTRA community today',
                style: TextStyle(fontSize: 15, color: AppTheme.greyText),
              ),
              const SizedBox(height: 28),
              GlassmorphismCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outlined),
                        hintText: 'John Doe',
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                        hintText: 'john@example.com',
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        hintText: '+91 98765 43210',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        hintText: '••••••••',
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Checkbox(
                          value: _agreeTerms,
                          onChanged: (value) => setState(() => _agreeTerms = value!),
                          activeColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        Expanded(
                          child: Text(
                            'I agree to the Terms & Conditions and Privacy Policy',
                            style: TextStyle(fontSize: 12, color: AppTheme.greyText),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              GradientButton(text: 'Create Account', isLoading: _isLoading, onPressed: _signup),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account?', style: TextStyle(fontFamily: 'Poppins')),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    child: const Text('Login', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
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

// ============================================================
// HOME SCREEN
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();
  final List<String> categories = ['All', 'Vegetables', 'Fruits', 'Organic', 'Featured'];
  String selectedCategory = 'All';
  int _selectedIndex = 0;
  List<Product> _products = [];
  List<Product> _featuredProducts = [];
  List<String> _favorites = [];
  bool _isLoading = true;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _db.getAllProducts();
      final featured = await _db.getFeaturedProducts();
      final favorites = await _db.getFavorites();
      setState(() {
        _products = products.map((e) => Product.fromMap(e)).toList();
        _featuredProducts = featured.map((e) => Product.fromMap(e)).toList();
        _favorites = favorites.map((e) => e['product_id'] as String).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading data: $e');
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    try {
      final isFav = await _db.isFavorite(product.id);
      if (isFav) {
        await _db.removeFavorite(product.id);
        setState(() => _favorites.remove(product.id));
      } else {
        await _db.addFavorite({
          'product_id': product.id,
          'product_name': product.name,
          'price': product.price,
          'image_path': product.imageUrl,
        });
        setState(() => _favorites.add(product.id));
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  void _addToCart(Product product) async {
    try {
      await _db.addToCart({
        'product_id': product.id,
        'product_name': product.name,
        'price': product.price,
        'quantity': 1,
        'unit': product.unit,
        'image_path': product.imageUrl,
        'is_organic': product.isOrganic ? 1 : 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart! 🛒'), backgroundColor: AppTheme.primaryGreen, duration: Duration(seconds: 1)),
      );
    } catch (e) {
      debugPrint('Error adding to cart: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 12),
            _buildBannerSlider(),
            const SizedBox(height: 16),
            _buildCategorySection(),
            const SizedBox(height: 16),
            if (_featuredProducts.isNotEmpty) _buildFeaturedSection(),
            const SizedBox(height: 16),
            _buildProductGrid(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.lightGreen]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.eco, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 8),
          const Text('ASTRA'),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.pushNamed(context, '/profile'),
          style: IconButton.styleFrom(backgroundColor: AppTheme.softGreen),
        ),
        IconButton(
          icon: const Icon(Icons.favorite_border),
          onPressed: () => Navigator.pushNamed(context, '/favorites'),
          style: IconButton.styleFrom(backgroundColor: AppTheme.softGreen),
        ),
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => Navigator.pushNamed(context, '/cart'),
          style: IconButton.styleFrom(backgroundColor: AppTheme.softGreen),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              _authService.signOut();
              Navigator.pushReplacementNamed(context, '/welcome');
            } else if (value == 'admin' && isAdmin()) {
              Navigator.pushNamed(context, '/admin');
            } else if (value == 'employee' && isEmployee()) {
              Navigator.pushNamed(context, '/employee');
            }
          },
          itemBuilder: (context) => [
            if (isAdmin()) const PopupMenuItem(value: 'admin', child: Text('Admin Panel')),
            if (isEmployee()) const PopupMenuItem(value: 'employee', child: Text('Employee Panel')),
            const PopupMenuItem(value: 'profile', child: Text('Profile')),
            const PopupMenuItem(value: 'logout', child: Text('Logout')),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassmorphismCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: const TextField(
          decoration: InputDecoration(
            hintText: 'Search fresh vegetables...',
            hintStyle: TextStyle(color: AppTheme.greyText),
            prefixIcon: Icon(Icons.search, color: AppTheme.greyText),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerSlider() {
    return CarouselSlider(
      options: CarouselOptions(
        height: 130,
        autoPlay: true,
        enlargeCenterPage: true,
        viewportFraction: 0.92,
        autoPlayInterval: const Duration(seconds: 4),
      ),
      items: [
        _buildBannerItem('Fresh from Farm', 'Directly to your doorstep', AppTheme.darkGreen),
        _buildBannerItem('100% Organic', 'Pesticide-free produce', AppTheme.primaryGreen),
        _buildBannerItem('Seasonal Harvest', 'Best prices of the season', AppTheme.lightGreen),
      ],
    );
  }

  Widget _buildBannerItem(String title, String subtitle, Color color) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.7)]),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.eco, size: 30, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return GestureDetector(
                onTap: () => setState(() => selectedCategory = category),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selectedCategory == category ? AppTheme.primaryGreen : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selectedCategory == category ? AppTheme.primaryGreen : Colors.grey.shade300),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selectedCategory == category ? FontWeight.w600 : FontWeight.w400,
                      color: selectedCategory == category ? Colors.white : AppTheme.greyText,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('🔥 Featured Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _featuredProducts.length,
            itemBuilder: (context, index) {
              final product = _featuredProducts[index];
              return _buildSmallProductCard(product);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSmallProductCard(Product product) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/product_details', arguments: product),
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              child: ProductImageWidget(imagePath: product.imageUrl, height: 90, width: double.infinity),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1),
                  const SizedBox(height: 2),
                  Text('₹${product.price}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid() {
    final filtered = selectedCategory == 'All'
        ? _products
        : selectedCategory == 'Featured'
        ? _products.where((p) => p.isFeatured).toList()
        : _products.where((p) => p.category == selectedCategory).toList();

    if (filtered.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No products found')));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(selectedCategory == 'All' ? 'All Products' : selectedCategory,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text('${filtered.length} items', style: const TextStyle(fontSize: 13, color: AppTheme.greyText)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.7,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final product = filtered[index];
            return _buildProductCard(product);
          },
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final isFavorite = _favorites.contains(product.id);
    final isOnSale = product.isOnSale && product.originalPrice != null;

    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/product_details', arguments: product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                  child: ProductImageWidget(imagePath: product.imageUrl, height: 110, width: double.infinity),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () => _toggleFavorite(product),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, size: 16, color: isFavorite ? Colors.red : Colors.grey),
                    ),
                  ),
                ),
                if (isOnSale)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                      child: Text('${product.discountPercentage.round()}% OFF', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (product.isOrganic)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(6)),
                      child: const Text('Organic', style: TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.w600)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1),
                  const SizedBox(height: 2),
                  Text(product.farmerName, style: const TextStyle(fontSize: 10, color: AppTheme.greyText), maxLines: 1),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 10, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(product.rating.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text('(${product.reviews})', style: const TextStyle(fontSize: 8, color: AppTheme.greyText)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₹${product.price}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                          if (product.originalPrice != null)
                            Text('₹${product.originalPrice}', style: const TextStyle(fontSize: 8, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _addToCart(product),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add, size: 14, color: Colors.white),
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
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppTheme.primaryGreen,
        unselectedItemColor: AppTheme.greyText,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 0) {
            // Home
          } else if (index == 1) {
            // Search
          } else if (index == 2) {
            Navigator.pushNamed(context, '/favorites');
          } else if (index == 3) {
            Navigator.pushNamed(context, '/profile');
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search_outlined), activeIcon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outlined), activeIcon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================
// PROFILE SCREEN
// ============================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  String? _profileImagePath;
  String? _userEmail;
  String? _userRole;
  bool _isLoading = true;
  bool _isEditing = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final profile = await _authService.getUserProfile(user.uid);
      setState(() {
        _userEmail = user.email ?? '';
        if (profile != null) {
          _nameController.text = profile['name'] ?? '';
          _phoneController.text = profile['phone'] ?? '';
          _bioController.text = profile['bio'] ?? '';
          _addressController.text = profile['address'] ?? '';
          _profileImagePath = profile['profileImage'] ?? '';
          _userRole = profile['role'] ?? 'user';
        }
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _profileImagePath = image.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final data = {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'address': _addressController.text.trim(),
        'profileImage': _profileImagePath ?? '',
        'updated_at': DateTime.now().toIso8601String(),
      };

      final success = await _authService.updateProfile(user.uid, data);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppTheme.primaryGreen),
        );
        setState(() => _isEditing = false);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update profile'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            TextButton(
              onPressed: () => setState(() => _isEditing = true),
              child: const Text('Edit', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
            ),
          if (_isEditing)
            TextButton(
              onPressed: () {
                setState(() => _isEditing = false);
                _loadProfile();
              },
              child: const Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Image
            GestureDetector(
              onTap: _isEditing ? _pickImage : null,
              child: Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryGreen, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _profileImagePath != null && _profileImagePath!.isNotEmpty
                          ? (File(_profileImagePath!).existsSync()
                          ? Image.file(File(_profileImagePath!), fit: BoxFit.cover)
                          : const Icon(Icons.person, size: 50, color: AppTheme.greyText))
                          : const Icon(Icons.person, size: 50, color: AppTheme.greyText),
                    ),
                  ),
                  if (_isEditing)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Name
            GlassmorphismCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoTile(
                    icon: Icons.person_outline,
                    label: 'Name',
                    value: _nameController.text,
                    isEditing: _isEditing,
                    controller: _nameController,
                  ),
                  const Divider(),
                  _buildInfoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: _userEmail ?? '',
                    isEditing: false,
                  ),
                  const Divider(),
                  _buildInfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: _phoneController.text,
                    isEditing: _isEditing,
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                  ),
                  const Divider(),
                  _buildInfoTile(
                    icon: Icons.assignment_ind,
                    label: 'Role',
                    value: _userRole ?? 'User',
                    isEditing: false,
                    isChip: true,
                  ),
                  const Divider(),
                  _buildInfoTile(
                    icon: Icons.info_outline,
                    label: 'Bio',
                    value: _bioController.text,
                    isEditing: _isEditing,
                    controller: _bioController,
                    maxLines: 2,
                  ),
                  const Divider(),
                  _buildInfoTile(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: _addressController.text,
                    isEditing: _isEditing,
                    controller: _addressController,
                    maxLines: 2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (_isEditing)
              GradientButton(
                text: 'Save Profile',
                icon: Icons.save,
                onPressed: _saveProfile,
                isLoading: _isLoading,
              ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () {
                _authService.signOut();
                Navigator.pushReplacementNamed(context, '/welcome');
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String label,
    required String value,
    bool isEditing = false,
    TextEditingController? controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool isChip = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.greyText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.greyText, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              if (isEditing && controller != null)
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                )
              else if (isChip)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: value == 'admin' ? AppTheme.softGreen : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    value.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: value == 'admin' ? AppTheme.primaryGreen : AppTheme.greyText,
                    ),
                  ),
                )
              else
                Text(
                  value.isEmpty ? 'Not set' : value,
                  style: TextStyle(
                    fontSize: 14,
                    color: value.isEmpty ? AppTheme.greyText : AppTheme.darkText,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// PRODUCT DETAILS SCREEN
// ============================================================
class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  int quantity = 1;
  bool _isFavorite = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final product = ModalRoute.of(context)?.settings.arguments as Product?;
    if (product != null) {
      try {
        final isFav = await _db.isFavorite(product.id);
        setState(() => _isFavorite = isFav);
      } catch (e) {
        debugPrint('Error loading product data: $e');
      }
    }
  }

  Future<void> _toggleFavorite(Product product) async {
    try {
      final isFav = await _db.isFavorite(product.id);
      if (isFav) {
        await _db.removeFavorite(product.id);
        setState(() => _isFavorite = false);
      } else {
        await _db.addFavorite({
          'product_id': product.id,
          'product_name': product.name,
          'price': product.price,
          'image_path': product.imageUrl,
        });
        setState(() => _isFavorite = true);
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = ModalRoute.of(context)?.settings.arguments as Product?;
    if (product == null) {
      return const Scaffold(body: Center(child: Text('Product not found')));
    }

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.favorite : Icons.favorite_border, color: _isFavorite ? Colors.red : null),
            onPressed: () => _toggleFavorite(product),
          ),
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              color: AppTheme.softGreen,
              child: ProductImageWidget(imagePath: product.imageUrl, height: 220, fit: BoxFit.contain),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(product.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${product.price}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                          if (product.isOnSale && product.originalPrice != null)
                            Text('₹${product.originalPrice}', style: const TextStyle(fontSize: 12, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(product.rating.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Text('(${product.reviews} reviews)', style: const TextStyle(fontSize: 12, color: AppTheme.greyText)),
                        ],
                      ),
                      if (product.isOrganic)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppTheme.primaryGreen, borderRadius: BorderRadius.circular(10)),
                          child: const Text('Organic', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      if (product.isFresh)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(10)),
                          child: const Text('Fresh', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.softGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.lightGreen]),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(product.farmerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              const Text('View Farmer Profile →', style: TextStyle(fontSize: 12, color: AppTheme.greyText)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(product.description, style: const TextStyle(fontSize: 14, color: AppTheme.greyText, height: 1.5)),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: product.stock > 0 ? AppTheme.softGreen : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(product.stock > 0 ? Icons.check_circle : Icons.warning,
                            color: product.stock > 0 ? AppTheme.primaryGreen : Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          product.stock > 0 ? '${product.stock} units available' : 'Out of stock',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                              color: product.stock > 0 ? AppTheme.primaryGreen : Colors.red),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              onPressed: () { if (quantity > 1) setState(() => quantity--); },
                            ),
                            Text(quantity.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              onPressed: () { if (quantity < product.stock) setState(() => quantity++); },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GradientButton(
                          text: 'Add to Cart',
                          icon: Icons.shopping_cart,
                          onPressed: () async {
                            setState(() => _isLoading = true);
                            await _db.addToCart({
                              'product_id': product.id,
                              'product_name': product.name,
                              'price': product.price,
                              'quantity': quantity,
                              'unit': product.unit,
                              'image_path': product.imageUrl,
                              'is_organic': product.isOrganic ? 1 : 0,
                            });
                            
                            // ✅ Fix: Check context.mounted after async operation
                            if (!context.mounted) return;
                            
                            setState(() => _isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Added to cart! 🛒'), backgroundColor: AppTheme.primaryGreen),
                            );
                          },
                          isLoading: _isLoading,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, '/checkout'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        side: const BorderSide(color: AppTheme.primaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Buy Now', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FAVORITES SCREEN
// ============================================================
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final items = await _db.getFavorites();
      setState(() {
        _favorites = items;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFavorite(String productId) async {
    await _db.removeFavorite(productId);
    await _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('My Favorites')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 60, color: Colors.grey),
            SizedBox(height: 12),
            Text('No favorites yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            SizedBox(height: 6),
            Text('Start adding products to your favorites', style: TextStyle(color: AppTheme.greyText)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final item = _favorites[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
            ),
            child: Row(
              children: [
                ProductImageWidget(imagePath: item['image_path'] ?? '', width: 60, height: 60),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['product_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('₹${item['price'] ?? 0}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => _removeFavorite(item['product_id']),
                ),
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () async {
                    await _db.addToCart({
                      'product_id': item['product_id'],
                      'product_name': item['product_name'],
                      'price': item['price'],
                      'quantity': 1,
                      'unit': 'kg',
                      'image_path': item['image_path'] ?? '',
                      'is_organic': 0,
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to cart!'), backgroundColor: AppTheme.primaryGreen),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// CART SCREEN
// ============================================================
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<CartItem> _cartItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    try {
      final items = await _db.getCartItems();
      setState(() {
        _cartItems = items.map((e) => CartItem.fromMap(e)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading cart: $e');
      setState(() => _isLoading = false);
    }
  }

  double get _subtotal => _cartItems.fold(0.0, (total, item) => total + item.total);
  double get _deliveryFee => _subtotal > 500 ? 0 : 20.0;
  double get _total => _subtotal + _deliveryFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('My Cart'),
        actions: [
          if (_cartItems.isNotEmpty)
            TextButton(
              onPressed: () async {
                await _db.clearCart();
                await _loadCart();
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined, size: 60, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Your cart is empty', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text('Start adding fresh vegetables to your cart', style: TextStyle(color: AppTheme.greyText)),
            const SizedBox(height: 16),
            GradientButton(text: 'Browse Products', onPressed: () => Navigator.pop(context)),
          ],
        ),
      )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _cartItems.length,
              itemBuilder: (context, index) {
                final item = _cartItems[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      ProductImageWidget(imagePath: item.imageUrl, width: 55, height: 55),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.productName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            Text('₹${item.price}/${item.unit}', style: const TextStyle(fontSize: 12, color: AppTheme.greyText)),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () async {
                                    if (item.quantity > 1) {
                                      await _db.updateCartQuantity(item.productId, item.quantity - 1);
                                      await _loadCart();
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.softGreen,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.remove, size: 14, color: AppTheme.primaryGreen),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(item.quantity.toString(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () async {
                                    await _db.updateCartQuantity(item.productId, item.quantity + 1);
                                    await _loadCart();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryGreen,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.add, size: 14, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${item.total.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () async {
                              await _db.removeFromCart(item.productId);
                              await _loadCart();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(6)),
                              child: Icon(Icons.close, size: 14, color: Colors.red.shade400),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal', style: TextStyle(color: AppTheme.greyText)),
                      Text('₹${_subtotal.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w500)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Delivery Fee', style: TextStyle(color: AppTheme.greyText)),
                      Text(_deliveryFee == 0 ? 'FREE' : '₹${_deliveryFee.toStringAsFixed(0)}',
                          style: TextStyle(fontWeight: FontWeight.w500, color: _deliveryFee == 0 ? AppTheme.primaryGreen : null)),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('₹${_total.toStringAsFixed(0)}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GradientButton(
                    text: 'Proceed to Checkout',
                    icon: Icons.arrow_forward,
                    onPressed: () => Navigator.pushNamed(context, '/checkout'),
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

// ============================================================
// CHECKOUT SCREEN
// ============================================================
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  String _paymentMethod = 'Cash on Delivery';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(title: const Text('Checkout')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Delivery Address', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Enter delivery address',
                hintText: 'House no, street, city, pincode',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Delivery notes (optional)',
                hintText: 'Gate code, landmark, etc.',
                prefixIcon: Icon(Icons.note_outlined),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            RadioGroup<String>(
              groupValue: _paymentMethod,
              onChanged: (value) => setState(() => _paymentMethod = value!),
              child: GlassmorphismCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Cash on Delivery'),
                      value: 'Cash on Delivery',
                      activeColor: AppTheme.primaryGreen,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    RadioListTile<String>(
                      title: const Text('UPI (Google Pay, PhonePe)'),
                      value: 'UPI',
                      activeColor: AppTheme.primaryGreen,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    RadioListTile<String>(
                      title: const Text('Credit/Debit Card'),
                      value: 'Card',
                      activeColor: AppTheme.primaryGreen,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<double>(
              future: _db.getCartTotal(),
              builder: (context, snapshot) {
                final subtotal = snapshot.data ?? 0.0;
                final deliveryFee = subtotal > 500 ? 0 : 20.0;
                final total = subtotal + deliveryFee;

                return GlassmorphismCard(
                  child: Column(
                    children: [
                      _buildSummaryRow('Subtotal', '₹${subtotal.toStringAsFixed(0)}'),
                      _buildSummaryRow('Delivery Fee', deliveryFee == 0 ? 'FREE' : '₹${deliveryFee.toStringAsFixed(0)}',
                          isGreen: deliveryFee == 0),
                      const Divider(),
                      _buildSummaryRow('Total', '₹${total.toStringAsFixed(0)}', isBold: true, isGreen: true),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            GradientButton(
              text: 'Place Order',
              isLoading: _isLoading,
              onPressed: _placeOrder,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isGreen = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.w600 : FontWeight.w400, fontSize: isBold ? 16 : 14)),
          Text(value, style: TextStyle(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w400,
            fontSize: isBold ? 18 : 14,
            color: isGreen ? AppTheme.primaryGreen : null,
          )),
        ],
      ),
    );
  }

  void _placeOrder() async {
    if (_addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter delivery address')),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    try {
      final cartItems = await _db.getCartItems();
      final subtotal = await _db.getCartTotal();
      final deliveryFee = subtotal > 500 ? 0 : 20.0;
      final total = subtotal + deliveryFee;

      final order = {
        'id': Uuid().v4(),
        'user_id': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'total_amount': total,
        'status': 'Pending',
        'delivery_address': _addressController.text.trim(),
        'payment_method': _paymentMethod,
        'order_date': DateTime.now().toIso8601String(),
        'items': cartItems.map((e) => e.toString()).join(','),
        'delivery_notes': _notesController.text.trim(),
      };

    await _db.insertOrder(order);
    await _db.clearCart();

    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    
    setState(() => _isLoading = false);
    navigator.pushReplacementNamed('/order_tracking');
    messenger.showSnackBar(
      const SnackBar(content: Text('Order placed successfully! 🎉'), backgroundColor: AppTheme.primaryGreen),
    );
  } catch (e) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = false);
    messenger.showSnackBar(
      SnackBar(content: Text('Error placing order: $e'), backgroundColor: Colors.red),
    );
  }
  }
}

// ============================================================
// ORDER TRACKING SCREEN
// ============================================================
class OrderTrackingScreen extends StatelessWidget {
  const OrderTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = ['Order Placed', 'Processing', 'Out for Delivery', 'Delivered'];
    const int currentStep = 1;

    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Track Order'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GlassmorphismCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.softGreen,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.shopping_bag, color: AppTheme.primaryGreen, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Order #ASTRA-001', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text('Placed on ${DateTime.now().toString().substring(0, 10)}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.greyText)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('Processing',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange.shade800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(steps.length, (index) {
                    final isCompleted = index <= currentStep;
                    final isCurrent = index == currentStep;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                isCompleted ? Icons.check : Icons.access_time,
                                color: isCompleted ? Colors.white : Colors.grey,
                                size: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              steps[index],
                              style: TextStyle(
                                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                                fontSize: isCurrent ? 14 : 13,
                                color: isCompleted ? AppTheme.darkText : AppTheme.greyText,
                              ),
                            ),
                          ),
                          if (isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.softGreen,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text('In Progress',
                                  style: TextStyle(fontSize: 8, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.softGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.delivery_dining, color: AppTheme.primaryGreen, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('Your order will be delivered by 6:30 PM today',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            backgroundColor: AppTheme.primaryGreen,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Contact', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADMIN PANEL SCREEN - FIXED WITH EMPLOYEE ADDITION
// ============================================================
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final AuthService _authService = AuthService();

  // Product Controllers
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _productPriceController = TextEditingController();
  final TextEditingController _productUnitController = TextEditingController();
  final TextEditingController _productCategoryController = TextEditingController();
  final TextEditingController _productDescriptionController = TextEditingController();
  final TextEditingController _productStockController = TextEditingController();
  final TextEditingController _farmerNameController = TextEditingController();

  // Employee Controllers
  final TextEditingController _empNameController = TextEditingController();
  final TextEditingController _empEmailController = TextEditingController();
  final TextEditingController _empPasswordController = TextEditingController();
  final TextEditingController _empPhoneController = TextEditingController();

  String? _selectedImagePath;
  bool _isOrganic = false;
  bool _isFresh = true;
  bool _isFeatured = false;
  bool _isOnSale = false;
  final ImagePicker _picker = ImagePicker();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _employees = [];
  int _selectedTab = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final products = await _db.getAllProducts();
      final orders = await _db.getAllOrders();
      final employees = await _authService.getEmployees();
      setState(() {
        _products = products;
        _orders = orders;
        _employees = employees;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      setState(() => _isLoading = false);
    }
  }

  // ==================== PRODUCT METHODS ====================
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() => _selectedImagePath = image.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _addProduct() async {
    try {
      if (_productNameController.text.isEmpty ||
          _productPriceController.text.isEmpty ||
          _productCategoryController.text.isEmpty) {
        _showSnackbar('Please fill all required fields', Colors.orange);
        return;
      }

      final product = {
        'id': Uuid().v4(),
        'name': _productNameController.text.trim(),
        'price': double.parse(_productPriceController.text.trim()),
        'original_price': null,
        'unit': _productUnitController.text.trim().isNotEmpty ? _productUnitController.text.trim() : 'kg',
        'category': _productCategoryController.text.trim(),
        'description': _productDescriptionController.text.trim(),
        'farmer_name': _farmerNameController.text.trim().isNotEmpty ? _farmerNameController.text.trim() : 'ASTRA Farms',
        'farmer_id': 'f1',
        'rating': 0.0,
        'reviews': 0,
        'is_organic': _isOrganic ? 1 : 0,
        'is_fresh': _isFresh ? 1 : 0,
        'is_featured': _isFeatured ? 1 : 0,
        'is_on_sale': _isOnSale ? 1 : 0,
        'stock': int.parse(_productStockController.text.trim().isEmpty ? '0' : _productStockController.text.trim()),
        'image_path': _selectedImagePath ?? '',
        'created_at': DateTime.now().toIso8601String(),
      };

      await _db.insertProduct(product);
      await _loadData();
      if (!mounted) return;
      _clearProductFields();
      _showSnackbar('Product added successfully!', AppTheme.primaryGreen);
    } catch (e) {
      _showSnackbar('Error adding product: $e', Colors.red);
    }
  }

  Future<void> _deleteProduct(String id) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Product'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        await _db.deleteProduct(id);
        await _loadData();
        _showSnackbar('Product deleted successfully!', Colors.green);
      }
    } catch (e) {
      _showSnackbar('Error deleting product: $e', Colors.red);
    }
  }

  void _clearProductFields() {
    _productNameController.clear();
    _productPriceController.clear();
    _productUnitController.clear();
    _productCategoryController.clear();
    _productDescriptionController.clear();
    _productStockController.clear();
    _farmerNameController.clear();
    setState(() {
      _selectedImagePath = null;
      _isOrganic = false;
      _isFresh = true;
      _isFeatured = false;
      _isOnSale = false;
    });
  }

  // ==================== EMPLOYEE METHODS - FIXED ====================
  Future<void> _addEmployee() async {
    if (_empNameController.text.isEmpty ||
        _empEmailController.text.isEmpty ||
        _empPasswordController.text.isEmpty) {
      _showSnackbar('Please fill all employee fields', Colors.orange);
      return;
    }

    // Admin credentials save பண்ணு — re-login க்கு
    final adminEmail =
        FirebaseAuth.instance.currentUser?.email ?? '';

    setState(() => _isLoading = true);
    try {
      final success = await _authService.addEmployee(
        _empEmailController.text.trim(),
        _empPasswordController.text.trim(),
        _empNameController.text.trim(),
        _empPhoneController.text.trim(),
      );

      if (success) {
        if (!mounted) return;
        _showSnackbar(
            'Employee added! Logging back in as admin...', AppTheme.primaryGreen);
        _empNameController.clear();
        _empEmailController.clear();
        _empPasswordController.clear();
        _empPhoneController.clear();

        // ✅ Admin-ஐ மீண்டும் login பண்ணு
        if (adminEmail.isNotEmpty) {
          await _authService.signOut();
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        }
      } else {
        _showSnackbar(
            'Employee already exists or failed to add', Colors.red);
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }
  Future<void> _deleteEmployee(String userId) async {
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Employee'),
          content: const Text('Are you sure you want to delete this employee?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirm == true) {
        final success = await _authService.deleteEmployee(userId);
        if (success) {
          await _loadData();
          _showSnackbar('Employee deleted successfully!', Colors.green);
        } else {
          _showSnackbar('Failed to delete employee', Colors.red);
        }
      }
    } catch (e) {
      _showSnackbar('Error: $e', Colors.red);
    }
  }

  // ==================== ORDER METHODS ====================
  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      await _db.updateOrderStatus(orderId, status);
      await _loadData();
      _showSnackbar('Order status updated to $status', AppTheme.primaryGreen);
    } catch (e) {
      _showSnackbar('Error updating order: $e', Colors.red);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(fontFamily: 'Playfair Display')),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildTabs(),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _buildProductsTab(),
                _buildOrdersTab(),
                _buildEmployeesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Row(
        children: [
          _buildTabButton('Products', 0, Icons.inventory),
          _buildTabButton('Orders', 1, Icons.shopping_bag),
          _buildTabButton('Employees', 2, Icons.people),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index, IconData icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.primaryGreen : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppTheme.primaryGreen : AppTheme.greyText, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.greyText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== PRODUCTS TAB ====================
  Widget _buildProductsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassmorphismCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add New Product', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: _productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    prefixIcon: Icon(Icons.production_quantity_limits),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _productPriceController,
                        decoration: const InputDecoration(
                          labelText: 'Price *',
                          prefixIcon: Icon(Icons.currency_rupee),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _productUnitController,
                        decoration: const InputDecoration(
                          labelText: 'Unit (kg, bunch)',
                          prefixIcon: Icon(Icons.scale),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _productCategoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: Icon(Icons.category),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _productDescriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.description),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _productStockController,
                        decoration: const InputDecoration(
                          labelText: 'Stock',
                          prefixIcon: Icon(Icons.inventory_2),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _farmerNameController,
                        decoration: const InputDecoration(
                          labelText: 'Farmer Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Organic'),
                        value: _isOrganic,
                        onChanged: (value) => setState(() => _isOrganic = value),
                        activeThumbColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Fresh'),
                        value: _isFresh,
                        onChanged: (value) => setState(() => _isFresh = value),
                        activeThumbColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('Featured'),
                        value: _isFeatured,
                        onChanged: (value) => setState(() => _isFeatured = value),
                        activeThumbColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        title: const Text('On Sale'),
                        value: _isOnSale,
                        onChanged: (value) => setState(() => _isOnSale = value),
                        activeThumbColor: AppTheme.primaryGreen,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: Text(_selectedImagePath == null ? 'Pick Image' : 'Image Selected'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GradientButton(
                        text: 'Add Product',
                        onPressed: _addProduct,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('All Products', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _products.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No products added yet')))
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    ProductImageWidget(imagePath: product['image_path'] ?? '', width: 40, height: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product['name'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('₹${product['price']} / ${product['unit']} • ${product['category']}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.greyText)),
                          Wrap(
                            children: [
                              if (product['is_organic'] == 1)
                                Container(
                                  margin: const EdgeInsets.only(top: 2, right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppTheme.softGreen,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Organic',
                                      style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
                                ),
                              if (product['is_featured'] == 1)
                                Container(
                                  margin: const EdgeInsets.only(top: 2, right: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Featured',
                                      style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: Colors.orange)),
                                ),
                              if (product['is_on_sale'] == 1)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Sale',
                                      style: TextStyle(fontSize: 7, fontWeight: FontWeight.w600, color: Colors.red)),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => _deleteProduct(product['id']),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== ORDERS TAB ====================
  Widget _buildOrdersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('All Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.softGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${_orders.length} orders',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.primaryGreen)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _orders.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No orders yet')))
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              final order = _orders[index];
              final statusColors = {
                'Pending': Colors.orange,
                'Processing': Colors.blue,
                'Shipped': Colors.purple,
                'Delivered': AppTheme.primaryGreen,
                'Cancelled': Colors.red,
              };
              final statusColor = statusColors[order['status']] ?? Colors.grey;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Order #${order['id']?.substring(0, 8) ?? 'N/A'}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(order['status'] ?? 'Pending',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Total: ₹${order['total_amount'] ?? 0} • ${order['payment_method'] ?? 'N/A'}',
                        style: const TextStyle(fontSize: 11, color: AppTheme.greyText)),
                    Text('Date: ${order['order_date']?.substring(0, 10) ?? 'N/A'}',
                        style: const TextStyle(fontSize: 10, color: AppTheme.greyText)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: ['Processing', 'Shipped', 'Delivered', 'Cancelled'].map((status) {
                        return GestureDetector(
                          onTap: () => _updateOrderStatus(order['id'], status),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: order['status'] == status ? AppTheme.primaryGreen : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: order['status'] == status ? Colors.white : AppTheme.greyText,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ==================== EMPLOYEES TAB ====================
  Widget _buildEmployeesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassmorphismCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add New Employee', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: _empNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _empEmailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address *',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _empPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Password *',
                    prefixIcon: Icon(Icons.lock_outlined),
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _empPhoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                GradientButton(
                  text: 'Add Employee',
                  icon: Icons.person_add,
                  onPressed: _addEmployee,
                  isLoading: _isLoading,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('All Employees', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _employees.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No employees added')))
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _employees.length,
            itemBuilder: (context, index) {
              final emp = _employees[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.softGreen,
                      radius: 20,
                      child: Text(
                        (emp['name'] ?? 'E')[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(emp['name'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text(emp['email'] ?? '',
                              style: const TextStyle(fontSize: 11, color: AppTheme.greyText)),
                          Text('Phone: ${emp['phone'] ?? 'N/A'}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.greyText)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: emp['status'] == 'active' ? AppTheme.softGreen : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        emp['status'] ?? 'active',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: emp['status'] == 'active' ? AppTheme.primaryGreen : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: () => _deleteEmployee(emp['id']),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPLOYEE PANEL SCREEN
// ============================================================
class EmployeePanelScreen extends StatefulWidget {
  const EmployeePanelScreen({super.key});

  @override
  State<EmployeePanelScreen> createState() => _EmployeePanelScreenState();
}

class _EmployeePanelScreenState extends State<EmployeePanelScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    try {
      final orders = await _db.getAllOrders();
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading orders: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.offWhite,
      appBar: AppBar(
        title: const Text('Employee Panel'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadOrders),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Orders to Process', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _orders.isEmpty
                ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No orders available')))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final statusColors = {
                  'Pending': Colors.orange,
                  'Processing': Colors.blue,
                  'Shipped': Colors.purple,
                  'Delivered': AppTheme.primaryGreen,
                  'Cancelled': Colors.red,
                };
                final statusColor = statusColors[order['status']] ?? Colors.grey;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Order #${order['id']?.substring(0, 8) ?? 'N/A'}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(order['status'] ?? 'Pending',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Total: ₹${order['total_amount'] ?? 0}',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('Payment: ${order['payment_method'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.greyText)),
                      Text('Date: ${order['order_date']?.substring(0, 10) ?? 'N/A'}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.greyText)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: ['Processing', 'Shipped', 'Delivered'].map((status) {
                          return GestureDetector(
                            onTap: () async {
                              await _db.updateOrderStatus(order['id'], status);
                              await _loadOrders();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Order status updated to $status'),
                                      backgroundColor: AppTheme.primaryGreen),
                                );
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: order['status'] == status ? AppTheme.primaryGreen : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: order['status'] == status ? Colors.white : AppTheme.greyText,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FIREBASE OPTIONS
// ============================================================
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAgJLRDBHLDjhLNxde8tz1f3ZKOVl1xUFg',
    appId: '1:349617265780:android:5247b0320d8d5a59560521',
    messagingSenderId: '349617265780',
    projectId: 'demoo-ef118',
    storageBucket: 'demoo-ef118.firebasestorage.app',
  );
}

// ============================================================
// MAIN APP
// ============================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
      await Firebase.initializeApp();
    }

  final db = DatabaseHelper();
  await db.insertSampleData();

  runApp(const AstraApp());
}

class AstraApp extends StatelessWidget {
  const AstraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ASTRA - Fresh Vegetables',
      theme: AppTheme.lightTheme,
      initialRoute: FirebaseAuth.instance.currentUser == null
          ? '/splash'
          : '/home',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/product_details': (context) => const ProductDetailsScreen(),
        '/cart': (context) => const CartScreen(),
        '/checkout': (context) => const CheckoutScreen(),
        '/order_tracking': (context) => const OrderTrackingScreen(),
        '/favorites': (context) => const FavoritesScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/admin': (context) => const AdminPanelScreen(),
        '/employee': (context) => const EmployeePanelScreen(),
      },
    );
  }
}