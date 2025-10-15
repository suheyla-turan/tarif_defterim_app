import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/recipes_provider.dart';
import '../constants/recipe_types.dart';

class AddRecipeScreen extends ConsumerStatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  ConsumerState<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends ConsumerState<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final List<TextEditingController> _ingredientCtrls = [TextEditingController()];
  final List<TextEditingController> _stepCtrls = [TextEditingController()];

  String _mainType = RecipeTypes.mainTypes.first;
  String? _subType;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _countryCtrl.dispose();
    for (final c in _ingredientCtrls) c.dispose();
    for (final c in _stepCtrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final addState = ref.watch(addRecipeControllerProvider);
    final addCtrl = ref.read(addRecipeControllerProvider.notifier);

    ref.listen(addRecipeControllerProvider, (prev, next) {
      if (prev?.submitting == true && next.submitting == false && next.error == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tarif eklendi')),
          );
          Navigator.pop(context);
        }
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final subTypes = RecipeTypes.subTypesOf(_mainType);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yeni Tarif'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Başlık'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _mainType,
                items: RecipeTypes.mainTypes
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Tür'),
                onChanged: (v) => setState(() {
                  _mainType = v!;
                  _subType = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _subType,
                items: subTypes
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                decoration: const InputDecoration(labelText: 'Alt tür (opsiyonel)'),
                onChanged: (v) => setState(() => _subType = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryCtrl,
                decoration:
                    const InputDecoration(labelText: 'Ülke (opsiyonel)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Açıklama (opsiyonel)'),
              ),
              const SizedBox(height: 16),
              Text('Malzemeler', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._ingredientCtrls.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: c,
                          decoration: InputDecoration(labelText: 'Malzeme #${i + 1}'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _ingredientCtrls.length > 1
                            ? () => setState(() => _ingredientCtrls.removeAt(i))
                            : null,
                      )
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _ingredientCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Malzeme ekle'),
                ),
              ),
              const SizedBox(height: 12),
              Text('Adımlar', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._stepCtrls.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: c,
                          decoration: InputDecoration(labelText: 'Adım #${i + 1}'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Zorunlu' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _stepCtrls.length > 1
                            ? () => setState(() => _stepCtrls.removeAt(i))
                            : null,
                      )
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _stepCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('Adım ekle'),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: addState.submitting
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final ingredients = _ingredientCtrls
                            .map((c) => c.text.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        final steps = _stepCtrls
                            .map((c) => c.text.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        await addCtrl.submit(
                          title: _titleCtrl.text,
                          description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
                          mainType: _mainType,
                          subType: _subType,
                          country: _countryCtrl.text.isEmpty ? null : _countryCtrl.text,
                          ingredients: ingredients,
                          steps: steps,
                        );
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(addState.submitting ? 'Kaydediliyor...' : 'Kaydet'),
              )
            ],
          ),
        ),
      ),
    );
  }
}


