import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/login_user.dart';
import '../models/exhibition.dart';
import '../models/booth_application.dart';
import 'dart:io';
import 'dart:convert';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;
  // Currently logged-in user (in-memory)
  LoginUser? _currentUser;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'exhibition_app.db');
    return await openDatabase(
      path,
      // bumped to 7 to ensure floor_plans exists on upgrade
      version: 16,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Drop and recreate the users table with fresh data
      await db.execute('DROP TABLE IF EXISTS users');
    }
    if (oldVersion < 3) {
      // Create exhibitions table if it doesn't exist
      try {
        await db.execute('DROP TABLE IF EXISTS exhibitions');
      } catch (e) {
        print('Note: exhibitions table did not exist');
      }
    }
    // Add booth_applications table in version 4 without dropping existing data
    if (oldVersion < 4) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS booth_applications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exhibitionId INTEGER NOT NULL,
            userId INTEGER NOT NULL,
            boothId TEXT NOT NULL,
            exhibitorName TEXT,
            companyName TEXT,
            email TEXT,
            phone TEXT,
            status TEXT DEFAULT 'Pending',
            createdAt TEXT NOT NULL
          )
        ''');
        print('DATABASE - booth_applications table created (onUpgrade)');
      } catch (e) {
        print('DATABASE - Error creating booth_applications table: $e');
      }
    }

    // floor_plans introduced around v5, but older DBs may not have the table.
    // Ensure the table exists and has exhibitionId.
    if (oldVersion < 7) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS floor_plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            filePath TEXT,
            resolution TEXT,
            size TEXT,
            uploadedBy TEXT,
            uploadedDate TEXT,
            exhibitionId INTEGER
          )
        ''');
        print('DATABASE - floor_plans table ensured (onUpgrade)');
      } catch (e) {
        print('DATABASE - Error ensuring floor_plans table (onUpgrade): $e');
      }

      // In case an older schema exists without exhibitionId, try to add the column.
      try {
        await db.execute('ALTER TABLE floor_plans ADD COLUMN exhibitionId INTEGER');
        print('DATABASE - floor_plans altered to add exhibitionId (onUpgrade)');
      } catch (e) {
        // Ignore if it already exists or alter isn't supported.
        print('DATABASE - floor_plans exhibitionId alter skipped: $e');
      }
    }

    // Add booth_layouts in version 6
    if (oldVersion < 6) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS booth_layouts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            exhibitionId INTEGER NOT NULL,
            scope TEXT NOT NULL,
            data TEXT NOT NULL,
            updatedAt TEXT NOT NULL,
            UNIQUE(exhibitionId, scope)
          )
        ''');
        print('DATABASE - booth_layouts table created (onUpgrade)');
      } catch (e) {
        print('DATABASE - Error creating booth_layouts table (onUpgrade): $e');
      }
    }

    // v8: add isPublished to exhibitions + richer booth_applications fields
    if (oldVersion < 8) {
      // exhibitions.isPublished
      try {
        await db.execute('ALTER TABLE exhibitions ADD COLUMN isPublished INTEGER DEFAULT 1');
        print('DATABASE - exhibitions altered to add isPublished (onUpgrade)');
      } catch (e) {
        print('DATABASE - exhibitions isPublished alter skipped: $e');
      }

      // booth_applications additional fields
      const boothColumns = <String, String>{
        'companyDescription': 'TEXT',
        'exhibitProfile': 'TEXT',
        'addItems': 'TEXT',
        'eventStartDate': 'TEXT',
        'eventEndDate': 'TEXT',
        'decisionReason': 'TEXT',
        'updatedAt': 'TEXT',
      };

      for (final entry in boothColumns.entries) {
        try {
          await db.execute('ALTER TABLE booth_applications ADD COLUMN ${entry.key} ${entry.value}');
          print('DATABASE - booth_applications altered to add ${entry.key} (onUpgrade)');
        } catch (e) {
          print('DATABASE - booth_applications ${entry.key} alter skipped: $e');
        }
      }
    }

    // v9: booth_applications booking window fields
    if (oldVersion < 9) {
      const boothColumns = <String, String>{
        'bookingStartDate': 'TEXT',
        'bookingEndDate': 'TEXT',
      };

      for (final entry in boothColumns.entries) {
        try {
          await db.execute('ALTER TABLE booth_applications ADD COLUMN ${entry.key} ${entry.value}');
          print('DATABASE - booth_applications altered to add ${entry.key} (onUpgrade)');
        } catch (e) {
          print('DATABASE - booth_applications ${entry.key} alter skipped: $e');
        }
      }
    }

    // v10: exhibitions adjacency competitor rule flag
    if (oldVersion < 10) {
      try {
        await db.execute('ALTER TABLE exhibitions ADD COLUMN blockAdjacentCompetitors INTEGER DEFAULT 0');
        print('DATABASE - exhibitions altered to add blockAdjacentCompetitors (onUpgrade)');
      } catch (e) {
        print('DATABASE - exhibitions blockAdjacentCompetitors alter skipped: $e');
      }
    }

    // v11: booth_applications industry category
    if (oldVersion < 11) {
      try {
        await db.execute('ALTER TABLE booth_applications ADD COLUMN industryCategory TEXT');
        print('DATABASE - booth_applications altered to add industryCategory (onUpgrade)');
      } catch (e) {
        print('DATABASE - booth_applications industryCategory alter skipped: $e');
      }
    }

    // v12: exhibitions industry categories list
    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE exhibitions ADD COLUMN industryCategories TEXT');
        print('DATABASE - exhibitions altered to add industryCategories (onUpgrade)');
      } catch (e) {
        print('DATABASE - exhibitions industryCategories alter skipped: $e');
      }

      // Backfill defaults for older exhibitions so dropdown isn't empty.
      try {
        final defaultIndustryCategories = jsonEncode(<String>[
          'Food',
          'Coffee',
          'Telecom',
          'Technology',
          'Retail',
        ]);
        await db.rawUpdate(
          "UPDATE exhibitions SET industryCategories = ? WHERE industryCategories IS NULL OR TRIM(industryCategories) = ''",
          [defaultIndustryCategories],
        );
        print('DATABASE - exhibitions industryCategories backfilled (onUpgrade)');
      } catch (e) {
        print('DATABASE - exhibitions industryCategories backfill skipped: $e');
      }
    }

    // v13: booth_types (persistent booth type catalog)
    if (oldVersion < 13) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS booth_types (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            size TEXT,
            price TEXT,
            features TEXT,
            createdAt TEXT NOT NULL
          )
        ''');
        print('DATABASE - booth_types table ensured (onUpgrade)');
      } catch (e) {
        print('DATABASE - Error ensuring booth_types table (onUpgrade): $e');
      }

      // Seed defaults if empty (keeps older installs functional).
      try {
        final existing = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM booth_types')) ?? 0;
        if (existing == 0) {
          final now = DateTime.now().toIso8601String();
          await db.insert('booth_types', {
            'name': 'Small Booth',
            'size': '3x3m',
            'price': '\$500',
            'features': jsonEncode(<String>['Table', 'Chair', 'Basic Lighting']),
            'createdAt': now,
          });
          await db.insert('booth_types', {
            'name': 'Medium Booth',
            'size': '5x5m',
            'price': '\$1,000',
            'features': jsonEncode(<String>['Table', 'Chairs', 'Electricity', 'WiFi']),
            'createdAt': now,
          });
          await db.insert('booth_types', {
            'name': 'Premium Booth',
            'size': '10x10m',
            'price': '\$2,500',
            'features': jsonEncode(<String>['Complete Setup', 'Electricity', 'WiFi', 'AC', 'Furniture']),
            'createdAt': now,
          });
          print('DATABASE - booth_types defaults seeded (onUpgrade)');
        }
      } catch (e) {
        print('DATABASE - booth_types seed skipped (onUpgrade): $e');
      }
    }

    // v14: exhibitions organizer ownership (separate per organizer account)
    if (oldVersion < 14) {
      try {
        await db.execute('ALTER TABLE exhibitions ADD COLUMN organizerId INTEGER');
        print('DATABASE - exhibitions altered to add organizerId (onUpgrade)');
      } catch (e) {
        print('DATABASE - exhibitions organizerId alter skipped: $e');
      }

      // Backfill: assign existing exhibitions to the first organizer user (best-effort).
      try {
        final organizerId = Sqflite.firstIntValue(
          await db.rawQuery("SELECT id FROM users WHERE LOWER(role) = 'organizer' ORDER BY id ASC LIMIT 1"),
        );
        if (organizerId != null) {
          await db.rawUpdate(
            'UPDATE exhibitions SET organizerId = ? WHERE organizerId IS NULL',
            [organizerId],
          );
          print('DATABASE - exhibitions organizerId backfilled (onUpgrade)');
        }
      } catch (e) {
        print('DATABASE - exhibitions organizerId backfill skipped: $e');
      }
    }

    // v15: organizer-managed add_ons catalog
    if (oldVersion < 15) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS add_ons (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            organizerId INTEGER NOT NULL,
            name TEXT NOT NULL,
            price TEXT,
            createdAt TEXT NOT NULL,
            UNIQUE(organizerId, name)
          )
        ''');
        print('DATABASE - add_ons table ensured (onUpgrade)');
      } catch (e) {
        print('DATABASE - Error ensuring add_ons table (onUpgrade): $e');
      }

      // Seed defaults for the first organizer if none exist.
      try {
        final organizerId = Sqflite.firstIntValue(
          await db.rawQuery("SELECT id FROM users WHERE LOWER(role) = 'organizer' ORDER BY id ASC LIMIT 1"),
        );
        if (organizerId != null) {
          final existing = Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM add_ons WHERE organizerId = ?', [organizerId]),
              ) ??
              0;
          if (existing == 0) {
            final now = DateTime.now().toIso8601String();
            await db.insert('add_ons', {
              'organizerId': organizerId,
              'name': 'Additional furniture',
              'price': '\$200',
              'createdAt': now,
            });
            await db.insert('add_ons', {
              'organizerId': organizerId,
              'name': 'Promotional spot',
              'price': '\$150',
              'createdAt': now,
            });
            await db.insert('add_ons', {
              'organizerId': organizerId,
              'name': 'Extended WiFi',
              'price': '\$100',
              'createdAt': now,
            });
            print('DATABASE - add_ons defaults seeded (onUpgrade)');
          }
        }
      } catch (e) {
        print('DATABASE - add_ons seed skipped (onUpgrade): $e');
      }
    }

    // v16: booth_types scoped by organizerId (organizers manage their own catalog)
    if (oldVersion < 16) {
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS booth_types_new (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            organizerId INTEGER,
            name TEXT NOT NULL,
            size TEXT,
            price TEXT,
            features TEXT,
            createdAt TEXT NOT NULL,
            UNIQUE(organizerId, name)
          )
        ''');

        // Best-effort migrate existing rows (older schema had no organizerId).
        try {
          await db.execute('''
            INSERT OR IGNORE INTO booth_types_new (id, organizerId, name, size, price, features, createdAt)
            SELECT id, NULL as organizerId, name, size, price, features, createdAt
            FROM booth_types
          ''');
        } catch (e) {
          print('DATABASE - booth_types migration copy skipped: $e');
        }

        await db.execute('DROP TABLE IF EXISTS booth_types');
        await db.execute('ALTER TABLE booth_types_new RENAME TO booth_types');
        print('DATABASE - booth_types migrated to organizerId schema (onUpgrade)');
      } catch (e) {
        print('DATABASE - booth_types migration failed (onUpgrade): $e');
      }
    }

    // Recreate tables only if earlier versions required dropping
    if (oldVersion == 0 || oldVersion < 2 || oldVersion < 3) {
      await _onCreate(db, newVersion);
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    print('DATABASE - Creating tables (version: $version)');
    try {
      // Create users/login table
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          email TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          fullName TEXT,
          role TEXT DEFAULT 'user',
          createdAt TEXT NOT NULL
        )
      ''');
      print('DATABASE - Users table created');
    } catch (e) {
      print('DATABASE - Error creating users table: $e');
    }

    // Create booth types catalog (v13+)
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS booth_types (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          organizerId INTEGER,
          name TEXT NOT NULL,
          size TEXT,
          price TEXT,
          features TEXT,
          createdAt TEXT NOT NULL
          ,UNIQUE(organizerId, name)
        )
      ''');
      print('DATABASE - booth_types table created');

      final now2 = DateTime.now().toIso8601String();
      await db.insert('booth_types', {
        'organizerId': null,
        'name': 'Small Booth',
        'size': '3x3m',
        'price': '\$500',
        'features': jsonEncode(<String>['Table', 'Chair', 'Basic Lighting']),
        'createdAt': now2,
      });
      await db.insert('booth_types', {
        'organizerId': null,
        'name': 'Medium Booth',
        'size': '5x5m',
        'price': '\$1,000',
        'features': jsonEncode(<String>['Table', 'Chairs', 'Electricity', 'WiFi']),
        'createdAt': now2,
      });
      await db.insert('booth_types', {
        'organizerId': null,
        'name': 'Premium Booth',
        'size': '10x10m',
        'price': '\$2,500',
        'features': jsonEncode(<String>['Complete Setup', 'Electricity', 'WiFi', 'AC', 'Furniture']),
        'createdAt': now2,
      });
      print('DATABASE - booth_types defaults inserted');
    } catch (e) {
      print('DATABASE - Error creating/seeding booth_types: $e');
    }

    // Create add-ons catalog (v15+)
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS add_ons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          organizerId INTEGER NOT NULL,
          name TEXT NOT NULL,
          price TEXT,
          createdAt TEXT NOT NULL,
          UNIQUE(organizerId, name)
        )
      ''');
      print('DATABASE - add_ons table created');

      final organizerId = Sqflite.firstIntValue(
        await db.rawQuery("SELECT id FROM users WHERE LOWER(role) = 'organizer' ORDER BY id ASC LIMIT 1"),
      );
      if (organizerId != null) {
        final now3 = DateTime.now().toIso8601String();
        await db.insert('add_ons', {
          'organizerId': organizerId,
          'name': 'Additional furniture',
          'price': '\$200',
          'createdAt': now3,
        });
        await db.insert('add_ons', {
          'organizerId': organizerId,
          'name': 'Promotional spot',
          'price': '\$150',
          'createdAt': now3,
        });
        await db.insert('add_ons', {
          'organizerId': organizerId,
          'name': 'Extended WiFi',
          'price': '\$100',
          'createdAt': now3,
        });
        print('DATABASE - add_ons defaults inserted');
      }
    } catch (e) {
      print('DATABASE - Error creating/seeding add_ons: $e');
    }

    // Insert sample users for testing (password: password123)
    final now = DateTime.now().toIso8601String();
    
    try {
      // Admin user
      await db.insert('users', {
        'email': 'admin@exhibition.com',
        'password': 'password123',
        'fullName': 'Admin User',
        'role': 'admin',
        'createdAt': now,
      });
      print('DATABASE - Admin user inserted');

      // Organizer user
      await db.insert('users', {
        'email': 'organizer@exhibition.com',
        'password': 'password123',
        'fullName': 'Event Organizer',
        'role': 'organizer',
        'createdAt': now,
      });
      print('DATABASE - Organizer user inserted');

      // Exhibitor user
      await db.insert('users', {
        'email': 'exhibitor@exhibition.com',
        'password': 'password123',
        'fullName': 'Booth Exhibitor',
        'role': 'exhibitor',
        'createdAt': now,
      });
      print('DATABASE - Exhibitor user inserted');
    } catch (e) {
      print('DATABASE - Error inserting sample users: $e');
    }

    // Create exhibitions table
    try {
      await db.execute('''
        CREATE TABLE exhibitions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          organizerId INTEGER,
          name TEXT NOT NULL,
          description TEXT,
          startDate TEXT NOT NULL,
          endDate TEXT NOT NULL,
          location TEXT NOT NULL,
          status TEXT DEFAULT 'Upcoming',
          totalBooths INTEGER DEFAULT 0,
          isPublished INTEGER DEFAULT 1,
          blockAdjacentCompetitors INTEGER DEFAULT 0,
          industryCategories TEXT,
          createdAt TEXT NOT NULL
        )
      ''');
      print('DATABASE - Exhibitions table created');
    } catch (e) {
      print('DATABASE - Error creating exhibitions table: $e');
    }

    // Create booth_applications table (ensure exists on fresh DB creation)
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS booth_applications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          exhibitionId INTEGER NOT NULL,
          userId INTEGER NOT NULL,
          boothId TEXT NOT NULL,
          exhibitorName TEXT,
          companyName TEXT,
            industryCategory TEXT,
            companyDescription TEXT,
            exhibitProfile TEXT,
            addItems TEXT,
            eventStartDate TEXT,
            eventEndDate TEXT,
            bookingStartDate TEXT,
            bookingEndDate TEXT,
          email TEXT,
          phone TEXT,
          status TEXT DEFAULT 'Pending',
            decisionReason TEXT,
          createdAt TEXT NOT NULL
            ,updatedAt TEXT
        )
      ''');
      print('DATABASE - booth_applications table created (onCreate)');
    } catch (e) {
      print('DATABASE - Error creating booth_applications table (onCreate): $e');
    }

    // Create floor_plans table to store uploaded floor plan metadata
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS floor_plans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          filePath TEXT,
          resolution TEXT,
          size TEXT,
          uploadedBy TEXT,
          uploadedDate TEXT,
          exhibitionId INTEGER
        )
      ''');
      print('DATABASE - floor_plans table created (onCreate)');
    } catch (e) {
      print('DATABASE - Error creating floor_plans table (onCreate): $e');
    }

    // Create booth_layouts table to store booth mapping layouts per exhibition
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS booth_layouts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          exhibitionId INTEGER NOT NULL,
          scope TEXT NOT NULL,
          data TEXT NOT NULL,
          updatedAt TEXT NOT NULL,
          UNIQUE(exhibitionId, scope)
        )
      ''');
      print('DATABASE - booth_layouts table created (onCreate)');
    } catch (e) {
      print('DATABASE - Error creating booth_layouts table (onCreate): $e');
    }

    // Insert sample exhibitions
    try {
      final defaultIndustryCategories = jsonEncode(<String>[
        'Food',
        'Coffee',
        'Telecom',
        'Technology',
        'Retail',
      ]);

      final organizerId = Sqflite.firstIntValue(
        await db.rawQuery("SELECT id FROM users WHERE LOWER(role) = 'organizer' ORDER BY id ASC LIMIT 1"),
      );

      await db.insert('exhibitions', {
        'organizerId': organizerId,
        'name': 'Tech Expo 2025',
        'description': 'The biggest technology exhibition of the year',
        'startDate': '15 Jan 2025',
        'endDate': '20 Jan 2025',
        'location': 'Convention Center A',
        'status': 'Active',
        'totalBooths': 12,
        'industryCategories': defaultIndustryCategories,
        'createdAt': now,
      });

      await db.insert('exhibitions', {
        'organizerId': organizerId,
        'name': 'Art Exhibition',
        'description': 'Contemporary art from around the world',
        'startDate': '22 Jan 2025',
        'endDate': '25 Jan 2025',
        'location': 'Art Gallery Downtown',
        'status': 'Upcoming',
        'totalBooths': 8,
        'industryCategories': defaultIndustryCategories,
        'createdAt': now,
      });

      await db.insert('exhibitions', {
        'organizerId': organizerId,
        'name': 'Business Conference',
        'description': 'Annual business and networking conference',
        'startDate': '28 Jan 2025',
        'endDate': '30 Jan 2025',
        'location': 'Business Hub',
        'status': 'Upcoming',
        'totalBooths': 15,
        'industryCategories': defaultIndustryCategories,
        'createdAt': now,
      });
      print('DATABASE - Sample exhibitions inserted');
    } catch (e) {
      print('DATABASE - Error inserting sample exhibitions: $e');
    }
    print('DATABASE - _onCreate completed');
  }

  // ==================== BOOTH APPLICATION OPERATIONS ====================

  // Create a new booth application
  Future<BoothApplication> createBoothApplication(BoothApplication application) async {
    try {
      final db = await database;
      // Ensure new applications are created with a Pending status unless explicitly provided
      final nowIso = DateTime.now().toIso8601String();
      final newApp = application.copyWith(
        id: application.id,
        exhibitionId: application.exhibitionId,
        userId: application.userId,
        boothId: application.boothId,
        exhibitorName: application.exhibitorName,
        companyName: application.companyName,
        industryCategory: application.industryCategory,
        companyDescription: application.companyDescription,
        exhibitProfile: application.exhibitProfile,
        addItems: application.addItems,
        eventStartDate: application.eventStartDate,
        eventEndDate: application.eventEndDate,
        bookingStartDate: application.bookingStartDate,
        bookingEndDate: application.bookingEndDate,
        email: application.email,
        phone: application.phone,
        status: application.status.isEmpty ? 'Pending' : application.status,
        createdAt: nowIso,
        updatedAt: nowIso,
      );

      final id = await db.insert('booth_applications', newApp.toMap());
      return newApp.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create booth application: $e');
    }
  }

  // Get all booth applications
  Future<List<BoothApplication>> getAllBoothApplications() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'booth_applications',
        orderBy: 'createdAt DESC',
      );
      return List.generate(maps.length, (i) => BoothApplication.fromMap(maps[i]));
    } catch (e) {
      throw Exception('Failed to get booth applications: $e');
    }
  }

  // Get applications by exhibition id
  Future<List<BoothApplication>> getBoothApplicationsByExhibition(int exhibitionId) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'booth_applications',
        where: 'exhibitionId = ?',
        whereArgs: [exhibitionId],
        orderBy: 'createdAt DESC',
      );
      return List.generate(maps.length, (i) => BoothApplication.fromMap(maps[i]));
    } catch (e) {
      throw Exception('Failed to get booth applications by exhibition: $e');
    }
  }

  // ==================== DASHBOARD/REPORTING HELPERS ====================

  Future<int> getExhibitionsCountByStatus(String status) async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) as c FROM exhibitions WHERE status = ?',
        [status],
      );
      return (rows.first['c'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Failed to get exhibitions count: $e');
    }
  }

  Future<int> getBoothApplicationsCountByStatus(String status) async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) as c FROM booth_applications WHERE status = ?',
        [status],
      );
      return (rows.first['c'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Failed to get booth applications count: $e');
    }
  }

  Future<int> getTotalBoothsCount() async {
    try {
      final db = await database;
      final rows = await db.rawQuery(
        'SELECT COALESCE(SUM(COALESCE(totalBooths, 0)), 0) as s FROM exhibitions',
      );
      return (rows.first['s'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Failed to get total booths count: $e');
    }
  }

  Future<int> getApprovedApplicationsCreatedTodayCount() async {
    try {
      final db = await database;
      final todayPrefix = DateTime.now().toIso8601String().substring(0, 10);
      final rows = await db.rawQuery(
        'SELECT COUNT(*) as c FROM booth_applications WHERE status = ? AND createdAt LIKE ?',
        ['Approved', '$todayPrefix%'],
      );
      return (rows.first['c'] as int?) ?? 0;
    } catch (e) {
      throw Exception('Failed to get approved-today count: $e');
    }
  }

  // Update booth application status or full record
  Future<void> updateBoothApplication(BoothApplication application) async {
    try {
      final db = await database;
      await db.update(
        'booth_applications',
        application.toMap(),
        where: 'id = ?',
        whereArgs: [application.id],
      );
    } catch (e) {
      throw Exception('Failed to update booth application: $e');
    }
  }

  Future<void> updateBoothApplicationStatus(int id, String status) async {
    try {
      final db = await database;
      await db.update(
        'booth_applications',
        {
          'status': status,
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to update application status: $e');
    }
  }

  Future<void> updateBoothApplicationStatusWithReason(int id, String status, {String? reason}) async {
    try {
      final db = await database;
      await db.update(
        'booth_applications',
        {
          'status': status,
          'decisionReason': reason ?? '',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to update application status: $e');
    }
  }

  // Delete booth application
  Future<void> deleteBoothApplication(int id) async {
    try {
      final db = await database;
      await db.delete(
        'booth_applications',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete booth application: $e');
    }
  }

  // Login - Check if user exists with matching email and password
  Future<LoginUser?> login(String email, String password) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'email = ? AND password = ?',
        whereArgs: [email, password],
      );

      if (maps.isNotEmpty) {
        return LoginUser.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw Exception('Login failed: $e');
    }
  }

  // Register - Create new user account
  Future<LoginUser> register(LoginUser user) async {
    try {
      final db = await database;
      final newUser = LoginUser(
        email: user.email,
        password: user.password,
        fullName: user.fullName,
        role: user.role ?? 'user',
        createdAt: DateTime.now(),
      );

      final id = await db.insert('users', newUser.toMap());
      return newUser.copyWith(id: id);
    } catch (e) {
      throw Exception('Registration failed: $e');
    }
  }

  // Get user by email
  Future<LoginUser?> getUserByEmail(String email) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'users',
        where: 'email = ?',
        whereArgs: [email],
      );

      if (maps.isNotEmpty) {
        return LoginUser.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Update user
  Future<void> updateUser(LoginUser user) async {
    try {
      final db = await database;
      await db.update(
        'users',
        user.toMap(),
        where: 'id = ?',
        whereArgs: [user.id],
      );
    } catch (e) {
      throw Exception('Update failed: $e');
    }
  }

  // Delete user
  Future<void> deleteUser(int id) async {
    try {
      final db = await database;
      await db.delete(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Delete failed: $e');
    }
  }

  // Get all users
  Future<List<LoginUser>> getAllUsers() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('users');
      return List.generate(maps.length, (i) => LoginUser.fromMap(maps[i]));
    } catch (e) {
      throw Exception('Failed to get users: $e');
    }
  }

  // ==================== EXHIBITION OPERATIONS ====================

  // Create new exhibition
  Future<Exhibition> createExhibition(Exhibition exhibition) async {
    try {
      final db = await database;
      final user = _currentUser;
      final isAdmin = (user?.role ?? '').toLowerCase() == 'admin';
      final organizerId = isAdmin ? exhibition.organizerId : user?.id;
      final newExhibition = Exhibition(
        organizerId: organizerId,
        name: exhibition.name,
        description: exhibition.description,
        startDate: exhibition.startDate,
        endDate: exhibition.endDate,
        location: exhibition.location,
        status: exhibition.status,
        totalBooths: exhibition.totalBooths,
        isPublished: exhibition.isPublished,
        blockAdjacentCompetitors: exhibition.blockAdjacentCompetitors,
        industryCategories: exhibition.industryCategories,
        createdAt: DateTime.now(),
      );

      final id = await db.insert('exhibitions', newExhibition.toMap());
      return newExhibition.copyWith(id: id);
    } catch (e) {
      throw Exception('Failed to create exhibition: $e');
    }
  }

  // Get all exhibitions
  Future<List<Exhibition>> getAllExhibitions() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'exhibitions',
        orderBy: 'createdAt DESC',
      );
      return List.generate(maps.length, (i) => Exhibition.fromMap(maps[i]));
    } catch (e) {
      throw Exception('Failed to get exhibitions: $e');
    }
  }

  // Organizer-only: get exhibitions owned by the current organizer.
  Future<List<Exhibition>> getMyExhibitions() async {
    final user = _currentUser;
    if (user == null) return <Exhibition>[];
    if ((user.role ?? '').toLowerCase() != 'organizer') {
      return getAllExhibitions();
    }
    try {
      final db = await database;
      final maps = await db.query(
        'exhibitions',
        where: 'organizerId = ?',
        whereArgs: [user.id],
        orderBy: 'createdAt DESC',
      );
      return List.generate(maps.length, (i) => Exhibition.fromMap(maps[i]));
    } catch (e) {
      throw Exception('Failed to get my exhibitions: $e');
    }
  }

  Future<List<Exhibition>> getPublishedExhibitions() async {
    try {
      final db = await database;
      final maps = await db.query(
        'exhibitions',
        where: 'isPublished = 1',
        orderBy: 'createdAt DESC',
      );
      return List.generate(maps.length, (i) => Exhibition.fromMap(maps[i]));
    } catch (e) {
      throw Exception('Failed to get published exhibitions: $e');
    }
  }

  // Get exhibition by id
  Future<Exhibition?> getExhibitionById(int id) async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'exhibitions',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return Exhibition.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get exhibition: $e');
    }
  }

  // Update exhibition
  Future<void> updateExhibition(Exhibition exhibition) async {
    try {
      final db = await database;
      await db.update(
        'exhibitions',
        exhibition.toMap(),
        where: 'id = ?',
        whereArgs: [exhibition.id],
      );
    } catch (e) {
      throw Exception('Failed to update exhibition: $e');
    }
  }

  // Delete exhibition
  Future<void> deleteExhibition(int id) async {
    try {
      final db = await database;
      await db.delete(
        'exhibitions',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw Exception('Failed to delete exhibition: $e');
    }
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // Current user helpers
  void setCurrentUser(LoginUser? user) {
    _currentUser = user;
    print('DATABASE - Current user set: ${user?.email}');
  }

  LoginUser? getCurrentUser() {
    return _currentUser;
  }

  // Reset database - useful for debugging
  Future<void> resetDatabase() async {
    final db = await database;
    await db.execute('DROP TABLE IF EXISTS users');
    await db.execute('DROP TABLE IF EXISTS exhibitions');
    await db.execute('DROP TABLE IF EXISTS booth_applications');
    await db.execute('DROP TABLE IF EXISTS floor_plans');
    await db.execute('DROP TABLE IF EXISTS booth_layouts');
    await db.execute('DROP TABLE IF EXISTS booth_types');
    await db.execute('DROP TABLE IF EXISTS add_ons');
    await _onCreate(db, 7);
  }

  // ==================== BOOTH TYPE OPERATIONS ====================

  Map<String, dynamic> _normalizeBoothTypeRow(Map<String, dynamic> row) {
    final featuresRaw = row['features']?.toString();
    List<String> features = const <String>[];
    if (featuresRaw != null && featuresRaw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(featuresRaw);
        if (decoded is List) {
          features = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        // ignore malformed legacy data
      }
    }
    return {
      ...row,
      'features': features,
    };
  }

  Future<List<Map<String, dynamic>>> getBoothTypes() async {
    final db = await database;
    try {
      final user = _currentUser;
      final role = (user?.role ?? '').toLowerCase();

      final List<Map<String, dynamic>> rows;
      if (role == 'organizer' && user?.id != null) {
        rows = await db.query(
          'booth_types',
          where: 'organizerId = ? OR organizerId IS NULL',
          whereArgs: [user!.id],
          orderBy: 'name COLLATE NOCASE ASC',
        );
      } else {
        rows = await db.query('booth_types', orderBy: 'name COLLATE NOCASE ASC');
      }
      return rows.map(_normalizeBoothTypeRow).toList();
    } catch (e) {
      print('DATABASE - getBoothTypes failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<int> createBoothType({
    required String name,
    String? size,
    String? price,
    List<String>? features,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final user = _currentUser;
    final role = (user?.role ?? '').toLowerCase();
    final organizerId = (role == 'organizer') ? user?.id : null;
    return db.insert('booth_types', {
      'organizerId': organizerId,
      'name': name,
      'size': size,
      'price': price,
      'features': jsonEncode(features ?? <String>[]),
      'createdAt': now,
    });
  }

  Future<int> updateBoothType({
    required int id,
    required String name,
    String? size,
    String? price,
    List<String>? features,
  }) async {
    final db = await database;
    final user = _currentUser;
    final role = (user?.role ?? '').toLowerCase();

    if (role == 'organizer' && user?.id != null) {
      return db.update(
        'booth_types',
        {
          'name': name,
          'size': size,
          'price': price,
          'features': jsonEncode(features ?? <String>[]),
        },
        where: 'id = ? AND organizerId = ?',
        whereArgs: [id, user!.id],
      );
    }
    return db.update(
      'booth_types',
      {
        'name': name,
        'size': size,
        'price': price,
        'features': jsonEncode(features ?? <String>[]),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBoothType(int id) async {
    final db = await database;
    final user = _currentUser;
    final role = (user?.role ?? '').toLowerCase();
    if (role == 'organizer' && user?.id != null) {
      return db.delete('booth_types', where: 'id = ? AND organizerId = ?', whereArgs: [id, user!.id]);
    }
    return db.delete('booth_types', where: 'id = ?', whereArgs: [id]);
  }

  // ==================== ADD-ON OPERATIONS ====================

  Future<List<Map<String, dynamic>>> getAddOnsForOrganizer(int organizerId) async {
    final db = await database;
    try {
      return db.query(
        'add_ons',
        where: 'organizerId = ?',
        whereArgs: [organizerId],
        orderBy: 'name COLLATE NOCASE ASC',
      );
    } catch (e) {
      print('DATABASE - getAddOnsForOrganizer failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> getAddOnsForExhibition(int exhibitionId) async {
    final db = await database;
    try {
      final exMaps = await db.query('exhibitions', columns: ['organizerId'], where: 'id = ?', whereArgs: [exhibitionId], limit: 1);
      if (exMaps.isEmpty) return <Map<String, dynamic>>[];
      final organizerId = (exMaps.first['organizerId'] as num?)?.toInt();
      if (organizerId == null) return <Map<String, dynamic>>[];
      return getAddOnsForOrganizer(organizerId);
    } catch (e) {
      print('DATABASE - getAddOnsForExhibition failed: $e');
      return <Map<String, dynamic>>[];
    }
  }

  Future<int> createAddOn({required String name, String? price}) async {
    final user = _currentUser;
    if (user == null || (user.role ?? '').toLowerCase() != 'organizer') {
      throw Exception('Only organizers can create add-ons');
    }
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return db.insert('add_ons', {
      'organizerId': user.id,
      'name': name,
      'price': price,
      'createdAt': now,
    });
  }

  Future<int> updateAddOn({required int id, required String name, String? price}) async {
    final user = _currentUser;
    if (user == null || (user.role ?? '').toLowerCase() != 'organizer') {
      throw Exception('Only organizers can update add-ons');
    }
    final db = await database;
    return db.update(
      'add_ons',
      {
        'name': name,
        'price': price,
      },
      where: 'id = ? AND organizerId = ?',
      whereArgs: [id, user.id],
    );
  }

  Future<int> deleteAddOn(int id) async {
    final user = _currentUser;
    if (user == null || (user.role ?? '').toLowerCase() != 'organizer') {
      throw Exception('Only organizers can delete add-ons');
    }
    final db = await database;
    return db.delete('add_ons', where: 'id = ? AND organizerId = ?', whereArgs: [id, user.id]);
  }

  // ==================== FLOOR PLAN OPERATIONS ====================

  // Save a floor plan metadata record
  Future<int> saveFloorPlan(Map<String, dynamic> floorPlan) async {
    try {
      final db = await database;
      // keep only one record per app — insert a new row
      final id = await db.insert('floor_plans', floorPlan);
      return id;
    } catch (e) {
      throw Exception('Failed to save floor plan: $e');
    }
  }

  // Get the latest floor plan
  Future<Map<String, dynamic>?> getFloorPlan() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('floor_plans', orderBy: 'id DESC', limit: 1);
      if (maps.isNotEmpty) return maps.first;
      return null;
    } catch (e) {
      throw Exception('Failed to get floor plan: $e');
    }
  }

  // Get the latest floor plan for a specific exhibition
  Future<Map<String, dynamic>?> getFloorPlanForExhibition(int exhibitionId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'floor_plans',
        where: 'exhibitionId = ?',
        whereArgs: [exhibitionId],
        orderBy: 'id DESC',
        limit: 1,
      );
      if (maps.isNotEmpty) return maps.first;
      return null;
    } catch (e) {
      throw Exception('Failed to get floor plan for exhibition: $e');
    }
  }

  // Delete a floor plan by id (also attempts to delete the file)
  Future<void> deleteFloorPlanById(int id) async {
    try {
      final db = await database;
      final existing = await db.query('floor_plans', where: 'id = ?', whereArgs: [id]);
      if (existing.isNotEmpty) {
        final filePath = existing.first['filePath'] as String?;
        if (filePath != null && filePath.isNotEmpty) {
          try {
            final f = File(filePath);
            if (await f.exists()) await f.delete();
          } catch (e) {
            print('DATABASE - Failed to delete floor plan file: $e');
          }
        }
      }
      await db.delete('floor_plans', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to delete floor plan: $e');
    }
  }

  // ==================== BOOTH LAYOUT OPERATIONS ====================

  // Layout scopes
  // - default: used by organizers (and as fallback)
  // - admin_override: admin-specific override layout
  Future<void> upsertBoothLayout({
    required int exhibitionId,
    required String scope,
    required List<Map<String, dynamic>> booths,
  }) async {
    try {
      final db = await database;
      final nowIso = DateTime.now().toIso8601String();
      await db.insert(
        'booth_layouts',
        {
          'exhibitionId': exhibitionId,
          'scope': scope,
          'data': jsonEncode(booths),
          'updatedAt': nowIso,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw Exception('Failed to save booth layout: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getBoothLayout(int exhibitionId, String scope) async {
    try {
      final db = await database;
      final rows = await db.query(
        'booth_layouts',
        where: 'exhibitionId = ? AND scope = ?',
        whereArgs: [exhibitionId, scope],
        limit: 1,
      );
      if (rows.isEmpty) return [];

      final data = rows.first['data'] as String?;
      if (data == null || data.isEmpty) return [];

      final decoded = jsonDecode(data);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((m) => m.map((k, v) => MapEntry(k.toString(), v)))
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      throw Exception('Failed to load booth layout: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getEffectiveBoothLayout(int exhibitionId) async {
    final overrideLayout = await getBoothLayout(exhibitionId, 'admin_override');
    if (overrideLayout.isNotEmpty) return overrideLayout;
    return getBoothLayout(exhibitionId, 'default');
  }
}

extension _LoginUserCopyWith on LoginUser {
  LoginUser copyWith({
    int? id,
    String? email,
    String? password,
    String? fullName,
    String? role,
    DateTime? createdAt,
  }) {
    return LoginUser(
      id: id ?? this.id,
      email: email ?? this.email,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

extension _ExhibitionCopyWith on Exhibition {
  Exhibition copyWith({
    int? id,
    String? name,
    String? description,
    String? startDate,
    String? endDate,
    String? location,
    String? status,
    int? totalBooths,
    bool? isPublished,
    DateTime? createdAt,
  }) {
    return Exhibition(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      status: status ?? this.status,
      totalBooths: totalBooths ?? this.totalBooths,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
