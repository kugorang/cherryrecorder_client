import 'package:flutter/material.dart';
import '../../../../core/models/memo.dart';
import '../../../../core/database/database_helper.dart';

class PlaceDetailViewModel extends ChangeNotifier {
  List<Memo> _memos = [];
  bool _isLoading = false;
  String? _error;

  List<Memo> get memos => _memos;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMemos(String placeId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final results = await DatabaseHelper.instance.queryMemos(placeId);
      _memos = results.map((map) => Memo.fromMap(map)).toList();
    } catch (e) {
      _error = '메모를 불러오는 중 오류가 발생했습니다: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addMemo(Memo memo) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await DatabaseHelper.instance.insertMemo(memo.toMap());
      await loadMemos(memo.placeId);
      return true;
    } catch (e) {
      _error = '메모를 저장하는 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateMemo(Memo memo) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await DatabaseHelper.instance.updateMemo(memo.toMap());
      await loadMemos(memo.placeId);
      return true;
    } catch (e) {
      _error = '메모를 수정하는 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteMemo(String id, String placeId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await DatabaseHelper.instance.deleteMemo(id);
      await loadMemos(placeId);
      return true;
    } catch (e) {
      _error = '메모를 삭제하는 중 오류가 발생했습니다: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
