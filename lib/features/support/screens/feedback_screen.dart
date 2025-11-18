import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/localization_provider.dart';
import '../providers/support_provider.dart';

class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  int? _selectedRating;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = ref.read(authControllerProvider).user;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).sessionRequired)),
        );
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final repo = ref.read(supportRepositoryProvider);
      await repo.submitFeedback(
        userId: user.uid,
        userEmail: user.email,
        feedback: _feedbackController.text.trim(),
        rating: _selectedRating,
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.feedbackSubmitted),
            backgroundColor: Colors.green,
          ),
        );
        _feedbackController.clear();
        setState(() {
          _selectedRating = null;
        });
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.feedback),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.feedbackDescription,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Text(
                l10n.rating,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final rating = index + 1;
                  return IconButton(
                    icon: Icon(
                      _selectedRating != null && rating <= _selectedRating!
                          ? Icons.star
                          : Icons.star_border,
                      color: _selectedRating != null && rating <= _selectedRating!
                          ? Colors.amber
                          : null,
                      size: 40,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedRating = rating;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _feedbackController,
                decoration: InputDecoration(
                  labelText: l10n.feedback,
                  hintText: l10n.feedbackHint,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 10,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.required;
                  }
                  if (value.trim().length < 10) {
                    return l10n.feedbackMinLength;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.submit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

