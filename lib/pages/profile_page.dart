import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: FutureBuilder(
        future: _getUserDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final userData = snapshot.data as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (userData['photoURL'] != null)
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: NetworkImage(userData['photoURL']),
                  )
                else
                  CircleAvatar(
                    radius: 50,
                    child: Icon(Icons.person, size: 50),
                  ),
                SizedBox(height: 16.0),
                Text(
                  userData['displayName'] ?? 'No Name',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8.0),
                Text(userData['email'] ?? 'No Email'),
                SizedBox(height: 8.0),
                Text(userData['dob'] ?? 'Date of Birth not set'),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _getUserDetails() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw 'No user logged in';
    }

    // Fetch additional user details from Firestore if needed
    DocumentSnapshot<Map<String, dynamic>> userDoc = await FirebaseFirestore
        .instance
        .collection('users')
        .doc(user.uid)
        .get();

    return {
      'displayName': user.displayName,
      'email': user.email,
      'photoURL': user.photoURL,
      'dob':
          userDoc.data()?['dob'], // Assuming 'dob' field is stored in Firestore
    };
  }
}
