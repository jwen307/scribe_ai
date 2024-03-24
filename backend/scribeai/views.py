from django.shortcuts import render
# In your Django app's views.py
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser
from rest_framework.response import Response
from django.conf import settings  # Import settings
import os

class UploadAudioFileView(APIView):
    parser_classes = [MultiPartParser]

    def post(self, request, format=None):
        audio_file = request.FILES['audio_file'] 

        # Enhanced saving for debugging 
        destination_path = os.path.join(settings.MEDIA_ROOT, 'test_upload.wav')
        with open(destination_path, 'wb+') as destination:
            for chunk in audio_file.chunks():
                destination.write(chunk)

        return Response({"message": "Audio file received!"}) # Simplified for troubleshooting
