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
          'POST', Uri.parse('http://192.168.4.204:5000/predict'));
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
          title: Text('Change Food Name'),
          content: TextField(
            controller: _newFoodNameController,
            decoration: InputDecoration(
              hintText: 'Enter new name',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: Text('Save'),
              onPressed: () {
                setState(() {
                  _foodName = _newFoodNameController.text;
                });
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

    _showLoadingDialog();

    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      UploadTask task = FirebaseStorage.instance
          .ref('uploads/$fileName')
          .putFile(_imageFile!);

      task.snapshotEvents.listen((event) {
        setState(() {
          _uploadProgress = (event.bytesTransferred / event.totalBytes) * 100;
        });
      });

      TaskSnapshot snapshot = await task;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('estimates').add({
        'name': _foodName,
        'image_url': downloadUrl,
        'timestamp': DateTime.now(),
        ..._foodDetails!,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload complete')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
      Navigator.of(context).pop(); // Close loading dialog
    }
  }

  void _resetEstimatePage() {
    setState(() {
      _imageFile = null;
      _foodName = null;
      _foodDetails = null;
      _uploadProgress = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Estimate',
          style: TextStyle(color: Color(0xFFF3F3F3)),
        ),
        backgroundColor: Color(0xFF188FA7),
      ),
      backgroundColor: Color(0xFFE2DBBE),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (_imageFile != null)
            Image.file(
              _imageFile!,
              height: 200,
            ),
          SizedBox(height: 16),
          if (_isSubmitting) CircularProgressIndicator(),
          if (!_isSubmitting) ...[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Card(
                      color: Color(0xFFD5D6AA),
                      child: InkWell(
                        onTap: _captureImage,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera,
                                size: 80,
                                color: Color(0xFF769FB6),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Capture',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      color: Color(0xFFD5D6AA),
                      child: InkWell(
                        onTap: _uploadImage,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.upload,
                                size: 80,
                                color: Color(0xFF769FB6),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Upload',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_foodDetails != null) ...[
            SizedBox(height: 16),
            Text(
              _foodName ?? 'Unknown Food',
              style: TextStyle(fontSize: 24, color: Colors.black),
            ),
          ],
        ],
      ),
    );
  }
}
