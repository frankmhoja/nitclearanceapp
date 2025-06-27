import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../provider/auth_provider.dart';
import '../provider/clearance_state_provider.dart';

// [Previous downloadFile function remains unchanged]
Future<void> downloadFile(String url, String filename) async {
  var status = await Permission.storage.request();
  if (!status.isGranted) {
    Fluttertoast.showToast(msg: 'Storage permission denied');
    return;
  }

  try {
    Directory downloadsDir = Directory('/storage/emulated/0/Download');
    if (!downloadsDir.existsSync()) {
      downloadsDir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
    }

    final filePath = path.join(downloadsDir.path, filename);
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();

    if (response.statusCode == 200) {
      List<int> bytes = [];
      final contentLength = response.contentLength ?? 0;
      int received = 0;

      await for (var chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        double progress = (received / contentLength) * 100;
        print('Progress: ${progress.toStringAsFixed(0)}%');
      }

      final file = File(filePath);
      await file.writeAsBytes(bytes);
      Fluttertoast.showToast(msg: 'File saved to: $filePath');
    } else {
      Fluttertoast.showToast(msg: 'Download failed: HTTP ${response.statusCode}');
    }
  } catch (e) {
    Fluttertoast.showToast(msg: 'Error: $e');
  }
}

class ClearanceFeedbackScreen extends StatefulWidget {
  const ClearanceFeedbackScreen({super.key});

  @override
  _ClearanceFeedbackScreenState createState() => _ClearanceFeedbackScreenState();
}

class _ClearanceFeedbackScreenState extends State<ClearanceFeedbackScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    final clearanceProvider = Provider.of<ClearanceStateProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user != null && authProvider.accessToken != null) {
      await clearanceProvider.initialize(authProvider.user!.username, authProvider.accessToken!);
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final clearanceProvider = Provider.of<ClearanceStateProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final feedbacks = clearanceProvider.feedbacks;

    if (!authProvider.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Clearance Feedback'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: const Center(
          child: Text(
            'Please log in to view feedback.',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clearance Feedback'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadFeedbacks,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Feedback for Clearance Requests',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: feedbacks.isEmpty
                    ? const Center(
                  child: Text(
                    'No feedback available.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
                    : ListView.builder(
                  itemCount: feedbacks.length,
                  itemBuilder: (context, index) {
                    final feedback = feedbacks[index];
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8.0),
                      child: ListTile(
                        title: Text(
                          '${feedback.property} - ${feedback.status}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RegNo: ${feedback.regNo}'),
                            Text('Name: ${feedback.name}'),
                            Text('Department: ${feedback.department}'),
                            Text('Date: ${feedback.date}'),
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.indigo),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FeedbackDocumentViewer(feedback: feedback),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedbackDocumentViewer extends StatefulWidget {
  final ClearanceFeedback feedback;

  const FeedbackDocumentViewer({super.key, required this.feedback});

  @override
  _FeedbackDocumentViewerState createState() => _FeedbackDocumentViewerState();
}

class _FeedbackDocumentViewerState extends State<FeedbackDocumentViewer> {
  bool _isGeneratingPDF = false;

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'returned':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'not accounted':
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'returned':
        return Icons.assignment_return;
      case 'pending':
        return Icons.hourglass_empty;
      case 'not accounted':
        return Icons.error;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<bool> _isSupportedPlatform() async {
    try {
      if (kIsWeb) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF download is not supported on web platform.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
      if (!Platform.isAndroid && !Platform.isIOS) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('PDF download is only supported on Android and iOS.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking platform: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error checking platform: $e');
      return false;
    }
  }

  Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isIOS) {
        return true; // iOS doesn't require explicit storage permissions
      }

      if (Platform.isAndroid) {
        // Check permission status
        final permission = await Permission.storage.status;
        final manageStorage = await Permission.manageExternalStorage.status;

        if (permission.isGranted || manageStorage.isGranted) {
          print('Storage permissions already granted');
          return true;
        }

        // Request permissions
        final statuses = await [
          Permission.storage,
          Permission.manageExternalStorage,
        ].request();

        final storageGranted = statuses[Permission.storage]?.isGranted ?? false;
        final manageStorageGranted = statuses[Permission.manageExternalStorage]?.isGranted ?? false;

        if (storageGranted || manageStorageGranted) {
          print('Storage permissions granted');
          return true;
        }

        // Handle permission denial
        if (mounted) {
          final permanentlyDenied = statuses[Permission.storage]?.isPermanentlyDenied ?? false ||
              statuses[Permission.manageExternalStorage]!.isPermanentlyDenied ?? false;

          await showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Storage Permission Required'),
                content: Text(
                  permanentlyDenied
                      ? 'Storage access is permanently denied. Please enable "All files access" in app settings.'
                      : 'Storage access is required to save PDF files. Please grant permissions.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (permanentlyDenied) {
                        openAppSettings();
                      }
                    },
                    child: Text(permanentlyDenied ? 'Open Settings' : 'OK'),
                  ),
                ],
              );
            },
          );
        }
        print('Storage permissions denied');
        return false;
      }
      return false;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      print('Error requesting permission: $e');
      return false;
    }
  }

  Future<void> _downloadPDF() async {
    if (_isGeneratingPDF) {
      print('Download already in progress');
      return;
    }

    // Check platform compatibility
    final isSupported = await _isSupportedPlatform();
    if (!isSupported) {
      print('Platform not supported for PDF download');
      return;
    }

    // Confirm download with user
    final shouldDownload = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Download PDF'),
          content: const Text('Do you want to download this feedback as a PDF document to your Downloads folder?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );

    if (shouldDownload != true) {
      print('User cancelled download');
      return;
    }

    // Request storage permissions
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      print('Permission not granted for download');
      return;
    }

    setState(() {
      _isGeneratingPDF = true;
    });

    try {
      // Create PDF document
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor(0.247, 0.318, 0.710), // 0xFF3F51B5
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          'NIT Clearance Feedback Report',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                _buildPDFContent(),
                pw.Spacer(),
                pw.Divider(color: const PdfColor(0.878, 0.878, 0.878)), // 0xFFE0E0E0
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated on: ${DateTime.now().toString().split('.')[0]}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: const PdfColor(0.502, 0.502, 0.502), // 0xFF808080
                  ),
                ),
              ],
            );
          },
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      // Sanitize regNo to avoid invalid characters in file name
      final sanitizedRegNo = widget.feedback.regNo.replaceAll(RegExp(r'[^\w\d]'), '_');
      final fileName = 'clearance_feedback_${sanitizedRegNo}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      if (Platform.isAndroid) {
        // Use the standard Android Downloads directory
        final downloadsDir = Directory('/storage/emulated/0/Download');
        try {
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
            print('Created Downloads directory: ${downloadsDir.path}');
          }

          final filePath = path.join(downloadsDir.path, fileName);
          final file = File(filePath);

          await file.writeAsBytes(pdfBytes);
          print('PDF saved successfully at: $filePath');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('PDF downloaded Successfully'),
                backgroundColor: Colors.green,
                action: SnackBarAction(
                  label: 'Open',
                  onPressed: () => _openPDF(filePath),
                ),
              ),
            );
          }
        } catch (e) {
          print('Error saving PDF to Downloads: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error saving PDF to Downloads: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else if (Platform.isIOS) {
        final tempDir = await getTemporaryDirectory();
        final filePath = path.join(tempDir.path, fileName);
        final file = File(filePath);

        try {
          await file.writeAsBytes(pdfBytes);
          print('PDF saved temporarily at: $filePath');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PDF generated successfully!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          print('Error saving PDF on iOS: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error generating PDF: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPDF = false;
        });
      }
    }
  }

  pw.Widget _buildPDFContent() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor(0.878, 0.878, 0.878)), // 0xFFE0E0E0
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _getPDFStatusColor(widget.feedback.status),
              borderRadius: pw.BorderRadius.circular(20),
            ),
            child: pw.Text(
              widget.feedback.status.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder.all(color: const PdfColor(0.878, 0.878, 0.878)), // 0xFFE0E0E0
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(2),
            },
            children: [
              _buildPDFTableRow('Property', widget.feedback.property, isHeader: true),
              _buildPDFTableRow('Registration Number', widget.feedback.regNo),
              _buildPDFTableRow('Full Name', widget.feedback.name),
              _buildPDFTableRow('Department', widget.feedback.department),
              _buildPDFTableRow('Authorized Signature', widget.feedback.sign),
              _buildPDFTableRow('Date Processed', widget.feedback.date),
              if (widget.feedback.status == 'Rejected' && widget.feedback.rejectionReason.isNotEmpty)
                _buildPDFTableRow('Rejection Reason', widget.feedback.rejectionReason, isImportant: true),
            ],
          ),
        ],
      ),
    );
  }

  PdfColor _getPDFStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'returned':
        return const PdfColor(0.298, 0.686, 0.314); // 0xFF4CAF50
      case 'pending':
        return const PdfColor(1.0, 0.596, 0.0); // 0xFFFF9800
      case 'not accounted':
      case 'rejected':
        return const PdfColor(0.957, 0.267, 0.212); // 0xFFF44336
      default:
        return const PdfColor(0.620, 0.620, 0.620); // 0xFF9E9E9E
    }
  }

  pw.TableRow _buildPDFTableRow(String label, String value, {bool isHeader = false, bool isImportant = false}) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(12),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isImportant ? const PdfColor(0.957, 0.267, 0.212) : const PdfColor(0.0, 0.0, 0.0), // 0xFFF44336 or 0xFF000000
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(12),
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isImportant ? const PdfColor(0.957, 0.267, 0.212) : const PdfColor(0.0, 0.0, 0.0), // 0xFFF44336 or 0xFF000000
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openPDF(String filePath) async {
    try {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved at: $filePath'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error opening PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback Document'),
        backgroundColor: Theme.of(context).primaryColor,
        actions: [
          IconButton(
            onPressed: _isGeneratingPDF ? null : _downloadPDF,
            icon: _isGeneratingPDF
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.download),
            tooltip: 'Download PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo.shade700, Colors.indigo.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NIT Clearance Feedback',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Official Document',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(widget.feedback.status),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _getStatusIcon(widget.feedback.status),
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.feedback.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDocumentRow('Property', widget.feedback.property, isHeader: true),
                  _buildDocumentRow('Registration Number', widget.feedback.regNo),
                  _buildDocumentRow('Full Name', widget.feedback.name),
                  _buildDocumentRow('Department', widget.feedback.department),
                  _buildDocumentRow('Authorized Signature', widget.feedback.sign),
                  _buildDocumentRow('Date Processed', widget.feedback.date),
                  if (widget.feedback.status == 'Rejected' && widget.feedback.rejectionReason.isNotEmpty)
                    _buildDocumentRow('Rejection Reason', widget.feedback.rejectionReason, isImportant: true),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGeneratingPDF ? null : _downloadPDF,
                icon: _isGeneratingPDF
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.download),
                label: Text(_isGeneratingPDF ? 'Generating PDF...' : 'Download as PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Document generated on: ${DateTime.now().toString().split('.')[0]}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentRow(String label, String value, {bool isHeader = false, bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isImportant ? Colors.red : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? 'N/A' : value,
            style: TextStyle(
              fontSize: isHeader ? 18 : 16,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
              color: isImportant ? Colors.red : Colors.black87,
            ),
          ),
          if (isImportant) const SizedBox(height: 8),
          if (isImportant && label == 'Rejection Reason') const Divider(color: Colors.red, thickness: 1),
        ],
      ),
    );
  }
}