import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WaterService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _uid => _auth.currentUser?.uid;
  bool get _isAuth => _uid != null;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('water_intake');

  String _todayKey(String date) => 'water_count_$date';

  Future<int> getCountForDate(String date) async {
    if (_isAuth) {
      final snap = await _col
          .where('userId', isEqualTo: _uid)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        return (snap.docs.first.data()['count'] ?? 0) as int;
      }
      return 0;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_todayKey(date)) ?? 0;
  }

  Stream<int> getCountStream(String date) {
    if (!_isAuth) {
      return Stream.fromFuture(getCountForDate(date));
    }
    return _col
        .where('userId', isEqualTo: _uid)
        .where('date', isEqualTo: date)
        .limit(1)
        .snapshots()
        .map((s) =>
            s.docs.isNotEmpty ? (s.docs.first.data()['count'] ?? 0) as int : 0);
  }

  Future<void> setCount(String date, int count) async {
    count = count < 0 ? 0 : count;
    if (_isAuth) {
      // Upsert by compound key (userId+date)
      final q = await _col
          .where('userId', isEqualTo: _uid)
          .where('date', isEqualTo: date)
          .limit(1)
          .get();
      if (q.docs.isEmpty) {
        await _col.add({
          'userId': _uid,
          'date': date,
          'count': count,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await q.docs.first.reference.update({
          'count': count,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_todayKey(date), count);
    }
  }

  Future<int> increment(String date, {int delta = 1}) async {
    final current = await getCountForDate(date);
    final next = current + delta;
    await setCount(date, next);
    return next;
  }

  Future<int> decrement(String date, {int delta = 1}) async {
    final current = await getCountForDate(date);
    final next = current - delta;
    await setCount(date, next < 0 ? 0 : next);
    return next;
  }
}
