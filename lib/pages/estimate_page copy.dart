import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EstimatePagec extends StatefulWidget {
  @override
  _EstimatePageState createState() => _EstimatePageState();
}

class _EstimatePageState extends State<EstimatePagec> {
  File? _image;
  final _inputController = TextEditingController();
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _captureImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.camera);
    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
      }
    });
  }

  Future<void> _uploadData() async {
    if (_image == null || _inputController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Please capture an image and enter the details')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'No user logged in';
      // Upload image to Firebase Storage
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference storageRef =
          FirebaseStorage.instance.ref().child('images/$fileName.jpg');
      UploadTask uploadTask = storageRef.putFile(_image!);

      uploadTask.snapshotEvents.listen((event) {
        setState(() {
          _uploadProgress =
              event.bytesTransferred.toDouble() / event.totalBytes.toDouble();
        });
      });

      TaskSnapshot taskSnapshot = await uploadTask;
      String imageUrl = await taskSnapshot.ref.getDownloadURL();

      // Save the input field data and image URL to Firestore
      // await FirebaseFirestore.instance.collection('history').add({
      //   'description': _inputController.text,
      //   'image_url': imageUrl,
      //   'timestamp': FieldValue.serverTimestamp(),
      // });
      CollectionReference estimates = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history');

      await estimates.add({
        'description': _inputController.text,
        'image_url': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload successful!')),
      );

      // Reset the form
      setState(() {
        _image = null;
        _inputController.clear();
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_image != null)
            Image.file(_image!, height: 200, fit: BoxFit.cover),
          SizedBox(height: 16),
          if (_image != null)
            TextFormField(
              controller: _inputController,
              decoration: InputDecoration(
                labelText: 'Enter Details',
                border: OutlineInputBorder(),
              ),
            ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _captureImage,
            child: Text(_image == null ? 'Capture' : 'Re-Capture'),
          ),
          SizedBox(height: 16),
          if (_image != null)
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadData,
              child: _isUploading
                  ? CircularProgressIndicator(value: _uploadProgress)
                  : Text('Submit'),
            ),
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: LinearProgressIndicator(value: _uploadProgress),
            ),
        ],
      ),
    );
  }
}
