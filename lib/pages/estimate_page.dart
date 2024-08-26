import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
  double _uploadProgress = 0;

  Future<void> _captureImage({bool fromGallery = false}) async {
    final XFile? image = await _picker.pickImage(
      source: fromGallery ? ImageSource.gallery : ImageSource.camera,
    );
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

        await _showFoodDetailsDialog();
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

  Future<void> _showLoadingDialog() {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Uploading...'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showFoodDetailsDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_foodName ?? 'Unknown Food'),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetEstimatePage();
                },
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: _foodDetails!.entries.map((entry) {
                if (entry.key == 'name') return SizedBox.shrink();
                return Text(
                    '${entry.key.replaceAll('_', ' ')}: ${entry.value}');
              }).toList(),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Change Name'),
              onPressed: () {
                Navigator.of(context).pop();
                _showChangeNameDialog();
              },
            ),
            ElevatedButton(
              child: Text('Save'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _uploadToFirebase();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showChangeNameDialog() async {
    TextEditingController _newFoodNameController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Change Food Name'),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetEstimatePage();
                },
              ),
            ],
          ),
          content: TextField(
            controller: _newFoodNameController,
            decoration: InputDecoration(labelText: 'Enter new food name'),
          ),
          actions: <Widget>[
            ElevatedButton(
              child: Text('Submit'),
              onPressed: () async {
                String newFoodName = _newFoodNameController.text;
                await _getUpdatedFoodDetails(newFoodName);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _getUpdatedFoodDetails(String foodName) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      var response = await http.post(
        Uri.parse('http://192.168.0.139:5000/get-food-details'),
        body: jsonEncode({'food_name': foodName}),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);

        setState(() {
          _foodName = responseData['name'];
          _foodDetails = responseData;
        });

        Navigator.of(context).pop(); // Close the change name dialog
        await _showFoodDetailsDialog(); // Reopen the food details dialog with updated info
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

  Future<void> _uploadToFirebase() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'No user logged in';

      // Show loading dialog
      _showLoadingDialog();

      // Upload the image to Firebase Storage
      String fileName =
          DateTime.now().millisecondsSinceEpoch.toString() + '.jpg';
      Reference storageReference =
          FirebaseStorage.instance.ref().child('images').child(fileName);
      UploadTask uploadTask = storageReference.putFile(_imageFile!);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred.toDouble() /
              snapshot.totalBytes.toDouble();
        });
      });

      TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      // Save to Firestore
      CollectionReference estimates = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('estimates');

      await estimates.add({
        'name': _foodName ?? 'Unknown',
        'details': _foodDetails,
        'image_url': downloadUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Data submitted successfully!')),
      );

      // Clear state after submission
      _resetEstimatePage();
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog if an error occurs
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _resetEstimatePage() {
    setState(() {
      _imageFile = null;
      _foodName = null;
      _foodDetails = null;
      _isSubmitting = false;
      _uploadProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Estimate Page'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: <Widget>[
            if (_imageFile != null)
              Column(
                children: [
                  Image.file(_imageFile!, height: 200, fit: BoxFit.cover),
                  SizedBox(height: 8.0),
                  _isSubmitting
                      ? Column(
                          children: [
                            LinearProgressIndicator(value: _uploadProgress),
                            SizedBox(height: 8.0),
                            Text(
                                '${(_uploadProgress * 100).toStringAsFixed(2)}%'),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: _captureImage,
                              child: Text('Re-Capture'),
                            ),
                          ],
                        ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () => _captureImage(fromGallery: false),
                    child: Text('Capture'),
                  ),
                  ElevatedButton(
                    onPressed: () => _captureImage(fromGallery: true),
                    child: Text('Upload'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
