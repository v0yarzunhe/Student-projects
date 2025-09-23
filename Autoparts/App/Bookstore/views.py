from django.shortcuts import render
import requests, json
# Create your views here.

def PaginaInicial(request):
    context = {
        "user": "",
    }
    return render(request, "Paginas/PaginaInicial.html", context)

def Carrito(request):
    context = {
        "user": "",
    }
    return render(request, "Paginas/Carrito.html", context)

def mostrar_stock(request):
    try:
        response = requests.get("http://127.0.0.1:5000/bodega")
        productos = response.json()
    except Exception as e:
        print("Error al consultar el servicio:", e)
        productos = [{}]

    context = {
        "producto": productos,
        "user": ""
    }

    return render(request, "Paginas/Actualizar_stock.html", context)