import 'package:flutter/material.dart';
import '../services/food_firestore_service.dart';

class DietPlansScreen extends StatefulWidget {
  final String date;
  const DietPlansScreen({Key? key, required this.date}) : super(key: key);

  @override
  _DietPlansScreenState createState() => _DietPlansScreenState();
}

class _DietPlansScreenState extends State<DietPlansScreen> {
  final _firestoreService = FoodFirestoreService();
  List<FoodLog> _todayLogs = [];
  List<FoodRecommendation> _recommendations = [];
  bool isLoading = true;
  bool isGeneratingRecommendations = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Determine current meal type based on time
  String _getCurrentMealType() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 11) {
      return 'breakfast';
    } else if (hour >= 11 && hour < 16) {
      return 'lunch';
    } else if (hour >= 16 && hour < 22) {
      return 'dinner';
    } else {
      return 'snack';
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
    });

    await Future.wait([
      _loadLogs(),
      _loadRecommendations(),
    ]);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _loadLogs() async {
    try {
      final logs = await _firestoreService.getLogsByDate(widget.date);
      if (mounted) {
        setState(() {
          _todayLogs = logs;
        });
      }
    } catch (e) {
      print('Error loading logs: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    try {
      final recs =
          await _firestoreService.getRecommendationsByDate(widget.date);
      if (mounted) {
        setState(() {
          _recommendations = recs;
        });
      }
    } catch (e) {
      print('Error loading recommendations: $e');
    }
  }

  Future<void> _generateRecommendations() async {
    if (_todayLogs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log some food first to get recommendations'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isGeneratingRecommendations = true;
    });

    try {
      await _firestoreService.generateRecommendationsManually(widget.date);
      await _loadRecommendations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recommendations generated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error generating recommendations: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate recommendations: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isGeneratingRecommendations = false;
        });
      }
    }
  }

  Future<void> _toggleRecommendationAcceptance(
      String recId, bool currentAccepted) async {
    try {
      final newAccepted = !currentAccepted;
      await _firestoreService
          .updateRecommendation(recId, {'accepted': newAccepted});
      await _loadRecommendations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newAccepted
                ? 'Recommendation accepted!'
                : 'Recommendation unmarked'),
            backgroundColor: newAccepted ? Colors.green : Colors.grey,
          ),
        );
      }
    } catch (e) {
      print('Error updating recommendation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update recommendation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRecommendation(String recId, String itemName) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recommendation'),
        content: Text('Are you sure you want to delete "$itemName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestoreService.deleteRecommendation(recId);
        await _loadRecommendations();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recommendation deleted'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      } catch (e) {
        print('Error deleting recommendation: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete recommendation: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildLoggedFoodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Logged Foods",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_todayLogs.length} items',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_todayLogs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  const Text('No food logged today'),
                ],
              ),
            ),
          )
        else
          ..._todayLogs.map((log) => Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getMealTypeColor(log.mealType),
                    child: Icon(
                      _getMealTypeIcon(log.mealType),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    log.name,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    '${log.calories} kcal • ${_capitalize(log.mealType)} • Qty: ${log.quantity}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildRecommendationsSection() {
    final currentMealType = _getCurrentMealType();
    final filteredRecommendations = _recommendations
        .where((rec) => rec.mealType.toLowerCase() == currentMealType)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "AI Recommendations",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'For ${_capitalize(currentMealType)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                if (filteredRecommendations.isNotEmpty)
                  Text(
                    '${filteredRecommendations.length} items',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: isGeneratingRecommendations
                      ? null
                      : _generateRecommendations,
                  icon: isGeneratingRecommendations
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text(isGeneratingRecommendations
                      ? 'Generating...'
                      : 'Generate'),
                  style: ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (filteredRecommendations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.lightbulb_outline, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        'No recommendations for ${_capitalize(currentMealType)} yet. Log some food and generate recommendations!'),
                  ),
                ],
              ),
            ),
          )
        else
          ...filteredRecommendations.map((rec) {
            final isAccepted = rec.accepted;
            final recId = rec.id!;
            final itemName = rec.item;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getMealTypeColor(rec.mealType),
                  child: Icon(
                    _getMealTypeIcon(rec.mealType),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  itemName,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    decoration: isAccepted ? TextDecoration.lineThrough : null,
                    color: isAccepted ? Colors.grey : null,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${rec.calories} kcal • ${_capitalize(rec.mealType)}',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (rec.reasoning.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          rec.reasoning,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isAccepted
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: isAccepted ? Colors.green : Colors.grey,
                      ),
                      onPressed: () =>
                          _toggleRecommendationAcceptance(recId, isAccepted),
                      tooltip:
                          isAccepted ? 'Mark as pending' : 'Mark as accepted',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteRecommendation(recId, itemName),
                      tooltip: 'Delete recommendation',
                    ),
                  ],
                ),
                isThreeLine: rec.reasoning.isNotEmpty,
              ),
            );
          }),
      ],
    );
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Colors.orange;
      case 'lunch':
        return Colors.green;
      case 'dinner':
        return Colors.blue;
      case 'snack':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getMealTypeIcon(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast':
        return Icons.wb_sunny;
      case 'lunch':
        return Icons.wb_sunny_outlined;
      case 'dinner':
        return Icons.nights_stay;
      case 'snack':
        return Icons.cookie;
      default:
        return Icons.restaurant;
    }
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diet Plans'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildLoggedFoodsSection(),
                  const SizedBox(height: 24),
                  _buildRecommendationsSection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}
