import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/recipes_provider.dart';
import '../constants/recipe_types.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

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
  final List<File> _pickedImages = [];
  bool _uploading = false;

  String _mainType = RecipeTypes.mainTypes.first;
  String? _subType;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden Seç'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1600);
    if (file == null) return;
    setState(() => _pickedImages.add(File(file.path)));
  }

  Future<List<String>> _uploadAllImages() async {
    if (_pickedImages.isEmpty) return [];
    final storage = FirebaseStorage.instance;
    final List<String> urls = [];
    for (final f in _pickedImages) {
      final name = 'recipes/${DateTime.now().millisecondsSinceEpoch}_${f.path.split('/').last}';
      final ref = storage.ref().child(name);
      final task = await ref.putFile(f);
      final url = await task.ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

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
              // Görsel seçimi
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in _pickedImages)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(f, width: 72, height: 72, fit: BoxFit.cover),
                          ),
                        InkWell(
                          onTap: _uploading ? null : _pickImage,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Theme.of(context).dividerColor),
                            ),
                            child: const Icon(Icons.add_a_photo_outlined),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                      setState(() => _uploading = true);
                      List<String> imageUrls = const [];
                      try {
                        imageUrls = await _uploadAllImages();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Görseller yüklenemedi, tarif görselsiz kaydediliyor')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _uploading = false);
                      }
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
                        imageUrls: imageUrls,
                        );
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(addState.submitting || _uploading ? 'Kaydediliyor...' : 'Kaydet'),
              )
            ],
          ),
        ),
      ),
    );
  }
}


