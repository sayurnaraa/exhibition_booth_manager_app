import 'package:flutter/material.dart';
import '../../models/exhibition.dart';
import '../../services/database_service.dart';

class AddExhibitionScreen extends StatefulWidget {
  final Exhibition? initialExhibition;

  const AddExhibitionScreen({super.key, this.initialExhibition});

  @override
  State<AddExhibitionScreen> createState() => _AddExhibitionScreenState();
}

class _AddExhibitionScreenState extends State<AddExhibitionScreen> {
  static const List<String> _defaultIndustryCategories = <String>[
    'Food',
    'Coffee',
    'Telecom',
    'Technology',
    'Retail',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _boothCountController = TextEditingController();
  final _categoriesController = TextEditingController();
  
  bool _isLoading = false;
  String _selectedStatus = 'Upcoming';
  final DatabaseService _dbService = DatabaseService();
  bool _blockAdjacentCompetitors = false;

  bool get _isEditMode => widget.initialExhibition?.id != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialExhibition;
    if (initial != null) {
      _nameController.text = initial.name;
      _descriptionController.text = initial.description;
      _locationController.text = initial.location;
      _startDateController.text = initial.startDate;
      _endDateController.text = initial.endDate;
      _boothCountController.text = initial.totalBooths.toString();
      _selectedStatus = initial.status;
      _blockAdjacentCompetitors = initial.blockAdjacentCompetitors;
      _categoriesController.text = (initial.industryCategories.isNotEmpty
              ? initial.industryCategories
              : _defaultIndustryCategories)
          .join(', ');
    } else {
      // Defaults for new exhibitions (organizer can edit/remove as needed).
      _categoriesController.text = _defaultIndustryCategories.join(', ');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _boothCountController.dispose();
    _categoriesController.dispose();
    super.dispose();
  }

  List<String> _parseCategories(String raw) {
    final parts = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final unique = <String>{};
    final out = <String>[];
    for (final p in parts) {
      final key = p.toLowerCase();
      if (unique.add(key)) out.add(p);
    }
    return out;
  }

  Future<void> _selectDate(TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      controller.text = '${picked.day} ${_getMonthName(picked.month)} ${picked.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  Future<void> _handleAddOrUpdateExhibition() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final exhibition = Exhibition(
        id: widget.initialExhibition?.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        startDate: _startDateController.text.trim(),
        endDate: _endDateController.text.trim(),
        location: _locationController.text.trim(),
        status: _selectedStatus,
        totalBooths: int.parse(_boothCountController.text.trim()),
        blockAdjacentCompetitors: _blockAdjacentCompetitors,
        industryCategories: _parseCategories(_categoriesController.text),
        createdAt: widget.initialExhibition?.createdAt,
      );

      if (_isEditMode) {
        await _dbService.updateExhibition(exhibition);
      } else {
        await _dbService.createExhibition(exhibition);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditMode
              ? 'Exhibition updated successfully!'
              : 'Exhibition created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Pop back to manage exhibitions screen
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Exhibition' : 'Add New Exhibition'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Exhibition Name
              const Text(
                'Exhibition Name',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter exhibition name',
                  prefixIcon: const Icon(Icons.event),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter exhibition name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                enabled: !_isLoading,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Enter exhibition description',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Booth adjacency rule
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Block adjacent competitor booths',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Prevents booking a booth next to a reserved/approved booth in the same industry/category.',
                ),
                value: _blockAdjacentCompetitors,
                onChanged: _isLoading
                    ? null
                    : (v) {
                        setState(() {
                          _blockAdjacentCompetitors = v;
                        });
                      },
                activeColor: Colors.deepPurple,
              ),
              const SizedBox(height: 16),

              // Industry categories
              const Text(
                'Industry Categories',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _categoriesController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'e.g., Food, Telecom, Retail',
                  prefixIcon: const Icon(Icons.category),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Comma-separated. These will appear in the exhibitor booking dropdown.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),

              // Location
              const Text(
                'Location',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  hintText: 'Enter location',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter location';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Start Date
              const Text(
                'Start Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _startDateController,
                enabled: !_isLoading,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Select start date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
                onTap: () => _selectDate(_startDateController),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select start date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // End Date
              const Text(
                'End Date',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _endDateController,
                enabled: !_isLoading,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Select end date',
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: const Icon(Icons.arrow_drop_down),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
                onTap: () => _selectDate(_endDateController),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select end date';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Total Booths
              const Text(
                'Total Booths',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _boothCountController,
                enabled: !_isLoading,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter number of booths',
                  prefixIcon: const Icon(Icons.shop),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.deepPurple),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.deepPurple,
                      width: 2,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter number of booths';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Status
              const Text(
                'Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.deepPurple),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButton<String>(
                  value: _selectedStatus,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: ['Upcoming', 'Active', 'Completed']
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                          setState(() {
                            _selectedStatus = value ?? 'Upcoming';
                          });
                        },
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleAddOrUpdateExhibition,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditMode ? 'Save Changes' : 'Create Exhibition',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
