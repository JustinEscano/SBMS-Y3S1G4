from django.shortcuts import render
from .models import User

# Show all users in the database
def user_list(request):
    users = User.objects.all()  # ← This queries AWS PostgreSQL
    return render(request, 'core/user_list.html', {'users': users})
