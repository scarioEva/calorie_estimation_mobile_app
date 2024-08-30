import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EstimatePage extends StatefulWidget {
  @override
  _EstimatePageState createState() => _EstimatePageState();
}

class _EstimatePageState extends State<EstimatePage> {
  final ImagePicker _picker = ImagePicker();
  File? _imageFile;
  String? _foodName;
  Map<String, dynamic>? _foodDetails;
  bool _isSubmitting = false;

  Future<void> _captureImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
      await _getFoodDetails();
    }
  }

  Future<void> _uploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
      await _getFoodDetails();
    }
  }

  Future<void> _getFoodDetails() async {
    if (_imageFile == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      var request = http.MultipartRequest(
          'POST', Uri.parse('http://192.168.0.139:5000/predict'));
      request.files
          .add(await http.MultipartFile.fromPath('file', _imageFile!.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        var responseData = jsonDecode(responseBody);

        setState(() {
          _foodName = responseData['name'];
          _foodDetails = responseData;
        });
      } else {
        throw 'Failed to get food details from API';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _updateFoodDetails(String newFoodName) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      var response = await http.post(
        Uri.parse('http://192.168.0.139:5000/get-food-details'),
        body: jsonEncode({'food_name': newFoodName}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        setState(() {
          _foodName = newFoodName;
          _foodDetails = responseData;
        });
      } else {
        throw 'Failed to get updated food details from API';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _showChangeNameDialog() async {
    TextEditingController _newFoodNameController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Change Food Name'),
          content: TextField(
            controller: _newFoodNameController,
            decoration: const InputDecoration(
              hintText: 'Enter food name',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Submit'),
              onPressed: () async {
                String newFoodName = _newFoodNameController.text;
                await _updateFoodDetails(newFoodName);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadToFirebase() async {
    if (_imageFile == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      UploadTask task = FirebaseStorage.instance
          .ref('food_images/$fileName')
          .putFile(_imageFile!);

      TaskSnapshot snapshot = await task;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      CollectionReference estimates = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('estimates');

      await estimates.add({
        'name': _foodName,
        'image_url': downloadUrl,
        'timestamp': DateTime.now(),
        ..._foodDetails!,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved successfully!!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _foodDetails = null;
        _isSubmitting = false;
        _imageFile = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estimate',
          style: TextStyle(color: Color(0xFFF3F3F3)),
        ),
        backgroundColor: const Color(0xFF188FA7),
      ),
      backgroundColor: const Color.fromARGB(87, 226, 219, 190),
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (_imageFile != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Image.file(
                  _imageFile!,
                  height: 200,
                ),
              ),
            const SizedBox(height: 16),
            if (_isSubmitting)
              const CircularProgressIndicator()
            else if (_foodDetails != null) ...[
              Text(
                _foodName ?? 'Unknown Food',
                style: const TextStyle(fontSize: 24, color: Colors.black),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Table(
                  border: TableBorder.all(color: Colors.black),
                  children: _foodDetails!.entries
                      .where((entry) => entry.key != 'name')
                      .map((entry) {
                    return TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            entry.key.replaceAll('_', ' ').toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(entry.value.toString()),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _showChangeNameDialog,
                    child: const Text('Change Name'),
                  ),
                  ElevatedButton(
                    onPressed: _uploadToFirebase,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 20),
              const Text(
                'Please capture or upload a food image.',
                style: TextStyle(fontSize: 18, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCaptureOrUploadCard(
                    icon: Icons.camera,
                    label: 'Capture',
                    onPressed: _captureImage,
                  ),
                  _buildCaptureOrUploadCard(
                    icon: Icons.upload,
                    label: 'Upload',
                    onPressed: _uploadImage,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureOrUploadCard({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: Card(
        color: const Color(0xFFD5D6AA),
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 50,
                  color: const Color(0xFF769FB6),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
