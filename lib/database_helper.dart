import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('loan_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        account_no TEXT NOT NULL UNIQUE,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE loans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        client_id INTEGER NOT NULL,
        principal REAL NOT NULL,
        interest REAL NOT NULL,
        total_payable REAL NOT NULL,
        daily_target REAL NOT NULL,
        outstanding_balance REAL NOT NULL,
        arrears REAL NOT NULL DEFAULT 0.0,
        status TEXT NOT NULL,
        disbursed_at TEXT NOT NULL,
        FOREIGN KEY (client_id) REFERENCES clients (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        loan_id INTEGER NOT NULL,
        client_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        channel TEXT NOT NULL,
        narration TEXT,
        entry_date TEXT NOT NULL,
        status TEXT NOT NULL,
        FOREIGN KEY (loan_id) REFERENCES loans (id),
        FOREIGN KEY (client_id) REFERENCES clients (id)
      )
    ''');
  }

  Future<int> createClient(String name, String phone) async {
    final db = await instance.database;
    String accNo = "ACC${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    return await db.insert('clients', {
      'name': name,
      'phone': phone,
      'account_no': accNo,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> searchClients(String query) async {
    final db = await instance.database;
    return await db.query(
      'clients',
      where: 'name LIKE ? OR account_no LIKE ? OR phone LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
    );
  }

  Future<int> disburseLoan(int clientId, double principal) async {
    final db = await instance.database;
    double interest = principal * 0.20;
    double totalPayable = principal + interest;
    double dailyTarget = totalPayable / 30;

    return await db.insert('loans', {
      'client_id': clientId,
      'principal': principal,
      'interest': interest,
      'total_payable': totalPayable,
      'daily_target': dailyTarget,
      'outstanding_balance': totalPayable,
      'arrears': 0.0,
      'status': 'Active',
      'disbursed_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getActiveLoan(int clientId) async {
    final db = await instance.database;
    final res = await db.query(
      'loans',
      where: 'client_id = ? AND status = ?',
      whereArgs: [clientId, 'Active'],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> saveBatchTransactions(List<Map<String, dynamic>> txList) async {
    final db = await instance.database;
    Batch batch = db.batch();

    for (var tx in txList) {
      batch.insert('transactions', {
        'loan_id': tx['loan_id'],
        'client_id': tx['client_id'],
        'amount': tx['amount'],
        'channel': tx['channel'],
        'narration': tx['narration'],
        'entry_date': DateTime.now().toIso8601String(),
        'status': 'Posted',
      });

      batch.execute('''
        UPDATE loans 
        SET outstanding_balance = outstanding_balance - ${tx['amount']},
            status = CASE WHEN (outstanding_balance - ${tx['amount']}) <= 0 THEN 'Settled' ELSE 'Active' END
        WHERE id = ${tx['loan_id']}
      ''');
    }

    await batch.commit(noResult: true);
  }

  Future<List<Map<String, dynamic>>> getLoanStatement(int loanId) async {
    final db = await instance.database;
    return await db.query(
      'transactions',
      where: 'loan_id = ? AND status = ?',
      whereArgs: [loanId, 'Posted'],
      orderBy: 'entry_date DESC',
    );
  }
}
