from rest_framework import viewsets
from rest_framework import generics
from .models import *
from .serializers import *
from django.http import HttpResponse
from rest_framework.permissions import AllowAny
from rest_framework_simplejwt.views import TokenObtainPairView

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [AllowAny]

def home(request):
    return HttpResponse("Welcome to the DBMS API.")

class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.all()
    serializer_class = UserSerializer

class RoomViewSet(viewsets.ModelViewSet):
    queryset = Room.objects.all()
    serializer_class = RoomSerializer

class EquipmentViewSet(viewsets.ModelViewSet):
    queryset = Equipment.objects.all()
    serializer_class = EquipmentSerializer

class SensorLogViewSet(viewsets.ModelViewSet):
    queryset = SensorLog.objects.all()
    serializer_class = SensorLogSerializer

class MaintenanceRequestViewSet(viewsets.ModelViewSet):
    queryset = MaintenanceRequest.objects.all()
    serializer_class = MaintenanceRequestSerializer

class LLMQueryViewSet(viewsets.ModelViewSet):
    queryset = LLMQuery.objects.all()
    serializer_class = LLMQuerySerializer

class LLMSummaryViewSet(viewsets.ModelViewSet):
    queryset = LLMSummary.objects.all()
    serializer_class = LLMSummarySerializer

class AuthTokenViewSet(viewsets.ModelViewSet):
    queryset = AuthToken.objects.all()
    serializer_class = AuthTokenSerializer
