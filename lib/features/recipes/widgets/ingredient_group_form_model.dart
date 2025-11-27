import 'package:flutter/material.dart';

/// Simple holder for the controllers that drive a categorized ingredient group
/// editing experience. Shared between add/edit recipe screens so we can build
/// identical UIs without duplicating controller logic.
class IngredientGroupFormModel {
  IngredientGroupFormModel({
    String name = '',
    List<String> ingredients = const [],
  })  : nameController = TextEditingController(text: name),
        ingredientControllers = ingredients.isEmpty
            ? [TextEditingController()]
            : ingredients.map((e) => TextEditingController(text: e)).toList();

  final TextEditingController nameController;
  final List<TextEditingController> ingredientControllers;

  void ensureIngredientField() {
    if (ingredientControllers.isEmpty) {
      ingredientControllers.add(TextEditingController());
    }
  }

  void dispose() {
    nameController.dispose();
    for (final ctrl in ingredientControllers) {
      ctrl.dispose();
    }
  }
}

