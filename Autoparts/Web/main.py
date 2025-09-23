import pymysql
from app import app
from config import mysql
from flask import jsonify
from flask import flash, request  
from datetime import datetime
import requests

url = 'http://127.0.0.1:5000/'

@app.route('/get_producto')
def get():
    try:
        conn = mysql.connect()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        cursor.execute("SELECT id_producto, nombre FROM producto;")
        empRows = cursor.fetchall()
        respone = jsonify(empRows)
        respone.status_code = 200
        return respone
    except Exception as e:
        print(e)
    finally:
        cursor.close() 
        conn.close()  

@app.route('/add', methods=['POST'])
def add_function():
    try:
        _json = request.json
        _id = int(_json['id'])  # Convertir a entero
        _amount = int(_json['amount'])  # Convertir a entero

        conn = mysql.connect()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        # Verificar el stock actual
        cursor.execute("""SELECT s.stock_actual 
                          FROM stock s 
                          WHERE s.producto_id_producto = %s""", (_id,))
        stock_data = cursor.fetchone()
        
        if not stock_data:
            response = jsonify({'result': 'Product not found!'})
            response.status_code = 404
            return response
            
        current_stock = int(stock_data['stock_actual'])  # Asegurar que es entero
        
        # Actualizar el stock
        sqlQuery = """UPDATE stock 
                      SET stock_actual = stock_actual + %s 
                      WHERE producto_id_producto = %s"""
        bindData = (_amount, _id)
        cursor.execute(sqlQuery, bindData)
        conn.commit()
        
        response = jsonify({
            'result': 'Stock updated successfully!', 
            'operation': 'ADD', 
            'amount_added': _amount,
            'new_stock': current_stock + _amount
        })
        response.status_code = 200
        return response
        
    except ValueError as e:
        response = jsonify({'result': 'Invalid input! ID and amount must be numbers.'})
        response.status_code = 400
        return response
    except Exception as e:
        print(f"Error: {str(e)}")
        response = jsonify({'result': 'An error occurred!'})
        response.status_code = 500
        return response
    finally:
        cursor.close()
        conn.close()
       
@app.route('/remove', methods=['POST'])
def remove_function():
    try:
        _json = request.json
        _id = int(_json['id'])  # Convertir a entero
        _amount = int(_json['amount'])  # Convertir a entero

        conn = mysql.connect()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        # Verificar el stock actual
        cursor.execute("""SELECT s.stock_actual 
                          FROM stock s 
                          WHERE s.producto_id_producto = %s""", (_id,))
        stock_data = cursor.fetchone()
        
        if not stock_data:
            response = jsonify({'result': 'Product not found!'})
            response.status_code = 404
            return response
            
        current_stock = int(stock_data['stock_actual'])  # Asegurar que es entero
        
        if current_stock < _amount:
            response = jsonify({
                'result': 'Insufficient stock! Cannot remove that amount.', 
                'current_stock': current_stock,
                'attempted_to_remove': _amount
            })
            response.status_code = -200
            return response
        
        # Actualizar el stock
        sqlQuery = """UPDATE stock 
                      SET stock_actual = stock_actual - %s 
                      WHERE producto_id_producto = %s"""
        bindData = (_amount, _id)
        cursor.execute(sqlQuery, bindData)
        conn.commit()
        
        response = jsonify({
            'result': 'Stock updated successfully!', 
            'operation': 'REMOVE', 
            'amount_removed': _amount,
            'new_stock': current_stock - _amount
        })
        response.status_code = 200
        return response
        
    except ValueError as e:
        response = jsonify({'result': 'Invalid input! ID and amount must be numbers.'})
        response.status_code = 400
        return response
    except Exception as e:
        print(f"Error: {str(e)}")
        response = jsonify({'result': 'An error occurred!'})
        response.status_code = 500
        return response
    finally:
        cursor.close()
        conn.close()

@app.route('/control', methods=['GET','POST'])
def control_function():
    try:
        _json = request.json
        _id = int(_json['id'])  # Convertir a entero

        conn = mysql.connect()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        # Verificar el stock actual
        cursor.execute("""SELECT s.stock_actual, s.stock_minimo
                          FROM stock s 
                          WHERE s.producto_id_producto = %s""", (_id,))
        stock_data = cursor.fetchone()
        
        if not stock_data:
            response = jsonify({'result': 'Product not found!'})
            response.status_code = 404
            return response
            
        current_stock = int(stock_data['stock_actual'])
        min_stock = int(stock_data['stock_minimo'])
        
        if current_stock <= min_stock:
            response = jsonify({
                'result': 'Low stock!', 
                'current_stock': current_stock,
                'min_stock': min_stock
            })
            response.status_code = 400
            return response
        else:
            response = jsonify({
                'result': 'Stock fine!', 
                'current_stock': current_stock,
                'min_stock': min_stock
            })
            response.status_code = 400
            return response
    
    except ValueError as e:
        response = jsonify({'result': 'Invalid input! ID and amount must be numbers.'})
        response.status_code = 400
        return response
    except Exception as e:
        print(f"Error: {str(e)}")
        response = jsonify({'result': 'An error occurred!'})
        response.status_code = 500
        return response
    finally:
        cursor.close()
        conn.close()
        
@app.route('/bodega', methods=['GET'])
def bodega():
    try:
        conn = mysql.connect()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        sqlQuery = """
            SELECT p.nombre, s.stock_actual, s.stock_minimo, p.precio, p.id_producto
            FROM producto p
            JOIN stock s ON p.id_producto = s.producto_id_producto;
        """

        cursor.execute(sqlQuery)
        empRows = cursor.fetchall()
        respone = jsonify(empRows)
        respone.status_code = 200
        return respone
    except Exception as e:
        print(f"Error en /consulta: {e}")
        return jsonify({'result': 'An error occurred!'}), 400
    finally:
        cursor.close() 
        conn.close()  

@app.route('/consulta', methods=['GET','POST'])
def consulta_function():
    conn = None
    cursor = None
    try:
        if request.method == 'POST':
            data = request.get_json(force=True)
            _id = int(data['id'])
        else:
            _id = int(request.args.get('id'))

        conn = mysql.connect()
        cursor = conn.cursor(pymysql.cursors.DictCursor)

        sqlQuery = """
            SELECT p.nombre, s.stock_actual, s.stock_minimo, p.precio
            FROM producto p
            JOIN stock s ON p.id_producto = s.producto_id_producto
            WHERE p.id_producto = %s;
        """
        cursor.execute(sqlQuery, (_id,))
        product_data = cursor.fetchone()

        if not product_data:
            return jsonify({'result': 'Product not found!'}), 404

        return jsonify({
            'nombre': product_data['nombre'],
            'stock_actual': product_data['stock_actual'],
            'stock_minimo': product_data['stock_minimo'],
            'precio': product_data['precio']

        }), 200

    except ValueError:
        return jsonify({'result': 'Invalid input! ID must be a number.'}), 400

    except Exception as e:
        print(f"Error en /consulta: {e}")
        return jsonify({'result': 'An error occurred!'}), 500

    finally:
        if cursor:
            cursor.close()
        if conn:
            conn.close()

@app.route('/add_cart', methods=['POST'])
def add_cart_function():
    try:
        _json = request.json
        _id_cart = int(_json['id_carrito'])
        _id_cliente = int(_json['id_cliente'])
        _id_product = int(_json['id_producto'])
        _amount = int(_json['amount'])

        conn = mysql.connect()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        # Verificar productos en el carrito
        cursor.execute("""SELECT producto_id_producto
                          FROM carrito 
                          WHERE id_carrito = %s """, (_id_cart,))
        cart_data = cursor.fetchone()
        
        if cart_data:
            if cart_data['producto_id_producto'] == _id_product:
                cursor.execute("""SELECT key_element
                                  FROM carrito 
                                  WHERE producto_id_producto = %s
                                  AND id_carrito = %s""", (_id_product, _id_cart,))
                key_data = cursor.fetchone()

                sqlQuery = """UPDATE carrito 
                              SET cantidad = cantidad + %s 
                              WHERE key_element = %s"""
                bindData = (_amount, key_data['key_element'])
                cursor.execute(sqlQuery, bindData)
                conn.commit()
                response = jsonify({
                    'result': f'Added {_amount} elements succesfully',
                    'id_producto': _id_product,
                    'id_carrito': _id_cart
                })
                response.status_code = 200
                return response
            
        sqlQuery = """INSERT INTO carrito (id_carrito, cantidad, producto_id_producto, cliente_id_cliente ) 
                      VALUES (
                      %s,
                      %s, 
                      %s, 
                      %s)"""
        bindData = (_id_cart, _amount, _id_product,_id_cliente)
        cursor.execute(sqlQuery, bindData)
        conn.commit()
        
        response = jsonify({
            'result': 'Cart element added successfully!',
            'id_carrito': _id_cart,
            'id_producto':_id_product,
            'cantidad': _amount,
            'cliente_id': _id_cliente
        })
        response.status_code = 200
        return response
        
    except ValueError as e:
        response = jsonify({'result': 'Invalid input! ID and amount must be numbers.'})
        response.status_code = 400
        return response
    except Exception as e:
        print(f"Error: {str(e)}")
        response = jsonify({'result': 'An error occurred!'})
        response.status_code = 500
        return response
    finally:
        cursor.close()
        conn.close()

@app.route('/get_cart', methods=['GET','POST'])
def get_cart_function():
    try:
        if request.method == 'POST':
            data = request.get_json(force=True)
            _id = int(data['id'])
        else:
            _id = int(request.args.get('id'))

        conn = mysql.connect()
        cursor = conn.cursor(pymysql.cursors.DictCursor)
        
        sqlQuery ="""SELECT p.nombre, c.cantidad,c.id_carrito,c.cliente_id_cliente, p.precio
                    FROM carrito c 
                    JOIN producto p 
                    ON c.producto_id_producto = p.id_producto
                    WHERE c.id_carrito= %s;"""
        bindData = (_id)
        cursor.execute(sqlQuery, bindData)
        cart_data = cursor.fetchall()
        
        if not cart_data:
            response = jsonify({'result': 'Cart not found!'})
            response.status_code = 404
            return response
            
        response = jsonify(cart_data)
        response.status_code = 200
        return response
    
    except ValueError as e:
        response = jsonify({'result': 'Invalid input! ID and amount must be numbers.'})
        response.status_code = 400
        return response
    except Exception as e:
        print(f"Error: {str(e)}")
        response = jsonify({'result': 'An error occurred!'})
        response.status_code = 400
        return response
    finally:
        cursor.close()
        conn.close()

@app.route('/crear_pedido', methods=['POST'])
def crear_pedido():
    try:
        _json = request.json
        _direccion = _json['direccion_pedido']
        _nombre = _json['nombre']
        _rut = _json['rut']
        _dv = _json['dv']
        _doc_id = _json['id_doc']
        _doc_type = _json['type_doc']

        conn = mysql.connect()
        cursor = conn.cursor()

        if _doc_type == "FACTURA":
            cursor.execute("""
                INSERT INTO pedido 
                (direccion_pedido, nombre, rut, dv, factura_nro_factura)
                VALUES (%s, %s, %s, %s, %s)
                """, (_direccion, _nombre, _rut, _dv, _doc_id))
        elif _doc_type == 'BOLETA':
            cursor.execute("""
                INSERT INTO pedido 
                (direccion_pedido, nombre, rut, dv, boleta_id_boleta)
                VALUES (%s, %s, %s, %s, %s)
                """, (_direccion, _nombre, _rut, _dv, _doc_id))

        conn.commit()

        return jsonify({"mensaje": "Pedido creado exitosamente"}), 200

    except Exception as e:
        print(e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()


@app.route('/crear_documento', methods=['POST'])
def crear_documento():
    try:
        _json = request.json
        _id = _json['nro_documento']
        _type = _json['tipo']
        _carrito = _json['id_carrito']
        _id_comprador = _json['comprador']
        

        conn = mysql.connect()
        cursor = conn.cursor()

        if _type == 'FACTURA':
            sqlQuery ="""SELECT p.precio, c.cantidad, s.stock_actual, p.id_producto
                    FROM carrito c 
                    JOIN producto p 
                    ON c.producto_id_producto = p.id_producto
                    JOIN stock s
                    ON c.producto_id_producto = s.producto_id_producto
                    WHERE c.id_carrito= %s;"""
            bindData = (_carrito)
            cursor.execute(sqlQuery, bindData)
            cart_data = cursor.fetchall()

            valor_cart = 0
            cantidad_cart = 0
            for cart_element in cart_data:
                valor_element = cart_element[0] * cart_element[1]
                cantidad_cart += 1
                valor_cart += valor_element

                ws = url+'remove'
                payload = {
                            'id': str(cart_element[3]),
                            'amount': str(cart_element[1])
                        }

                response = requests.post(ws, json=payload)
                if response.status_code == 200:
                    print('Success:', response.json())
                else:
                    print(f"Request failed with status code {response.status_code}")

            sqlQuery ="""SELECT id_descuento
                    FROM descuento
                    WHERE cantidad_minima <= %s
                    ORDER BY cantidad_minima DESC
                    LIMIT 1;"""
            bindData = (cantidad_cart,)
            cursor.execute(sqlQuery, bindData)
            resultado = cursor.fetchone()
            descuento = resultado[0]

            fecha = datetime.now().strftime("%Y-%m-%d")

            cursor.execute("""INSERT INTO factura 
                             (nro_factura, cantidad, subtotal, fecha, descuento_id_descuento, mayorista_id_empresa)
                              VALUES (%s, %s, %s, %s, %s, %s)""", (_id, cantidad_cart, valor_cart, fecha, descuento, _id_comprador))
        elif _type == 'BOLETA':
            sqlQuery ="""SELECT p.precio, c.cantidad, s.stock_actual, p.id_producto
                    FROM carrito c 
                    JOIN producto p 
                    ON c.producto_id_producto = p.id_producto
                    JOIN stock s
                    ON c.producto_id_producto = s.producto_id_producto
                    WHERE c.id_carrito= %s;"""
            bindData = (_carrito)
            cursor.execute(sqlQuery, bindData)
            cart_data = cursor.fetchall()

            valor_cart = 0
            for cart_element in cart_data:
                valor_element = cart_element[0] * cart_element[1]
                valor_cart += valor_element

                ws = url+'remove'
                payload = {
                            'id': str(cart_element[3]),
                            'amount': str(cart_element[1])
                        }

                response = requests.post(ws, json=payload)
                if response.status_code == 200:
                    print('Success:', response.json())
                else:
                    print(f"Request failed with status code {response.status_code}")

            fecha = datetime.now().strftime("%Y-%m-%d")

            cursor.execute("""INSERT INTO boleta 
                             (id_boleta, subtotal, fecha, cliente_id_cliente)
                              VALUES (%s, %s, %s, %s)""", (_id, valor_cart, fecha, _id_comprador))

        conn.commit()
        return jsonify({"mensaje": f"{_type} creada exitosamente"}), 200

    except Exception as e:
        print(e)
        return jsonify({"error": str(e)}), 500

    finally:
        cursor.close()
        conn.close()

@app.errorhandler(404)
def showMessage(error=None):
    message = {
        'status': 404,
        'message': 'Record not found: ' + request.url,
    }
    respone = jsonify(message)
    respone.status_code = 404
    return respone

if __name__ == "__main__":
    app.run()
