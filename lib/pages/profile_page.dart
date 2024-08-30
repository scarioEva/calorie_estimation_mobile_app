import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:food_calorie_estimation/pages/login_page.dart';
import 'package:intl/intl.dart';

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            'Profile',
            style: TextStyle(color: Color(0xFFF3F3F3)),
          ),
          backgroundColor: Color(0xFF188FA7),
        ),
        backgroundColor: Color.fromARGB(87, 226, 219, 190),
        body: const Center(
          child: Text(
            'No user logged in',
            style: TextStyle(color: Color(0xFF000000)),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(color: Color(0xFFF3F3F3)),
        ),
        backgroundColor: const Color(0xFF188FA7),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            color: const Color(0xFFF3F3F3),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginPage()),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color.fromARGB(87, 226, 219, 190),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CircleAvatar(
                radius: 50,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : const AssetImage('assets/profile.jpg') as ImageProvider,
              ),
              const SizedBox(height: 16),
              Text(
                user.displayName ?? 'No Name',
                style: const TextStyle(fontSize: 24, color: Color(0xFF000000)),
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? 'No Email',
                style: const TextStyle(fontSize: 16, color: Color(0xFF000000)),
              ),
              const SizedBox(height: 8),
              if (user.metadata.creationTime != null)
                Text(
                  'Joined on: ${DateFormat('dd/MM/yyyy').format(user.metadata.creationTime!)}',
                  style:
                      const TextStyle(fontSize: 16, color: Color(0xFF000000)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
