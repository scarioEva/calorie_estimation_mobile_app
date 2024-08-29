import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Profile'),
        ),
        body: Center(
          child: Text('No user logged in'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(
              radius: 50,
              backgroundImage: user.photoURL != null
                  ? NetworkImage(user.photoURL!)
                  : AssetImage('assets/default_profile.png') as ImageProvider,
            ),
            SizedBox(height: 16),
            Text(
              user.displayName ?? 'No Name',
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 8),
            Text(
              user.email ?? 'No Email',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            if (user.metadata.creationTime != null)
              Text(
                'Joined on: ${DateFormat('dd/MM/yyyy').format(user.metadata.creationTime!)}',
                style: TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
