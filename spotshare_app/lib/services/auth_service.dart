import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final userCredential = await _auth.signInWithEmailAndPassword(
        email: email, password: password);
    await _saveUserToFirestore(userCredential.user);
    return userCredential;
  }

  Future<UserCredential> signUpWithEmail(
      String email, String password, String name, String role, {String? carNumber}) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    
    await userCredential.user?.updateDisplayName(name);
    await _saveUserToFirestore(userCredential.user, name: name, role: role, carNumber: carNumber);
    return userCredential;
  }

  Future<void> _saveUserToFirestore(User? user, {String? name, String? role, String? carNumber}) async {
    if (user == null) return;
    String? token = await FirebaseMessaging.instance.getToken();
    final data = <String, dynamic>{
      'email': user.email,
      'name': name ?? user.displayName ?? '',
      'photoUrl': user.photoURL,
      'fcmToken': token,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };
    if (role != null) {
      data['role'] = role;
    }
    if (carNumber != null && carNumber.isNotEmpty) {
      data['carNumber'] = carNumber;
    }
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(data, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
