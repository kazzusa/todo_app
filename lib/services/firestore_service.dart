import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/task.dart';

class FirestoreService {
  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _tasks =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('tasks');

  DocumentReference<Map<String, dynamic>> get _deviceDoc =>
      FirebaseFirestore.instance.collection('users').doc(_uid).collection('config').doc('device');

  Stream<List<Task>> tasksStream() => _tasks
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => Task.fromMap(d.id, d.data()))
          .toList());

  Future<Task> addTask(Task task) async {
    final ref = await _tasks.add(task.toMap());
    return task.copyWith(id: ref.id);
  }

  Future<void> updateTask(Task task) =>
      _tasks.doc(task.id).update(task.toMap());

  Future<void> deleteTask(String id) => _tasks.doc(id).delete();

  Future<void> deleteTasks(List<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(_tasks.doc(id));
    }
    await batch.commit();
  }

  Future<void> saveFcmToken(String token) =>
      _deviceDoc.set({'fcmToken': token}, SetOptions(merge: true));
}
