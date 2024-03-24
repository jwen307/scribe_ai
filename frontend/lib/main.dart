import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:envied/envied.dart';
import 'env/env.dart';
import 'package:dart_openai/dart_openai.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() {
  OpenAI.apiKey = Env.apiKey; // Set the API key from the .env file
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical Scribe',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: RecordScreen(),
    );
  }
}

class RecordScreen extends StatefulWidget {
  @override
  _RecordScreenState createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  bool _isRecording = false; // Tracks recording state

  bool _isTranscripting = false; // Tracks transcription state

  bool _isGenerating = false; // Tracks the state of the AI generation

  //final record = AudioRecorder();
  AudioRecorder? record; // Make it nullable
  String? _audioFilePath;

  String transcriptionText = ''; // Store the transcription
  String? doctorsNoteText = ''; // Store the doctor's note

  //Setup the Google AI API
  final model = GenerativeModel(model: 'gemini-pro', apiKey: Env.genApiKey);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medical Scribe'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 100,
              color: _isRecording ? Colors.red : Colors.blue,
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              onPressed: _toggleRecording,
            ),
            SizedBox(height: 20),
            Text(
              _isRecording ? 'Recording...' : 'Press to Start Recording',
              style: TextStyle(fontSize: 20),
            ),

            SizedBox(height: 20),
            Text(
              _isTranscripting ? 'Transcripting...' : 'Transcription: ',
              style: TextStyle(fontSize: 20),
            ),

            // Transcription Text Display
            SizedBox(height: 20), // Add a spacer
            Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  // Make the text box scrollable
                  child: TextField(
                    maxLines: 10, // Allow multiple lines
                    decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Transcription will appear here'),
                    readOnly: true,
                    controller: TextEditingController(text: transcriptionText),
                  ),
                )),

            SizedBox(height: 20),
            Text(
              _isTranscripting ? 'Generating...' : 'Generated Note: ',
              style: TextStyle(fontSize: 20),
            ),

            // Doctor's Note Text Display
            SizedBox(height: 20),
            Container(
                width: MediaQuery.of(context).size.width * 0.8,
                child: SingleChildScrollView(
                  // Make the text box scrollable
                  child: TextField(
                    maxLines: 15, // Allow multiple lines
                    decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Doctor\'s Note'),
                    readOnly: true,
                    controller: TextEditingController(text: doctorsNoteText),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // Function to start/stop recording
  void _toggleRecording() {
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  // Placeholder functions for starting and stopping (To Be Implemented)
  void _startRecording() async {
    record = AudioRecorder();

    if (await record!.hasPermission()) {
      // Get a suitable path for storing the audio file
      Directory appDocDir;
      try {
        appDocDir = await getApplicationDocumentsDirectory();
      } catch (e) {
        print('Error getting application documents directory: $e');
        return;
      }
      String path = appDocDir.path;
      String audioFilePath = '$path/recording.wav';
      print(audioFilePath);

      // Start recording
      try {
        await record!.start(const RecordConfig(encoder: AudioEncoder.wav),
            path: 'recording.wav');
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print('There was an error starting the recording: $e');
      }

      setState(() {
        _isRecording = true;
      });
    } else {
      // Handle the case where permission is denied
      print("No microphone permission");
    }
  }

  void _stopRecording() async {
    final path = await record!.stop();

    setState(() {
      _isRecording = false;
      _audioFilePath = path; // Update the stored audio file path
      _isTranscripting = true; // Set the state to indicate transcription
    });

    if (_audioFilePath != null) {
      // Everything worked - Process the audio file
      try {
        OpenAIAudioModel transcription =
            await OpenAI.instance.audio.createTranscription(
          file: File(_audioFilePath!),
          model: "whisper-1",
          responseFormat: OpenAIAudioResponseFormat.json,
        );
        // print the transcription.
        print(transcription.text);

        // Set the transcription text in the UI
        setState(() {
          transcriptionText = transcription.text;
          _isTranscripting = false; // Set the state to indicate transcription
          _isGenerating = true; // Set the state to indicate generation
        });

        // Setup the content for the Google AI API
        // final content = [
        //   Content.text(
        //       "You are an AI medical scribe. Your task is to take the input from a conversation between a doctor and patient and output a doctor's note. The output should be in the following format:\n```\nPatient History: {Description of the patient (age, gender) and relevant previous medical history}\n\nSymptoms: {A description of the symptoms}\n\nPotential Causes:\n{- Potential Cause 1: Description of why it should or should not be ruled out\n- Potential Cause 2: Description of why it should or should not be ruled out\n- More as needed}\n\nDiagnosis: {A description of the diagnosis from the doctor}\n\nTreatment: {A description of the prescribed treatment}\n```"),
        //   Content.text(
        //       "input: Hi, my name is Dr. Johnson. Can you please confirm your date of birth for me. 01-01-1995. Thank you. What brings you in today? I've been have pain in the back of my knee for a few weeks now. I started to feeling the pain after playing basketball. I took an awkward fall. I didn't feel anything pop, but my knee did not feel good after that. I see, what would you rate you pain as on a scale of 1 to 10. 4. And when do you feel the pain, all the time or when you're walking, running, jumping? Mostly when I start walking or moving my leg. Gotcha, well, it's hard to know for sure what is going on with your knee without visually seeing it. I'm going to have schedule an MRI to see if there is any damage to the ligaments or meniscus. In the meantime, you should rest your leg and ice it. Take up to 2 ibuprofen a day if you feel like the pain is bothering you too much."),
        //   Content.text(
        //       "output: **Patient History:** 28-year-old patient with no significant past medical history.\n\n**Symptoms:** Pain in the back of the knee for several weeks, with a pain level of 4/10. Pain primarily occurs when walking or moving the leg. The pain started after a fall during basketball. \n\n**Potential Causes:**\n- **Ligament injury:** The fall could have caused damage to one or more ligaments in the knee, such as the ACL, PCL, MCL, or LCL. An MRI is needed to confirm or rule out this possibility.\n- **Meniscus tear:** A tear in the meniscus, the cartilage that acts as a shock absorber in the knee, could also be causing the pain. An MRI can help diagnose this issue.\n- **Other potential causes:** Other less likely causes, such as bursitis or tendinitis, should also be considered.\n\n**Diagnosis:** The exact diagnosis is currently unknown and requires further investigation with an MRI.\n\n**Treatment:** \n- Rest and ice the affected knee.\n-  Take up to 2 ibuprofen a day for pain management.\n-  Schedule an MRI to assess potential damage to ligaments or meniscus.\n\n**Follow-up:** The patient will need to return for a follow-up appointment to discuss the MRI results and determine further treatment options."),
        //   Content.text(
        //       "input: Hi, my name is Dr. Johnson. Can you please confirm your date of birth for me. 01-01-1995. Thank you. What brings you in today? I've been have pain in the back of my knee for a few weeks now. I started to feeling the pain after playing basketball. I took an awkward fall. I didn't feel anything pop, but my knee did not feel good after that. I see, what would you rate you pain as on a scale of 1 to 10. 4. And when do you feel the pain, all the time or when you're walking, running, jumping? Mostly when I start walking or moving my leg. Gotcha, well, it's hard to know for sure what is going on with your knee without visually seeing it. I'm going to have schedule an MRI to see if there is any damage to the ligaments or meniscus. In the meantime, you should rest your leg and ice it. Take up to 2 ibuprofen a day if you feel like the pain is bothering you too much."),
        // ];

        final content = [
          Content.multi([
            TextPart(
                "You are an AI medical scribe. Your task is to take the input from a conversation between a doctor and patient and output a doctor's note. The output should be in the following format:\n```\nPatient History: {Description of the patient (age, gender) and relevant previous medical history}\n\nSymptoms: {A description of the symptoms}\n\nPotential Causes:\n{- Potential Cause 1: Description of why it should or should not be ruled out\n- Potential Cause 2: Description of why it should or should not be ruled out\n- More as needed}\n\nDiagnosis: {A description of the diagnosis from the doctor}\n\nTreatment: {A description of the prescribed treatment}\n```"),
            TextPart(
                "input: Hi, my name is Dr. Johnson. Can you please confirm your date of birth for me. 01-01-1995. Thank you. What brings you in today? I've been have pain in the back of my knee for a few weeks now. I started to feeling the pain after playing basketball. I took an awkward fall. I didn't feel anything pop, but my knee did not feel good after that. I see, what would you rate you pain as on a scale of 1 to 10. 4. And when do you feel the pain, all the time or when you're walking, running, jumping? Mostly when I start walking or moving my leg. Gotcha, well, it's hard to know for sure what is going on with your knee without visually seeing it. I'm going to have schedule an MRI to see if there is any damage to the ligaments or meniscus. In the meantime, you should rest your leg and ice it. Take up to 2 ibuprofen a day if you feel like the pain is bothering you too much."),
            TextPart(
                "output: **Patient History:** 28-year-old patient with no significant past medical history.\n\n**Symptoms:** Pain in the back of the knee for several weeks, with a pain level of 4/10. Pain primarily occurs when walking or moving the leg. The pain started after a fall during basketball. \n\n**Potential Causes:**\n- **Ligament injury:** The fall could have caused damage to one or more ligaments in the knee, such as the ACL, PCL, MCL, or LCL. An MRI is needed to confirm or rule out this possibility.\n- **Meniscus tear:** A tear in the meniscus, the cartilage that acts as a shock absorber in the knee, could also be causing the pain. An MRI can help diagnose this issue.\n- **Other potential causes:** Other less likely causes, such as bursitis or tendinitis, should also be considered.\n\n**Diagnosis:** The exact diagnosis is currently unknown and requires further investigation with an MRI.\n\n**Treatment:** \n- Rest and ice the affected knee.\n-  Take up to 2 ibuprofen a day for pain management.\n-  Schedule an MRI to assess potential damage to ligaments or meniscus.\n\n**Follow-up:** The patient will need to return for a follow-up appointment to discuss the MRI results and determine further treatment options."),
            TextPart("input: " + transcriptionText),
          ])
        ];

        // Generate the doctor's note using the Google AI API
        final response = await model.generateContent(content);

        setState(() {
          doctorsNoteText = response.text; // Update with AI-generated note
          _isGenerating = false; // Set the state to indicate generation
        });
      } on RequestFailedException catch (e) {
        print(e.message);
        print(e.statusCode);
      }
    } else {
      // Handle the error - Inform the user
      print("Recording failed - audio file path is null");
    }

    record!.dispose(); // Dispose of the recorder object
  }

  // void _sendAudioToServer() async {
  //   if (_audioFilePath != null) {
  //     print('File path: $_audioFilePath');
  //     print(Uri.parse('http://127.0.0.1:8000/scribeai/upload-audio/'));

  //     var request = http.MultipartRequest(
  //         "POST", Uri.parse('http://127.0.0.1:8000/scribeai/upload-audio/'));

  //     // Add other fields if needed (e.g., API Keys)
  //     // ...

  //     try {
  //       request.files.add(await http.MultipartFile.fromPath(
  //         'audio_file',
  //         _audioFilePath!,
  //       ));
  //     } catch (error) {
  //       print('Error creating MultipartFile: $error');
  //     }

  //     try {
  //       final response = await request.send();
  //       print('Response Status code: ${response.statusCode}');
  //       if (response.statusCode == 200) {
  //         // Handle success
  //         print('Audio file uploaded successfully');
  //       } else {
  //         // Handle errors
  //         print('Failed to upload: ${response.statusCode}');
  //       }
  //     } catch (error) {
  //       print('Error uploading: $error');
  //     }
  //   }
  // }
}
