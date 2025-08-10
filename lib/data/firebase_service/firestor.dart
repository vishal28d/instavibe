import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:instavibe/data/model/usermodel.dart';
import 'package:instavibe/util/exeption.dart';
import 'package:uuid/uuid.dart';

class Firebase_Firestor {
  final FirebaseFirestore _firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ---------------- Create User ----------------
  Future<bool> CreateUser({
    required String email,
    required String username,
    required String bio,
    required String profile,
  }) async {
    if (email.isEmpty || username.isEmpty || bio.isEmpty || profile.isEmpty) {
      throw ArgumentError(
          'Email, username, bio, and profile must not be empty.');
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');

    await _firebaseFirestore.collection('users').doc(currentUser.uid).set({
      'email': email,
      'username': username,
      'bio': bio,
      'profile': profile,
      'followers': [],
      'following': [],
    });
    return true;
  }

  // ---------------- Get User ----------------
  Future<Usermodel> getUser({String? UID}) async {
    final userId = UID ?? _auth.currentUser?.uid;
    if (userId == null) throw Exception('User ID is null');

    try {
      final doc =
          await _firebaseFirestore.collection('users').doc(userId).get();
      if (!doc.exists) throw Exception('User document does not exist');

      final snapuser = doc.data();
      if (snapuser == null) throw Exception('User data is null');

      return Usermodel(
        snapuser['bio'] ?? '',
        snapuser['email'] ?? '',
        List.from(snapuser['followers'] ?? []),
        List.from(snapuser['following'] ?? []),
        snapuser['profile'] ?? '',
        snapuser['username'] ?? 'Unknown User',
      );
    } on FirebaseException catch (e) {
      throw exceptions(e.message ?? 'Unknown Firestore error');
    }
  }

  // ---------------- Create Post ----------------
  Future<bool> CreatePost({
    required String postImage,
    required String caption,
    required String location,
  }) async {
    if (postImage.isEmpty || caption.isEmpty || location.isEmpty) {
      throw ArgumentError(
          'Post image, caption, and location must not be empty.');
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');

    var uid = const Uuid().v4();
    var now = DateTime.now();
    Usermodel user = await getUser();

    await _firebaseFirestore.collection('posts').doc(uid).set({
      'postImage': postImage,
      'username': user.username ?? 'Unknown User',
      'profileImage': user.profile ?? '',
      'caption': caption,
      'location': location,
      'uid': currentUser.uid,
      'postId': uid,
      'like': [],
      'time': now
    });
    return true;
  }

  // ---------------- Create Reels ----------------
  Future<bool> CreatReels({
    required String video,
    required String caption,
  }) async {
    if (video.isEmpty || caption.isEmpty) {
      throw ArgumentError('Video and caption must not be empty.');
    }

    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');

    var uid = const Uuid().v4();
    var now = DateTime.now();
    Usermodel user = await getUser();

    await _firebaseFirestore.collection('reels').doc(uid).set({
      'reelsvideo': video,
      'username': user.username ?? 'Unknown User',
      'profileImage': user.profile ?? '',
      'caption': caption,
      'uid': currentUser.uid,
      'postId': uid,
      'like': [],
      'time': now
    });
    return true;
  }

  // ---------------- Add Comment ----------------
  Future<bool> Comments({
    required String comment,
    required String type,
    required String uidd,
  }) async {
    if (comment.trim().isEmpty || type.trim().isEmpty || uidd.trim().isEmpty) {
      throw ArgumentError('Comment, type, and uidd must not be empty.');
    }

    var uid = const Uuid().v4();
    Usermodel user = await getUser();

    await _firebaseFirestore
        .collection(type)
        .doc(uidd)
        .collection('comments')
        .doc(uid)
        .set({
      'comment': comment,
      'username': user.username ?? 'Unknown User',
      'profileImage': user.profile ?? '',
      'CommentUid': uid,
    });

    return true;
  }

  // ---------------- Like / Unlike ----------------
  Future<String> like({
    required List like,
    required String type,
    required String uid,
    required String postId,
  }) async {
    if (type.isEmpty || uid.isEmpty || postId.isEmpty) {
      return 'Invalid parameters';
    }

    String res = 'some error';
    try {
      final postRef = _firebaseFirestore.collection(type).doc(postId);

      if (like.contains(uid)) {
        await postRef.update({
          'like': FieldValue.arrayRemove([uid])
        });
      } else {
        await postRef.update({
          'like': FieldValue.arrayUnion([uid])
        });
      }
      res = 'success';
    } on Exception catch (e) {
      res = e.toString();
    }
    return res;
  }

  // ---------------- Follow / Unfollow ----------------
  Future<void> flollow({
    required String uid,
  }) async {
    if (uid.isEmpty) throw ArgumentError('UID must not be empty');

    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('No authenticated user found');

    DocumentSnapshot snap =
        await _firebaseFirestore.collection('users').doc(currentUser.uid).get();

    final data = snap.data() as Map<String, dynamic>?;
    if (data == null) throw Exception('User data is null');

    List following = List.from(data['following'] ?? []);

    try {
      if (following.contains(uid)) {
        await _firebaseFirestore
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'following': FieldValue.arrayRemove([uid])
        });
        await _firebaseFirestore.collection('users').doc(uid).update({
          'followers': FieldValue.arrayRemove([currentUser.uid])
        });
      } else {
        await _firebaseFirestore
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'following': FieldValue.arrayUnion([uid])
        });
        await _firebaseFirestore.collection('users').doc(uid).update({
          'followers': FieldValue.arrayUnion([currentUser.uid])
        });
      }
    } on Exception catch (e) {
      print(e.toString());
    }
  }
}
