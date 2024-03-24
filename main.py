import sounddevice as sd
from scipy.io.wavfile import read, write 
import time
from dotenv import load_dotenv
import os
import tkinter as tk
from tkinter import filedialog, messagebox


from openai import OpenAI
import google.generativeai as genai



def record_audio():
    global is_recording  # Indicate recording status

    def callback(indata, frames, time, status):
        if status:
            print(status, file=sys.stderr)
        if is_recording:
            recording.extend(indata.copy()) 

    fs = 44100
    duration = float("inf")  # Record until stopped
    recording = []
    is_recording = True

    with sd.InputStream(samplerate=fs, channels=1, callback=callback):
        print("Recording...")
        while is_recording:
            sd.sleep(100)  # Reduce CPU usage

    # Stop recording
    is_recording = False
    print("Recording finished.")
    return fs, recording

# Function to play the audio
def play_audio(filename="recording.wav"):
    print("Playing back audio...")
    fs, data = read(filename)
    
    #print(data.max())

    # Play the audio
    sd.play(data, fs)
    sd.wait()  # Wait for playback to finish
    print("Playback finished.")

def transcribe_audio(filename="recording.wav"):
    client = OpenAI()

    # Transcribe the audio
    with open("recording.wav", "rb") as f:
        transcription = client.audio.transcriptions.create(
            model = "whisper-1",
            file = f,
            response_format = 'text'
        )

    #print(transcription)
    return transcription


def get_note(transcription):
    # Setup the Gemini API
    generation_config = {
    "temperature": 0.9,
    "top_p": 1,
    "top_k": 1,
    "max_output_tokens": 2048,
    }

    safety_settings = [
    {
        "category": "HARM_CATEGORY_HARASSMENT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
        "category": "HARM_CATEGORY_HATE_SPEECH",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
        "category": "HARM_CATEGORY_SEXUALLY_EXPLICIT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    {
        "category": "HARM_CATEGORY_DANGEROUS_CONTENT",
        "threshold": "BLOCK_MEDIUM_AND_ABOVE"
    },
    ]

    genai.configure(api_key=os.environ.get("GOOOGLE_API_KEY"))
    model = genai.GenerativeModel(model_name="gemini-1.0-pro",
                                generation_config=generation_config,
                                safety_settings=safety_settings)

    prompt_parts = [
    "You are an AI medical scribe. Your task is to take the input from a conversation between a doctor and patient and output a doctor's note. The output should be in the following format:\n```\nPatient History: {Description of the patient (age, gender) and relevant previous medical history}\n\nSymptoms: {A description of the symptoms}\n\nPotential Causes:\n{- Potential Cause 1: Description of why it should or should not be ruled out\n- Potential Cause 2: Description of why it should or should not be ruled out\n- More as needed}\n\nDiagnosis: {A description of the diagnosis from the doctor}\n\nTreatment: {A description of the prescribed treatment}\n```",
    "input: Hi, my name is Dr. Johnson. Can you please confirm your date of birth for me. 01-01-1995. Thank you. What brings you in today? I've been have pain in the back of my knee for a few weeks now. I started to feeling the pain after playing basketball. I took an awkward fall. I didn't feel anything pop, but my knee did not feel good after that. I see, what would you rate you pain as on a scale of 1 to 10. 4. And when do you feel the pain, all the time or when you're walking, running, jumping? Mostly when I start walking or moving my leg. Gotcha, well, it's hard to know for sure what is going on with your knee without visually seeing it. I'm going to have schedule an MRI to see if there is any damage to the ligaments or meniscus. In the meantime, you should rest your leg and ice it. Take up to 2 ibuprofen a day if you feel like the pain is bothering you too much.",
    "output: **Patient History:** 28-year-old patient with no significant past medical history.\n\n**Symptoms:** Pain in the back of the knee for several weeks, with a pain level of 4/10. Pain primarily occurs when walking or moving the leg. The pain started after a fall during basketball. \n\n**Potential Causes:**\n- **Ligament injury:** The fall could have caused damage to one or more ligaments in the knee, such as the ACL, PCL, MCL, or LCL. An MRI is needed to confirm or rule out this possibility.\n- **Meniscus tear:** A tear in the meniscus, the cartilage that acts as a shock absorber in the knee, could also be causing the pain. An MRI can help diagnose this issue.\n- **Other potential causes:** Other less likely causes, such as bursitis or tendinitis, should also be considered.\n\n**Diagnosis:** The exact diagnosis is currently unknown and requires further investigation with an MRI.\n\n**Treatment:** \n- Rest and ice the affected knee.\n-  Take up to 2 ibuprofen a day for pain management.\n-  Schedule an MRI to assess potential damage to ligaments or meniscus.\n\n**Follow-up:** The patient will need to return for a follow-up appointment to discuss the MRI results and determine further treatment options.",
    f"input: {transcription}",
    "output: ",
    ]
 
    response = model.generate_content(prompt_parts)
    #print(response.text)
    return response.text

def start_stop_recording():
    if not is_recording:
        global recording
        recording = []  # Reset recording data
        fs, recording = record_audio()
        if recording: 
            write('recording.wav', fs, recording)
            process_button['state'] = tk.NORMAL  # Enable process button


# Load the environment variables from .env file
load_dotenv()

# Create the main window
root = tk.Tk()
root.title("AI Medical Scribe")

is_recording = False  # Indicate recording status
recording = []  # Store the recording data

# Update GUI
tk.Button(root, text="Start/Stop Recording", command=start_stop_recording).pack() 

root.mainloop()






