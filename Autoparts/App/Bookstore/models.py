from django.db import models

class Producto(models.Model):
    id_producto = models.IntegerField(primary_key=True)
    nombre = models.CharField(max_length=50)
    descripcion = models.CharField(max_length=50)
    precio = models.IntegerField()
    stock_producto_id_producto = models.IntegerField()
    categoria_id_categoria = models.IntegerField(null=True, blank=True)

    class Meta:
        managed = False  # porque ya existe en la base
        db_table = 'producto'


class Stock(models.Model):
    producto_id_producto = models.IntegerField()
    stock_actual = models.IntegerField()
    stock_minimo = models.IntegerField()
    sucursal_id_sucursal = models.IntegerField(null=True)

    class Meta:
        managed = False
        db_table = 'stock'
