import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class HomePage extends StatelessWidget {
  final CollectionReference _estimates =
      FirebaseFirestore.instance.collection('estimates');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Page'),
      ),
      body: StreamBuilder(
        stream: _estimates.snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.data!.docs.isEmpty) {
            return Center(child: Text('List is empty'));
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;

              return Card(
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      data['image_url'],
                      height: 50,
                      width: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(data['name']),
                  subtitle: Text(
                      'Created on: ${DateFormat('dd/MM/yyyy').format(data['timestamp'].toDate())}'),
                  onTap: () {
                    _showFoodDetailsDialog(context, data);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showFoodDetailsDialog(
      BuildContext context, Map<String, dynamic> data) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(data['name']),
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
              children: data.entries.map((entry) {
                if (entry.key == 'name' ||
                    entry.key == 'image_url' ||
                    entry.key == 'timestamp') return SizedBox.shrink();
                return Text(
                    '${entry.key.replaceAll('_', ' ')}: ${entry.value}');
              }).toList(),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
