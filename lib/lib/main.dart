import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'db_helper.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ConstructionFinanceApp(),
  ));
}

class ConstructionFinanceApp extends StatefulWidget {
  const ConstructionFinanceApp({super.key});

  @override
  State<ConstructionFinanceApp> createState() => _ConstructionFinanceAppState();
}

class _ConstructionFinanceAppState extends State<ConstructionFinanceApp> {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
  final int activeProjectId = 1;

  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double totalLabor = 0.0;
  double netProfit = 0.0;
  List<Map<String, dynamic>> recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final summary = await DatabaseHelper.instance.getFinancialSummary(activeProjectId);
    final txs = await DatabaseHelper.instance.getTransactions(activeProjectId);
    setState(() {
      totalIncome = summary['income']!;
      totalExpense = summary['expense']!;
      totalLabor = summary['labor']!;
      netProfit = summary['profit']!;
      recentTransactions = txs;
    });
  }

  void _showAddEntryDialog(String type) {
    final amountController = TextEditingController();
    final detailsController = TextEditingController();
    final workersController = TextEditingController();
    final rateController = TextEditingController();
    String category = type == 'EXPENSE' ? 'Cement' : 'Client Payment';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          top: 20,
          left: 20,
          right: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              type == 'INCOME'
                  ? 'Add Client Income'
                  : type == 'EXPENSE'
                      ? 'Add Material Expense'
                      : 'Add Labor Payment',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (type == 'EXPENSE')
              DropdownButtonFormField<String>(
                value: category,
                items: ['Cement', 'Steel', 'Sand/Aggregates', 'Fuel', 'Machinery Rent', 'Misc']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => category = val!,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            if (type == 'LABOR') ...[
              TextField(
                controller: workersController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Workers'),
              ),
              TextField(
                controller: rateController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Daily Rate per Worker (₹)'),
              ),
            ] else ...[
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
            ],
            TextField(
              controller: detailsController,
              decoration: const InputDecoration(labelText: 'Remarks / Notes'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: type == 'INCOME' ? Colors.green : Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                double calculatedAmount = 0.0;
                String remarks = detailsController.text;

                if (type == 'LABOR') {
                  int workers = int.tryParse(workersController.text) ?? 0;
                  double rate = double.tryParse(rateController.text) ?? 0.0;
                  calculatedAmount = workers * rate;
                  remarks = '$workers workers @ ₹$rate/day. $remarks';
                } else {
                  calculatedAmount = double.tryParse(amountController.text) ?? 0.0;
                }

                if (calculatedAmount > 0) {
                  await DatabaseHelper.instance.insertTransaction({
                    'project_id': activeProjectId,
                    'type': type,
                    'category': type == 'LABOR' ? 'Labor Payment' : category,
                    'amount': calculatedAmount,
                    'details': remarks,
                    'date': DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now()),
                  });
                  Navigator.pop(ctx);
                  _refreshData();
                }
              },
              child: const Text('Save to Offline Ledger'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Construction Ledger (Offline)'),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                color: netProfit >= 0 ? Colors.green[800] : Colors.red[800],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('NET ESTIMATED PROFIT', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormat.format(netProfit),
                        style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _metricTile('Income', totalIncome, Colors.green[600]!),
                  _metricTile('Expenses', totalExpense, Colors.orange[800]!),
                  _metricTile('Labor', totalLabor, Colors.red[600]!),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Income'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
                      onPressed: () => _showAddEntryDialog('INCOME'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_cart, size: 18),
                      label: const Text('Material'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                      onPressed: () => _showAddEntryDialog('EXPENSE'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.groups, size: 18),
                      label: const Text('Labor'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700], foregroundColor: Colors.white),
                      onPressed: () => _showAddEntryDialog('LABOR'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Daily Ledger Entries', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              recentTransactions.isEmpty
                  ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No entries recorded yet.')))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentTransactions.length,
                      itemBuilder: (ctx, i) {
                        final tx = recentTransactions[i];
                        final isIncome = tx['type'] == 'INCOME';
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isIncome ? Colors.green[100] : Colors.red[100],
                              child: Icon(
                                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                                color: isIncome ? Colors.green[800] : Colors.red[800],
                              ),
                            ),
                            title: Text('${tx['category']} - ${currencyFormat.format(tx['amount'])}'),
                            subtitle: Text('${tx['date']}\n${tx['details'] ?? ''}'),
                            isThreeLine: tx['details'] != null && tx['details'].toString().isNotEmpty,
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile(String label, double val, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  currencyFormat.format(val),
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
