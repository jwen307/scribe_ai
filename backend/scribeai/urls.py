from django.urls import path
from . import views  # Import your views from the 'api' app

urlpatterns = [
    path('upload-audio/', views.UploadAudioFileView.as_view(), name='upload-audio') 
]

