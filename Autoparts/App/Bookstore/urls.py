from django.urls import path
from Bookstore import views
from .views import mostrar_stock

urlpatterns = [
    path('',views.PaginaInicial, name='PaginaInicial'),
    path('carrito/', views.Carrito, name='carrito'),
    path('mostrar_stock', mostrar_stock, name='mostrar_stock'),
]