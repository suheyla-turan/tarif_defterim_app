import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers/localization_provider.dart';
import '../application/recipes_provider.dart';
import '../constants/recipe_types.dart';
import '../models/recipe.dart';
import '../widgets/ingredient_group_form_model.dart';

class EditRecipeScreen extends ConsumerStatefulWidget {
  final Recipe recipe;
  const EditRecipeScreen({super.key, required this.recipe});

  @override
  ConsumerState<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends ConsumerState<EditRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _portionCtrl;
  late List<TextEditingController> _ingredientCtrls;
  final List<IngredientGroupFormModel> _ingredientGroupForms = [];
  late List<TextEditingController> _stepCtrls;

  late String _mainType;
  String? _subType;

  final List<File> _newImages = [];
  List<String> _existingImages = [];
  bool _uploadingImages = false;
  bool _useIngredientCategories = false;

  @override
  void initState() {
    super.initState();
    final recipe = widget.recipe;
    _titleCtrl = TextEditingController(text: recipe.title);
    _descCtrl = TextEditingController(text: recipe.description ?? '');
    _countryCtrl = TextEditingController(text: recipe.country ?? '');
    _portionCtrl = TextEditingController(text: (recipe.portions ?? 1).toString());
    _mainType = recipe.mainType;
    _subType = recipe.subType;
    _existingImages = List<String>.from(recipe.imageUrls);
    _useIngredientCategories = recipe.ingredientGroups.isNotEmpty;
    if (_useIngredientCategories) {
      _ingredientGroupForms.addAll(
        recipe.ingredientGroups
            .map(
              (group) => IngredientGroupFormModel(
                name: group.name,
                ingredients: group.items.isEmpty ? [''] : group.items,
              ),
            )
            .toList(),
      );
    }
    final seedIngredients =
        recipe.resolvedIngredients.isEmpty ? [''] : recipe.resolvedIngredients;
    _ingredientCtrls =
        seedIngredients.map((e) => TextEditingController(text: e)).toList();
    _stepCtrls =
        (recipe.steps.isEmpty ? [''] : recipe.steps).map((e) => TextEditingController(text: e)).toList();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _countryCtrl.dispose();
    _portionCtrl.dispose();
    for (final ctrl in _ingredientCtrls) {
      ctrl.dispose();
    }
    for (final group in _ingredientGroupForms) {
      group.dispose();
    }
    for (final ctrl in _stepCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

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
              title: Text(AppLocalizations.of(context).fromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(AppLocalizations.of(context).fromCamera),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() {
      _newImages.add(File(picked.path));
    });
  }

  Future<List<String>> _uploadNewImages() async {
    if (_newImages.isEmpty) return const [];
    final storage = FirebaseStorage.instance;
    final urls = <String>[];
    final ownerId = widget.recipe.ownerId;
    for (final image in _newImages) {
      final name = '${DateTime.now().millisecondsSinceEpoch}_${image.path.split('/').last}';
      final ref = storage.ref().child('recipes/$ownerId/$name');
      final task = await ref.putFile(image);
      final url = await task.ref.getDownloadURL();
      urls.add(url);
    }
    return urls;
  }

  void _ensureGroupFormInitialized() {
    if (_ingredientGroupForms.isNotEmpty) return;
    final existingValues = _ingredientCtrls
        .map((c) => c.text.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    _ingredientGroupForms.add(
      IngredientGroupFormModel(
        ingredients: existingValues.isEmpty ? [''] : existingValues,
      ),
    );
  }

  void _addIngredientGroup() {
    setState(() {
      _ingredientGroupForms.add(IngredientGroupFormModel());
    });
  }

  void _removeIngredientGroup(int index) {
    if (_ingredientGroupForms.length == 1) return;
    setState(() {
      final removed = _ingredientGroupForms.removeAt(index);
      removed.dispose();
    });
  }

  void _replaceSimpleIngredientTexts(List<String> values) {
    if (values.isEmpty) {
      if (_ingredientCtrls.isEmpty) {
        _ingredientCtrls.add(TextEditingController());
      } else {
        for (final ctrl in _ingredientCtrls) {
          ctrl.text = '';
        }
      }
      return;
    }
    if (_ingredientCtrls.length < values.length) {
      _ingredientCtrls.addAll(
        List.generate(values.length - _ingredientCtrls.length, (_) => TextEditingController()),
      );
    }
    for (var i = 0; i < values.length; i++) {
      _ingredientCtrls[i].text = values[i];
    }
    for (var i = values.length; i < _ingredientCtrls.length; i++) {
      _ingredientCtrls[i].text = '';
    }
  }

  List<IngredientGroup> _collectIngredientGroups(AppLocalizations l10n) {
    final defaultName = l10n.uncategorizedIngredients;
    final groups = <IngredientGroup>[];
    for (final form in _ingredientGroupForms) {
      final items = form.ingredientControllers
          .map((c) => c.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (items.isEmpty) continue;
      final name = form.nameController.text.trim().isEmpty
          ? defaultName
          : form.nameController.text.trim();
      groups.add(IngredientGroup(name: name, items: items));
    }
    return groups;
  }

  void _handleIngredientCategoryToggle(bool value, AppLocalizations l10n) {
    if (value == _useIngredientCategories) return;
    setState(() {
      if (value) {
        _ensureGroupFormInitialized();
      } else {
        final flattened = _collectIngredientGroups(l10n)
            .expand((group) => group.items)
            .toList(growable: false);
        _replaceSimpleIngredientTexts(flattened);
      }
      _useIngredientCategories = value;
    });
  }

  Widget _buildSimpleIngredients(AppLocalizations l10n) {
    return Column(
      children: [
        ..._ingredientCtrls.asMap().entries.map(
          (entry) {
            final index = entry.key;
            final ctrl = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: ctrl,
                      decoration: InputDecoration(
                        labelText: '${l10n.ingredient} #${index + 1}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _ingredientCtrls.length > 1
                        ? () => setState(() {
                              final removed = _ingredientCtrls.removeAt(index);
                              removed.dispose();
                            })
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _ingredientCtrls.add(TextEditingController())),
            icon: const Icon(Icons.add),
            label: Text(l10n.addIngredient),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorizedIngredients(AppLocalizations l10n) {
    return Column(
      children: [
        ..._ingredientGroupForms.asMap().entries.map((entry) {
          final index = entry.key;
          final form = entry.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: form.nameController,
                          decoration: InputDecoration(
                            labelText: '${l10n.ingredientCategory} #${index + 1}',
                            hintText: l10n.ingredientCategoryHint,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.removeIngredientCategory,
                        onPressed:
                            _ingredientGroupForms.length > 1 ? () => _removeIngredientGroup(index) : null,
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...form.ingredientControllers.asMap().entries.map((inner) {
                    final itemIndex = inner.key;
                    final ctrl = inner.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: ctrl,
                              decoration: InputDecoration(
                                labelText: '${l10n.ingredient} #${itemIndex + 1}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: form.ingredientControllers.length > 1
                                ? () => setState(() {
                                      final removed = form.ingredientControllers.removeAt(itemIndex);
                                      removed.dispose();
                                    })
                                : null,
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => form.ingredientControllers.add(TextEditingController())),
                      icon: const Icon(Icons.add),
                      label: Text(l10n.addIngredient),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addIngredientGroup,
            icon: const Icon(Icons.add_box_outlined),
            label: Text(l10n.addIngredientCategory),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final editState = ref.watch(editRecipeControllerProvider);
    final editCtrl = ref.read(editRecipeControllerProvider.notifier);

    ref.listen(editRecipeControllerProvider, (prev, next) {
      if (prev?.submitting == true && next.submitting == false && next.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.recipeUpdated)),
          );
          Navigator.of(context).pop(true);
        }
      } else if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
    });

    final subTypes = RecipeTypes.subTypesOf(_mainType);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editRecipe),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ..._existingImages.map(
                    (url) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            url,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(24, 24),
                            ),
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () {
                              setState(() => _existingImages.remove(url));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._newImages.asMap().entries.map(
                    (entry) => Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            entry.value,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: -6,
                          right: -6,
                          child: IconButton(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black54,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(24, 24),
                            ),
                            icon: const Icon(Icons.close, size: 16, color: Colors.white),
                            onPressed: () {
                              setState(() => _newImages.removeAt(entry.key));
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: (_uploadingImages || editState.submitting) ? null : _pickImage,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: const Icon(Icons.add_a_photo_outlined),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(labelText: l10n.title),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? l10n.required : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _mainType,
                items: RecipeTypes.mainTypes
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(_getMainTypeDisplayName(e, l10n)),
                      ),
                    )
                    .toList(),
                decoration: InputDecoration(labelText: l10n.type),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _mainType = value;
                    final nextSubTypes = RecipeTypes.subTypesOf(_mainType);
                    _subType = nextSubTypes.isNotEmpty ? nextSubTypes.first : null;
                  });
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _subType,
                items: subTypes
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text(_getSubTypeDisplayName(e, l10n)),
                      ),
                    )
                    .toList(),
                decoration: InputDecoration(labelText: l10n.subType),
                onChanged: (value) => setState(() => _subType = value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _portionCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.portionField,
                  hintText: l10n.portionExample,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return l10n.required;
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed < 1) {
                    return l10n.validNumber;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _countryCtrl,
                decoration: InputDecoration(labelText: '${l10n.country} (${l10n.optional})'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration:
                    InputDecoration(labelText: '${l10n.description} (${l10n.optional})'),
              ),
              const SizedBox(height: 16),
              Text(l10n.ingredients, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                value: _useIngredientCategories,
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.categorizeIngredients),
                subtitle: Text(l10n.categorizeIngredientsHint),
                onChanged: (value) => _handleIngredientCategoryToggle(value, l10n),
              ),
              const SizedBox(height: 8),
              if (_useIngredientCategories)
                _buildCategorizedIngredients(l10n)
              else
                _buildSimpleIngredients(l10n),
              const SizedBox(height: 16),
              Text(l10n.steps, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._stepCtrls.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final ctrl = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: ctrl,
                            decoration:
                                InputDecoration(labelText: '${l10n.step} #${index + 1}'),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty) ? l10n.required : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: _stepCtrls.length > 1
                              ? () => setState(() => _stepCtrls.removeAt(index))
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _stepCtrls.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addStep),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: (editState.submitting || _uploadingImages)
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setState(() => _uploadingImages = true);
                        List<String> uploadedUrls = const [];
                        try {
                          uploadedUrls = await _uploadNewImages();
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.imagesUploadFailed)),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _uploadingImages = false);
                        }
                        final combinedImages = [
                          ..._existingImages,
                          ...uploadedUrls,
                        ];
                        final categorizedGroups =
                            _useIngredientCategories ? _collectIngredientGroups(l10n) : const <IngredientGroup>[];
                        if (_useIngredientCategories && categorizedGroups.isEmpty) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.addIngredient)),
                            );
                          }
                          return;
                        }
                        final ingredients = categorizedGroups.isNotEmpty
                            ? categorizedGroups.expand((g) => g.items).toList()
                            : _ingredientCtrls
                                .map((c) => c.text.trim())
                                .where((e) => e.isNotEmpty)
                                .toList();
                        final steps = _stepCtrls
                            .map((c) => c.text.trim())
                            .where((e) => e.isNotEmpty)
                            .toList();
                        final portionText = _portionCtrl.text.trim();
                        final portion = int.tryParse(portionText);
                        if (portion == null || portion < 1) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.validNumber)),
                            );
                          }
                          return;
                        }
                        await editCtrl.submit(
                          recipe: widget.recipe.copyWith(
                            title: _titleCtrl.text.trim(),
                            description:
                                _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
                            mainType: _mainType,
                            subType: _subType,
                            country: _countryCtrl.text.trim().isEmpty
                                ? null
                                : _countryCtrl.text.trim(),
                            ingredients: ingredients,
                            steps: steps,
                            imageUrls: combinedImages,
                            portions: portion,
                            ingredientGroups: categorizedGroups,
                          ),
                        );
                      },
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  (editState.submitting || _uploadingImages) ? l10n.saving : l10n.save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getMainTypeDisplayName(String mainType, AppLocalizations l10n) {
    switch (mainType) {
      case 'yemek':
        return l10n.meals;
      case 'tatli':
        return l10n.desserts;
      case 'icecek':
        return l10n.drinks;
      default:
        return mainType;
    }
  }

  String _getSubTypeDisplayName(String subType, AppLocalizations l10n) {
    switch (subType) {
      case 'corba':
        return l10n.soup;
      case 'ana_yemek':
        return l10n.mainDish;
      case 'meze':
        return l10n.appetizer;
      case 'salata':
        return l10n.salad;
      case 'hamur_isi':
        return l10n.pastry;
      case 'sutlu':
        return l10n.milky;
      case 'serbetli':
        return l10n.syrupy;
      case 'kek_pasta':
        return l10n.cake;
      case 'kurabiye':
        return l10n.cookie;
      case 'sicak':
        return l10n.hot;
      case 'soguk':
        return l10n.cold;
      case 'smoothie':
        return l10n.smoothie;
      default:
        return subType;
    }
  }
}


