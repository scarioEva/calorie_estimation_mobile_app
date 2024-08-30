import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late CollectionReference _estimates;
  String _selectedOrder = 'Created At';
  late User _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    _estimates = FirebaseFirestore.instance
        .collection('users')
        .doc(_currentUser.uid)
        .collection('estimates');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estimation History',
          style: TextStyle(color: Color(0xFFF3F3F3)),
        ),
        backgroundColor: const Color(0xFF188FA7),
      ),
      backgroundColor: const Color.fromARGB(87, 226, 219, 190),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Sort by:',
                  style: TextStyle(
                    fontSize: 18,
                    color: Color(0xFF000000),
                  ),
                ),
                DropdownButton<String>(
                  value: _selectedOrder,
                  items: <String>['Created At', 'Name']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedOrder = newValue!;
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder(
              stream: _getOrderedStream(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'List is empty',
                      style: TextStyle(color: Color(0xFF000000)),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var data = doc.data() as Map<String, dynamic>;

                    return Card(
                      color: const Color(0xFFF3F3F3),
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
                        title: Text(
                          data['name'],
                          style: const TextStyle(color: Color(0xFF000000)),
                        ),
                        subtitle: Text(
                          'Created on: ${DateFormat('dd/MM/yyyy').format(data['timestamp'].toDate())}',
                          style: const TextStyle(color: Color(0xFF000000)),
                        ),
                        onTap: () {
                          _showFoodDetailsDialog(context, data, doc.id);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _getOrderedStream() {
    if (_selectedOrder == 'Name') {
      return _estimates.orderBy('name', descending: false).snapshots();
    } else {
      return _estimates.orderBy('timestamp', descending: true).snapshots();
    }
  }

  Future<void> _showFoodDetailsDialog(
      BuildContext context, Map<String, dynamic> data, String docId) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox.shrink(), // Placeholder to center the title
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.network(
                      data['image_url'],
                      height: 150,
                      width: 150,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  data['name'],
                  style: const TextStyle(
                    fontSize: 24,
                    color: Color(0xFF188FA7),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                  },
                  children: data.entries
                      .where((entry) =>
                          entry.key != 'name' &&
                          entry.key != 'image_url' &&
                          entry.key != 'timestamp')
                      .map((entry) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Text(
                            entry.key.replaceAll('_', ' '),
                            style: const TextStyle(
                              color: Color(0xFF000000),
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(
                              color: Color(0xFF000000),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () {
                _deleteFoodItem(docId, data['image_url']);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteFoodItem(String docId, String imageUrl) async {
    try {
      // Delete the document from Firestore
      await _estimates.doc(docId).delete();

      // Delete the image from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted successfully')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $e')),
      );
    }
  }
}
