import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:torch_light/torch_light.dart';

var logger = Logger();
List<Uint8List> frameList = []; // List to store the frames
String predictionReceived = '';
List<String> predictedWords = [];
String predictedSentence = '';
List<dynamic> responseBody = [];
Color borderColor = Colors.transparent;
String ip = "172.20.10.2";
List<String> sentenceArray = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of available cameras
  final cameras = await availableCameras();
  var camera = cameras[0];

  runApp(CameraApp(camera: camera));
}

void sendFramesToWebService(Function(String) updatePredictedWords) async {
  // Create a URL for your Python web service
  final url = Uri.parse('http://$ip:8000/api/predict');

  // Convert the frameList to a list of base64-encoded strings
  //final framesData = frameList.map((frame) => frame.buffer.asUint8List()).toList();
  final framesBase64 = frameList.map((data) => base64.encode(data)).toList();

  // Create the request body
  final body = jsonEncode({'frames': framesBase64});

  // Send the POST request
  final response = await http
      .post(url, body: body, headers: {'Content-Type': 'application/json'});

  // Check the response status
  if (response.statusCode == 200) {
    // Frames successfully sent to the web service
    logger.d('Frames sent successfully!');
    final jsonResponse = jsonDecode(response.body);

    // Extract the predicted word from the response
    final predictedWord = jsonResponse['predicted'];
    logger.d('Predicted word: $predictedWord');
    updatePredictedWords(predictedWord);

    //predictedWords.add(predictedWord);

    logger.d('Predicted wordsarray: $predictedWords');
    //update widget
  } else {
    // Error occurred while sending frames
    logger.d('Failed to send frames. Error: ${response.body}');
  }
}

void sendWordsToWebService(Function(String) updatePredictedSentences) async {
  // Create a URL for your Python web service
  final urlWords = Uri.parse('http://$ip:8000/api/generate');

  // Convert the frameList to a list of base64-encoded strings

  // Create the request body
  final bodyWords = jsonEncode({'words': predictedWords});

  // Send the POST request
  final response = await http.post(urlWords,
      body: bodyWords, headers: {'Content-Type': 'application/json'});

  // Check the response status
  if (response.statusCode == 200) {
    // Frames successfully sent to the web service
    final jsonResponse = jsonDecode(response.body);

    // Extract the predicted word from the response
    final predictedSentenceNew = jsonResponse['sentence'];

    // Append the predicted word to the predictedWords array
    updatePredictedSentences(predictedSentenceNew);

    logger.d('Predicted sentence: $predictedSentence');
  } else {
    // Error occurred while sending words
    logger.d('Failed to send words. Error: ${response.body}');
  }
}

class PredictedWordsWidget extends StatefulWidget {
  final List<String> predictedWords;

  const PredictedWordsWidget({Key? key, required this.predictedWords})
      : super(key: key);

  @override
  _PredictedWordsWidgetState createState() => _PredictedWordsWidgetState();
}

class _PredictedWordsWidgetState extends State<PredictedWordsWidget> {
  @override
  Widget build(BuildContext context) {
    final widthh = MediaQuery.of(context).size.width;
    final heightt = MediaQuery.of(context).size.height;
    final blockSize = widthh / 100;
    final blockSizeVertical = heightt / 100;
    return SizedBox(
      width: widthh,
      height: blockSizeVertical * 70,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Text(
          'Predicted Words: ${widget.predictedWords}',
          style: TextStyle(color: Colors.black87, fontSize: 12.0),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class PredictedSentencesWidget extends StatefulWidget {
  final String predictedSentence;

  const PredictedSentencesWidget({Key? key, required this.predictedSentence})
      : super(key: key);

  @override
  _PredictedSentencesWidgetState createState() =>
      _PredictedSentencesWidgetState();
}

class _PredictedSentencesWidgetState extends State<PredictedSentencesWidget> {
  @override
  Widget build(BuildContext context) {
    final widthh = MediaQuery.of(context).size.width;
    final heightt = MediaQuery.of(context).size.height;
    final blockSize = widthh / 100;
    final blockSizeVertical = heightt / 100;
    return SizedBox(
      width: widthh,
      height: blockSizeVertical * 75,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Text(
          'Predicted Sentence: ${widget.predictedSentence}',
          style: TextStyle(color: Colors.black87, fontSize: 12.0),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class CameraApp extends StatefulWidget {
  final CameraDescription camera;

  const CameraApp({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController _controller;
  bool _isRecording = false;
  int pageIndex = 0;
  late Timer mytimer;
  bool timerFlag = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          ImageFormatGroup.bgra8888, // Specify a supported format group for iOS
    );
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });

    mytimer = Timer.periodic(Duration(seconds: 10), (timer) async {
      //code to run on every 4 secs
      borderColor = Colors.green;
      if (_isRecording == false) {
        _startRecording();
        timerFlag = true;
      } else {
        try {
          await TorchLight.enableTorch();
        } on Exception catch (_) {
          // Handle error
        }
        timerFlag = true;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
    mytimer?.cancel();
  }

  void updatePredictedWords(String predictedWord) {
    setState(() {
      predictedWords.add(predictedWord);
    });
  }

  void updatePredictedSentences(String predictedSentenceNew) {
    setState(() {
      predictedSentence = predictedSentenceNew;
    });
  }

  Future<void> _startRecording() async {
    if (!_controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isRecording = true;
    });

    // Start the camera preview and set the desired fps
    await _controller.startImageStream((CameraImage image) async {
      if (_isRecording) {
        // Convert the image to a byte array
        List<Uint8List> planes = image.planes.map((plane) {
          return plane.bytes;
        }).toList();
        Uint8List bytes = planes[0];

        // Add the frame to the frameList
        frameList.add(bytes);
        //log the length of frameList
        logger.d('frameList length: ${frameList.length}    $timerFlag');
        if (frameList.length == 60) {
          timerFlag = false;
          _controller.setFlashMode(FlashMode.off);
          sendFramesToWebService(updatePredictedWords);
          frameList.clear(); // Clear the frameList after sending frames
          borderColor = Colors.red;
          try {
            await TorchLight.disableTorch();
          } on Exception catch (_) {
            // Handle error
          }
        }
        if (timerFlag == false) {
          frameList.clear();
          borderColor = Colors.red;
        }
      }
    });
  }

  void _resetArrays() {
    setState(() {
      sentenceArray.add(predictedSentence);
      predictedSentence = '';
      predictedWords = [];
    });
  }

  Future<void> _stopRecording() async {
    if (!_controller.value.isInitialized) {
      return;
    }

    setState(() {
      _isRecording = false;
    });

    // Stop the camera preview
    await _controller.stopImageStream();
  }

  void _onItemTapped(int index) {
    setState(() {
      pageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
      home: Scaffold(
        extendBody: true,
        appBar: AppBar(
          title: const Text('Sign Language Translator'),
        ),
        body: Builder(builder: (BuildContext context) {
          final widthh = MediaQuery.of(context).size.width;
          final heightt = MediaQuery.of(context).size.height;
          final blockSize = widthh / 100;
          final blockSizeVertical = heightt / 100;
          if (pageIndex == 0) {
            return Stack(
              children: <Widget>[
                ClipRRect(
                  child: SizedOverflowBox(
                    size: Size(widthh, blockSizeVertical * 60),
                    alignment: Alignment.topCenter,
                    child: CameraPreview(_controller),
                  ),
                ),
                Container(
                  width: widthh,
                  height: blockSizeVertical * 60,
                  padding: const EdgeInsets.fromLTRB(5.0, 5.0, 5.0, 5.0),
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                      border: Border.all(
                          color: timerFlag ? Colors.green : Colors.red,
                          width: 5.0),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black,
                        ],
                      )),
                ),
                SizedBox(
                  width: widthh,
                  height: blockSizeVertical * 70,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: PredictedWordsWidget(predictedWords: predictedWords),
                  ),
                ),
                SizedBox(
                    width: widthh,
                    height: blockSizeVertical * 75,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: PredictedSentencesWidget(
                          predictedSentence: predictedSentence),
                    )),
                SizedBox(
                    width: widthh,
                    height: blockSizeVertical * 60,
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ElevatedButton(
                            onPressed: _resetArrays, child: Text('Reset')))),
                SizedBox(
                    width: widthh,
                    height: blockSizeVertical * 50,
                    child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ElevatedButton(
                            onPressed: () =>
                                sendWordsToWebService(updatePredictedSentences),
                            child: Text('Create Sentence')))),
              ],
            );
          } else {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (String sentence in sentenceArray)
                    Text(
                      "[$sentence]",
                      style: TextStyle(color: Colors.black, fontSize: 20.0),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            );
          }
        }),
        bottomNavigationBar: BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.accessibility_new),
              label: 'Translator',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.article),
              label: 'Chat History',
            ),
          ],
          currentIndex: pageIndex,
          onTap: _onItemTapped,
        ),
      ),

      /* */
    );
    // return MaterialApp(
    //   home: Scaffold(
    //     appBar: AppBar(
    //       title: const Text('Camera App'),
    //     ),
    //     body: Column(
    //       children: [
    //         Expanded(
    //           child: Center(
    //             child: AspectRatio(
    //               aspectRatio: _controller.value.aspectRatio,
    //               child: CameraPreview(_controller),
    //             ),
    //           ),
    //         ),
    //         Container(
    //           alignment: Alignment.center,
    //           padding: EdgeInsets.all(10),
    //           child: _isRecording
    //               ? ElevatedButton(
    //                   onPressed: _stopRecording,
    //                   child: Text('Stop Recording'),
    //                 )
    //               : ElevatedButton(
    //                   onPressed: _startRecording,
    //                   child: Text('Start Recording'),
    //                 ),
    //         ),
    //       ],
    //     ),
    //   ),
    // );
  }
}
