import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/report_service.dart';

class ReportUserScreen extends StatefulWidget {
  const ReportUserScreen({super.key, required this.reportedUser});

  final AppUser reportedUser;

  @override
  State<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends State<ReportUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  final _reports = ReportService();

  String _reason = 'Harassment';
  bool _submitting = false;

  static const _reasons = [
    'Harassment',
    'Inappropriate language',
    'Spam',
    'Cheating or unfair behavior',
    'Other',
  ];

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await _reports.submitReport(
        reportedUserId: widget.reportedUser.uid,
        reason: _reason,
        details: _details.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted successfully.')),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report User')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Report @${widget.reportedUser.username}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const InputDecoration(
                  labelText: 'Reason for reporting',
                ),
                items: _reasons.map((reason) {
                  return DropdownMenuItem(value: reason, child: Text(reason));
                }).toList(),
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _reason = value);
                        }
                      },
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _details,
                maxLines: 5,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Additional details',
                  hintText: 'Describe what happened...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please describe the issue.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
