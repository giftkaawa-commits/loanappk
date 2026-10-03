import 'package:flutter/material.dart';
import 'database_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LoanManagementApp());
}

class LoanManagementApp extends StatelessWidget {
  const LoanManagementApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PMMS Loan System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blueGrey,
        scaffoldBackgroundColor: const Color(0xFFF5F6F9),
        appBarTheme: const AppBarTheme(
          color: Color(0xFF2C3E50),
          elevation: 2,
        ),
      ),
      home: const MainHomeScreen(),
    );
  }
}

class MainHomeScreen extends StatefulWidget {
  const MainHomeScreen({Key? key}) : super(key: key);

  @override
  State<MainHomeScreen> createState() => _MainHomeScreenState();
}

class _MainHomeScreenState extends State<MainHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const BatchPostingScreen(),
    const DisbursementScreen(),
    const LoanCalculatorScreen(),
    const LoanStatementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF2C3E50),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Posting'),
          BottomNavigationBarItem(icon: Icon(Icons.add_card), label: 'Disburse'),
          BottomNavigationBarItem(icon: Icon(Icons.calculate), label: 'Calculator'),
          BottomNavigationBarItem(icon: Icon(Icons.analytics), label: 'Statements'),
        ],
      ),
    );
  }
}

class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  final _amountController = TextEditingController();
  double _principal = 0;
  double _interest = 0;
  double _totalPayable = 0;
  double _dailyPayment = 0;

  void _calculate() {
    double input = double.tryParse(_amountController.text) ?? 0;
    setState(() {
      _principal = input;
      _interest = input * 0.20;
      _totalPayable = _principal + _interest;
      _dailyPayment = _totalPayable / 30;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Calculator (30 Days / 20%)')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Enter Principal Loan Amount',
                border: OutlineInputBorder(),
                prefixText: 'UGX ',
              ),
              onChanged: (_) => _calculate(),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.white,
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _calcRow('Principal Amount:', 'UGX ${_principal.toStringAsFixed(0)}'),
                    const Divider(),
                    _calcRow('Interest (20%):', 'UGX ${_interest.toStringAsFixed(0)}', color: Colors.orange.shade800),
                    const Divider(),
                    _calcRow('Total Payable Amount:', 'UGX ${_totalPayable.toStringAsFixed(0)}', bold: true),
                    const Divider(),
                    _calcRow('Daily Target Repayment (30 Days):', 'UGX ${_dailyPayment.toStringAsFixed(0)}', color: Colors.green.shade800, bold: true),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _calcRow(String label, String val, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? Colors.black)),
        ],
      ),
    );
  }
}

class DisbursementScreen extends StatefulWidget {
  const DisbursementScreen({Key? key}) : super(key: key);

  @override
  State<DisbursementScreen> createState() => _DisbursementScreenState();
}

class _DisbursementScreenState extends State<DisbursementScreen> {
  bool _isNewClient = false;
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  
  Map<String, dynamic>? _selectedClient;
  List<Map<String, dynamic>> _searchResults = [];

  void _searchClient(String val) async {
    if (val.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await DatabaseHelper.instance.searchClients(val);
    setState(() => _searchResults = results);
  }

  void _processDisbursement() async {
    double principal = double.tryParse(_amountController.text) ?? 0;
    if (principal <= 0) return;

    int clientId;
    if (_isNewClient) {
      if (_nameController.text.isEmpty || _phoneController.text.isEmpty) return;
      clientId = await DatabaseHelper.instance.createClient(_nameController.text, _phoneController.text);
    } else {
      if (_selectedClient == null) return;
      clientId = _selectedClient!['id'];
    }

    await DatabaseHelper.instance.disburseLoan(clientId, principal);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Loan Disbursed Successfully! (20% Interest / 30 Days Applied)')),
    );

    _nameController.clear();
    _phoneController.clear();
    _amountController.clear();
    setState(() {
      _selectedClient = null;
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Disbursement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('Existing Client'),
                    value: false,
                    groupValue: _isNewClient,
                    onChanged: (val) => setState(() => _isNewClient = val!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<bool>(
                    title: const Text('New Client'),
                    value: true,
                    groupValue: _isNewClient,
                    onChanged: (val) => setState(() => _isNewClient = val!),
                  ),
                ),
              ],
            ),
            const Divider(),
            if (_isNewClient) ...[
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Client Full Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              ),
            ] else ...[
              TextField(
                onChanged: _searchClient,
                decoration: const InputDecoration(
                  labelText: 'Search Client (Name, Acc, or Phone)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              if (_selectedClient != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Selected: ${_selectedClient!['name']} (${_selectedClient!['account_no']})',
                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ),
              ..._searchResults.map((c) => ListTile(
                title: Text(c['name']),
                subtitle: Text('Acc: ${c['account_no']} | Phone: ${c['phone']}'),
                onTap: () {
                  setState(() {
                    _selectedClient = c;
                    _searchResults = [];
                  });
                },
              )),
            ],
            const SizedBox(height: 15),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Principal Amount to Disburse',
                prefixText: 'UGX ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50)),
                onPressed: _processDisbursement,
                child: const Text('CONFIRM DISBURSEMENT', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class BatchPostingScreen extends StatefulWidget {
  const BatchPostingScreen({Key? key}) : super(key: key);

  @override
  State<BatchPostingScreen> createState() => _BatchPostingScreenState();
}

class _BatchPostingScreenState extends State<BatchPostingScreen> {
  final List<Map<String, dynamic>> _batchQueue = [];
  
  Map<String, dynamic>? _selectedClient;
  Map<String, dynamic>? _activeLoan;
  List<Map<String, dynamic>> _searchResults = [];

  final _amountController = TextEditingController();
  final _narrationController = TextEditingController();
  String _selectedChannel = 'Cash';

  void _searchClient(String val) async {
    if (val.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await DatabaseHelper.instance.searchClients(val);
    setState(() => _searchResults = results);
  }

  void _selectClient(Map<String, dynamic> client) async {
    final loan = await DatabaseHelper.instance.getActiveLoan(client['id']);
    setState(() {
      _selectedClient = client;
      _activeLoan = loan;
      _searchResults = [];
    });
  }

  void _addToBatch() {
    if (_selectedClient == null || _activeLoan == null) return;
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    setState(() {
      _batchQueue.add({
        'client_id': _selectedClient!['id'],
        'client_name': _selectedClient!['name'],
        'phone': _selectedClient!['phone'],
        'loan_id': _activeLoan!['id'],
        'amount': amount,
        'channel': _selectedChannel,
        'narration': _narrationController.text.isEmpty ? 'Daily Loan Payment' : _narrationController.text,
        'current_balance': _activeLoan!['outstanding_balance'],
        'arrears': _activeLoan!['arrears'],
      });

      _selectedClient = null;
      _activeLoan = null;
      _amountController.clear();
      _narrationController.clear();
    });
  }

  void _postAllBatch() async {
    if (_batchQueue.isEmpty) return;

    await DatabaseHelper.instance.saveBatchTransactions(_batchQueue);

    for (var item in _batchQueue) {
      double newBalance = item['current_balance'] - item['amount'];
      _showSmsReceiptDialog(
        phone: item['phone'],
        name: item['client_name'],
        amountPaid: item['amount'],
        arrears: item['arrears'],
        newBalance: newBalance < 0 ? 0 : newBalance,
      );
    }

    setState(() {
      _batchQueue.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All batch payments posted and saved successfully!')),
    );
  }

  void _showSmsReceiptDialog({
    required String phone,
    required String name,
    required double amountPaid,
    required double arrears,
    required double newBalance,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.sms, color: Colors.blue),
            SizedBox(width: 8),
            Text('Automated SMS Receipt'),
          ],
        ),
        content: Text(
          'To: $phone\n\n'
          'Dear $name, payment of UGX ${amountPaid.toStringAsFixed(0)} received via $_selectedChannel. '
          'Arrears: UGX ${arrears.toStringAsFixed(0)}. Outstanding Balance: UGX ${newBalance.toStringAsFixed(0)}. '
          'Thank you for paying on time!',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Repayment & Batch Posting'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_upload),
            onPressed: _postAllBatch,
            tooltip: 'Save & Post All',
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              onChanged: _searchClient,
              decoration: const InputDecoration(
                labelText: 'Search Client (Repayment)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                dense: true,
              ),
            ),
            if (_searchResults.isNotEmpty)
              Container(
                height: 150,
                color: Colors.white,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(_searchResults[i]['name']),
                    subtitle: Text('Acc: ${_searchResults[i]['account_no']}'),
                    onTap: () => _selectClient(_searchResults[i]),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (_selectedClient != null) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Text('${_selectedClient!['name']} (${_selectedClient!['account_no']})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (_activeLoan != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text('Arrears: UGX ${_activeLoan!['arrears']}', style: const TextStyle(color: Colors.red)),
                            Text('Balance: UGX ${_activeLoan!['outstanding_balance']}', style: const TextStyle(color: Colors.blue)),
                            Text('Daily: UGX ${_activeLoan!['daily_target'].toStringAsFixed(0)}', style: const TextStyle(color: Colors.green)),
                          ],
                        ),
                      ] else
                        const Text('No Active Loan Found', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount Paid', border: OutlineInputBorder(), dense: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _selectedChannel,
                    items: ['Cash', 'Airtel Money', 'MTN MobileMoney']
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedChannel = val!),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _addToBatch,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('Add Transaction to Batch', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pending Batch (${_batchQueue.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
                ElevatedButton.icon(
                  onPressed: _postAllBatch,
                  icon: const Icon(Icons.save),
                  label: const Text('SAVE ALL'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2C3E50)),
                )
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _batchQueue.length,
                itemBuilder: (ctx, i) {
                  final tx = _batchQueue[i];
                  return Card(
                    child: ListTile(
                      dense: true,
                      title: Text('${tx['client_name']} - UGX ${tx['amount']}'),
                      subtitle: Text('Channel: ${tx['channel']} | Narration: ${tx['narration']}'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setState(() => _batchQueue.removeAt(i)),
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

class LoanStatementScreen extends StatefulWidget {
  const LoanStatementScreen({Key? key}) : super(key: key);

  @override
  State<LoanStatementScreen> createState() => _LoanStatementScreenState();
}

class _LoanStatementScreenState extends State<LoanStatementScreen> {
  List<Map<String, dynamic>> _searchResults = [];
  Map<String, dynamic>? _selectedClient;
  Map<String, dynamic>? _activeLoan;
  List<Map<String, dynamic>> _statementTx = [];

  void _searchClient(String val) async {
    if (val.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = await DatabaseHelper.instance.searchClients(val);
    setState(() => _searchResults = results);
  }

  void _selectClient(Map<String, dynamic> client) async {
    final loan = await DatabaseHelper.instance.getActiveLoan(client['id']);
    List<Map<String, dynamic>> txs = [];
    if (loan != null) {
      txs = await DatabaseHelper.instance.getLoanStatement(loan['id']);
    }
    setState(() {
      _selectedClient = client;
      _activeLoan = loan;
      _statementTx = txs;
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Client Loan Statement')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            TextField(
              onChanged: _searchClient,
              decoration: const InputDecoration(
                labelText: 'Search Client for Statement',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            if (_searchResults.isNotEmpty)
              Container(
                height: 150,
                color: Colors.white,
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (ctx, i) => ListTile(
                    title: Text(_searchResults[i]['name']),
                    subtitle: Text('Acc: ${_searchResults[i]['account_no']}'),
                    onTap: () => _selectClient(_searchResults[i]),
                  ),
                ),
              ),
            const SizedBox(height: 10),
            if (_selectedClient != null) ...[
              Card(
                child: ListTile(
                  title: Text(_selectedClient!['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Phone: ${_selectedClient!['phone']} | Acc: ${_selectedClient!['account_no']}'),
                ),
              ),
              if (_activeLoan != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Principal: UGX ${_activeLoan!['principal']}'),
                      Text('Balance: UGX ${_activeLoan!['outstanding_balance']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              const Divider(),
              const Text('Transaction History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Expanded(
                child: ListView.builder(
                  itemCount: _statementTx.length,
                  itemBuilder: (ctx, i) {
                    final tx = _statementTx[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          tx['channel'] == 'Cash' ? Icons.money : Icons.phone_android,
                          color: tx['channel'] == 'Cash' ? Colors.green : Colors.purple,
                        ),
                        title: Text('UGX ${tx['amount']} via ${tx['channel']}'),
                        subtitle: Text('Date: ${tx['entry_date'].toString().substring(0, 10)}'),
                        trailing: Text(tx['status'], style: const TextStyle(color: Colors.green)),
                      ),
                    );
                  },
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
