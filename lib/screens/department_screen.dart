import 'package:flutter/material.dart';

class DepartmentScreen extends StatelessWidget {
  final String departmentId;
  final String departmentName;
  final List<Map<String, dynamic>> parameters;

  const DepartmentScreen({
    super.key,
    required this.departmentId,
    required this.departmentName,
    required this.parameters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(departmentName),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Department ID: $departmentId',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Text(
                  'Clearance Items:',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _buildParametersTable(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParametersTable(BuildContext context) {
    return DataTable(
      columnSpacing: 16,
      border: TableBorder.all(color: Colors.grey.shade300),
      columns: const [
        DataColumn(
          label: Text(
            'Property',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Value',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Status',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Date',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        DataColumn(
          label: Text(
            'Sign',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
      rows: parameters.map((param) {
        final value = param['value'] is List
            ? (param['value'] as List).join(', ')
            : param['value'].toString();
        return DataRow(
          cells: [
            DataCell(
              Text(
                param['property'] as String,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            DataCell(
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            DataCell(
              Text(
                param['status'] as String,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: param['status'] == 'Approved'
                          ? Colors.green
                          : param['status'] == 'Pending'
                              ? Colors.orange
                              : param['status'] == 'Returned'
                                  ? Colors.green
                                  : param['status'] == 'Not Accounted'
                                      ? Colors.red
                                      : Colors.black,
                    ),
              ),
            ),
            DataCell(
              Text(
                param['date'] as String,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            DataCell(
              Text(
                param['sign'] as String,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
