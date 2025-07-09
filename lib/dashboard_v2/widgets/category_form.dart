import 'package:flutter/material.dart';
import 'package:myapp/utils/category_colors.dart';

class CategoryForm extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final Color? initialColor;
  final String submitButtonText;
  final Function(String name, String description, Color color) onSubmit;
  final VoidCallback onCancel;

  const CategoryForm({
    super.key,
    this.initialName,
    this.initialDescription,
    this.initialColor,
    required this.submitButtonText,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<CategoryForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late Color _selectedColor;
  final _formKey = GlobalKey<FormState>();

  // CC: Use the same predefined colors from CategoryColors
  static final List<Color> _availableColors = [
    const Color(0xFF90CAF9), // Light Blue
    const Color(0xFFEF9A9A), // Light Red
    const Color(0xFFA5D6A7), // Light Green
    const Color(0xFFCE93D8), // Light Purple
    const Color(0xFFFFCC80), // Light Orange
    const Color(0xFF80DEEA), // Light Teal
    const Color(0xFFF48FB1), // Light Pink
    const Color(0xFF9FA8DA), // Light Indigo
    const Color(0xFFFFE082), // Light Amber
    const Color(0xFF80CBC4), // Light Cyan
    const Color(0xFFFFAB91), // Light Deep Orange
    const Color(0xFFE6EE9C), // Light Lime
    const Color(0xFFB39DDB), // Light Deep Purple
    const Color(0xFF81D4FA), // Lighter Blue
    const Color(0xFFBCAAA4), // Light Brown
    const Color(0xFFC5E1A5), // Lighter Green
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _descriptionController = TextEditingController(text: widget.initialDescription);
    _selectedColor = widget.initialColor ?? _availableColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Category Name',
              hintText: 'Enter category name',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: widget.initialName == null,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a category name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (Optional)',
              hintText: 'Add a description for this category',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Category Color',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    // CC: Preview of selected color with category name
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedColor.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        _nameController.text.isEmpty ? 'Category Name' : _nameController.text,
                        style: TextStyle(
                          color: HSLColor.fromColor(_selectedColor)
                              .withLightness(0.3)
                              .toColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // CC: Color selection grid
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _availableColors.length,
                      itemBuilder: (context, index) {
                        final color = _availableColors[index];
                        final isSelected = color == _selectedColor;
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = color;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected 
                                    ? theme.colorScheme.primary 
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                            child: isSelected
                                ? Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: _handleSubmit,
                  child: Text(widget.submitButtonText),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      
      widget.onSubmit(name, description, _selectedColor);
    }
  }
}