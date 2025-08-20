import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:roda/data/core/supabase_client.dart';
import 'package:roda/core/theme/roda_colors.dart';
import 'package:roda/core/utils/logger.dart';

class TeacherSearchField extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final String? initialTeacherId;
  final String? initialTeacherName;
  final Function(String teacherId, String teacherName) onTeacherSelected;
  
  const TeacherSearchField({
    super.key,
    required this.controller,
    this.initialTeacherId,
    this.initialTeacherName,
    required this.onTeacherSelected,
  });

  @override
  ConsumerState<TeacherSearchField> createState() => _TeacherSearchFieldState();
}

class _TeacherSearchFieldState extends ConsumerState<TeacherSearchField> {
  bool _isSearching = false;
  List<TeacherSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  final FocusNode _focusNode = FocusNode();
  String? _selectedTeacherId;
  
  @override
  void initState() {
    super.initState();
    
    // Set initial values
    if (widget.initialTeacherName != null) {
      widget.controller.text = widget.initialTeacherName!;
      _selectedTeacherId = widget.initialTeacherId;
    }
    
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _showSuggestions = false);
      }
    });
  }
  
  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }
  
  void _onTextChanged() {
    // Only search if the text has actually changed from what we set
    if (widget.controller.text.length > 1) {
      _searchTeachers(widget.controller.text);
    } else {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }
  
  Future<void> _searchTeachers(String query) async {
    if (query.isEmpty || query.length < 2) return;
    
    setState(() => _isSearching = true);
    
    try {
      final supabase = ref.read(supabaseClientProvider);
      
      // Search for teachers by capoeira name or full name
      final response = await supabase
          .from('users')
          .select('id, full_name, capoeira_name, group_id, groups!inner(name)')
          .eq('role', 'teacher')
          .or('capoeira_name.ilike.%$query%,full_name.ilike.%$query%')
          .limit(10);
      
      setState(() {
        _isSearching = false;
        _suggestions = (response as List).map((teacher) {
          final groupName = teacher['groups']?['name'] as String?;
          return TeacherSuggestion(
            id: teacher['id'] as String,
            capoeiraName: teacher['capoeira_name'] as String? ?? '',
            fullName: teacher['full_name'] as String,
            groupName: groupName ?? 'No Group',
          );
        }).toList();
        _showSuggestions = _suggestions.isNotEmpty;
      });
    } catch (e) {
      Logger.error('Failed to search teachers', e);
      setState(() {
        _isSearching = false;
        _suggestions = [];
        _showSuggestions = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CupertinoTextField(
          controller: widget.controller,
          focusNode: _focusNode,
          placeholder: 'Search for a teacher',
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: RodaColors.systemGrey6,
            borderRadius: BorderRadius.circular(8),
          ),
          prefix: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(
              CupertinoIcons.person,
              color: RodaColors.systemGrey,
              size: 20,
            ),
          ),
          suffix: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: CupertinoActivityIndicator(radius: 10),
                )
              : widget.controller.text.isNotEmpty
                  ? CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Icon(
                        CupertinoIcons.clear_circled_solid,
                        color: RodaColors.systemGrey,
                        size: 20,
                      ),
                      onPressed: () {
                        widget.controller.clear();
                        _selectedTeacherId = null;
                        widget.onTeacherSelected('', '');
                      },
                    )
                  : null,
          onTap: () {
            if (widget.controller.text.isNotEmpty) {
              setState(() => _showSuggestions = true);
              _searchTeachers(widget.controller.text);
            }
          },
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: RodaColors.systemBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: RodaColors.separator,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: RodaColors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (context, index) {
                final teacher = _suggestions[index];
                final displayName = teacher.capoeiraName.isNotEmpty 
                    ? teacher.capoeiraName 
                    : teacher.fullName;
                
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () {
                    widget.controller.text = displayName;
                    _selectedTeacherId = teacher.id;
                    widget.onTeacherSelected(teacher.id, displayName);
                    setState(() => _showSuggestions = false);
                    _focusNode.unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: index != _suggestions.length - 1
                          ? const Border(
                              bottom: BorderSide(
                                color: RodaColors.separator,
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.person_solid,
                          color: RodaColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: RodaColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (teacher.capoeiraName.isNotEmpty && displayName != teacher.fullName)
                                Text(
                                  teacher.fullName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: RodaColors.textSecondary,
                                  ),
                                ),
                              Text(
                                teacher.groupName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: RodaColors.textHint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class TeacherSuggestion {
  final String id;
  final String capoeiraName;
  final String fullName;
  final String groupName;
  
  TeacherSuggestion({
    required this.id,
    required this.capoeiraName,
    required this.fullName,
    required this.groupName,
  });
}