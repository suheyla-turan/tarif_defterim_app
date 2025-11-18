import 'package:flutter/material.dart';
import '../../../core/providers/localization_provider.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.faq),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FAQItem(
            question: l10n.faqQuestion1,
            answer: l10n.faqAnswer1,
          ),
          const SizedBox(height: 16),
          _FAQItem(
            question: l10n.faqQuestion2,
            answer: l10n.faqAnswer2,
          ),
          const SizedBox(height: 16),
          _FAQItem(
            question: l10n.faqQuestion3,
            answer: l10n.faqAnswer3,
          ),
          const SizedBox(height: 16),
          _FAQItem(
            question: l10n.faqQuestion4,
            answer: l10n.faqAnswer4,
          ),
          const SizedBox(height: 16),
          _FAQItem(
            question: l10n.faqQuestion5,
            answer: l10n.faqAnswer5,
          ),
        ],
      ),
    );
  }
}

class _FAQItem extends StatefulWidget {
  final String question;
  final String answer;

  const _FAQItem({
    required this.question,
    required this.answer,
  });

  @override
  State<_FAQItem> createState() => _FAQItemState();
}

class _FAQItemState extends State<_FAQItem> {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(
          widget.question,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              widget.answer,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

