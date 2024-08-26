import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Food Estimates'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('estimates')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text('List is empty'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var document = snapshot.data!.docs[index];
              var foodName = document['name'] ?? 'Unknown';
              var foodImageUrl = document['image_url'];
              var timestamp = document['timestamp'] as Timestamp;
              var formattedDate =
                  DateFormat.yMMMd().add_jm().format(timestamp.toDate());

              return GestureDetector(
                onTap: () {
                  _showFoodDetailsDialog(
                      context, foodName, document['details'], foodImageUrl);
                },
                child: Card(
                  margin: EdgeInsets.all(10.0),
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Rounded Food Image
                        if (foodImageUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10.0),
                            child: Image.network(
                              foodImageUrl,
                              height: 100.0,
                              width: 100.0,
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Container(
                            height: 100.0,
                            width: 100.0,
                            color: Colors.grey[300],
                            child: Icon(
                              Icons.fastfood,
                              color: Colors.grey[700],
                              size: 50.0,
                            ),
                          ),
                        SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                foodName,
                                style: TextStyle(
                                  fontSize: 20.0,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8.0),
                              Text(
                                'Created on: $formattedDate',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showFoodDetailsDialog(BuildContext context, String foodName,
      Map<String, dynamic> foodDetails, String foodImageUrl) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(foodName),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: foodDetails.entries.map((entry) {
                return Text(
                    '${entry.key.replaceAll('_', ' ')}: ${entry.value}');
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}
