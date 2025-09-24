--SET SERVEROUTPUT ON;

VAR km_valor NUMBER
VAR km_general NUMBER
VAR km_panam NUMBER
VAR km_descuento NUMBER
VAR lm_id_inf NUMBER
VAR lm_id_sup NUMBER

BEGIN
    :km_valor := 50;
    :km_general := 150;
    :km_panam := 650;
    :km_descuento := 100;
    
    SELECT MIN(id), MAX(id)
    INTO :lm_id_inf, :lm_id_sup
    FROM pasajero;
END;

DECLARE
    i NUMBER;
    fecha_ini DATE;
    fecha_fin DATE;
    porc_pasajes NUMBER;
    tipo tipo_pasajero.descripcion%TYPE;
    km_tipo NUMBER;
    cantidad_vuelos NUMBER;
    km_add_vuelo NUMBER;
    cantidad_panam NUMBER;
    km_panam NUMBER;
    km_descuento NUMBER;
    rut pasajero.rut%TYPE;
    km_pasajero pasajero.kilometros%TYPE;
    km_pasajero_final pasajero.kilometros%TYPE;
    monto_final NUMBER;
    venta_pasaje NUMBER;
    suma_porcentaje NUMBER;
    monto_actual NUMBER;
    monto_abono NUMBER;
    monto_descuento NUMBER;
BEGIN
    fecha_ini := '01/03/'||TO_CHAR(SYSDATE - 365,'yyyy');
    fecha_fin := '31/08/'||TO_CHAR(SYSDATE - 365,'yyyy');
    
    i := :lm_id_inf;
    
    WHILE i <=: lm_id_sup LOOP
        --DBMS_OUTPUT.PUT_LINE('------------------------');
        --DBMS_OUTPUT.PUT_LINE('id: '||i);
        
        SELECT NVL(SUM(precio), 0), COUNT(DISTINCT cod_vuelo)
        INTO venta_pasaje, cantidad_vuelos
        FROM pasajero
        JOIN vuelo_pasajero ON rut = rut_pasajero
        JOIN vuelo USING(cod_vuelo)
        WHERE id = i
        AND fecha_vuelo BETWEEN fecha_ini AND fecha_fin;
        
        SELECT porcentaje
        INTO porc_pasajes
        FROM porc_kilometros
        WHERE venta_pasaje BETWEEN valor_inferior AND valor_superior;
        
        --DBMS_OUTPUT.PUT_LINE(porc_pasajes-100||'%');
        
        SELECT UPPER(descripcion)
        INTO tipo
        FROM pasajero
        LEFT JOIN tipo_pasajero USING(cod_tipo)
        WHERE id = i;
        
        IF tipo IN ('STANDARD') THEN
            km_tipo := 150;
        ELSIF tipo IN ('SILVER') THEN
            km_tipo := 110;
        ELSIF tipo IN ('GOLD','PREMIUM') THEN
            km_tipo := 50;
        ELSE
            km_tipo := 0;
        END IF;
        
        --DBMS_OUTPUT.PUT_LINE('+'||km_tipo||'km');
        
        SELECT kilometros
        INTO km_add_vuelo
        FROM vuelos_kilometros
        WHERE cantidad_vuelos BETWEEN vuelos_inf AND vuelos_sup;
        
        --DBMS_OUTPUT.PUT_LINE('+'||km_add_vuelo||'km');
        
        SELECT COUNT(DISTINCT cod_vuelo)
        INTO cantidad_panam
        FROM pasajero
        JOIN vuelo_pasajero ON rut = rut_pasajero
        JOIN vuelo USING(cod_vuelo)
        JOIN avion USING(cod_avion)
        JOIN linea USING(cod_linea)
        WHERE id = i
        AND UPPER(nombre) = 'PANAM'
        AND fecha_vuelo BETWEEN fecha_ini AND fecha_fin;
        
        IF cantidad_panam >= 1 THEN
            km_panam := :km_panam;
        ELSE
            km_panam := 0;
        END IF;
        
        --DBMS_OUTPUT.PUT_LINE('+'||km_panam||'km');
        
        IF cantidad_vuelos = 0 THEN
            km_descuento := :km_descuento;
        ELSE
            km_descuento := 0;
        END IF;
        
        --DBMS_OUTPUT.PUT_LINE('-'||km_descuento||'km');
        --DBMS_OUTPUT.PUT_LINE('+'||:km_general||'km');
    
        SELECT rut, NVL(kilometros, 0)
        INTO rut, km_pasajero
        FROM pasajero
        WHERE id=i;
        
        km_pasajero_final := ROUND(km_pasajero * (porc_pasajes + 100) / 100) + km_tipo + km_add_vuelo + km_panam - km_descuento + :km_general;
        monto_final := km_pasajero_final * :km_valor;
        
        --DBMS_OUTPUT.PUT_LINE(km_pasajero||'km -> '||km_pasajero_final||'km');
        --DBMS_OUTPUT.PUT_LINE('$'||monto_final);
        
        suma_porcentaje := ROUND(km_pasajero * porc_pasajes / 100);
        
        INSERT INTO km_pasajeros
        VALUES(i, rut, km_pasajero, suma_porcentaje, km_tipo, km_add_vuelo, km_panam, km_descuento, km_pasajero_final);
        
        monto_actual := km_pasajero * :km_valor;
        monto_abono := (ROUND(km_pasajero * porc_pasajes / 100) + km_tipo + km_add_vuelo + km_panam + :km_general) * :km_valor;
        monto_descuento := km_descuento * :km_valor;
        
        INSERT INTO valores_km_pasajeros
        VALUES(i, rut, monto_actual, monto_abono, monto_descuento, monto_final);
        i := i + 10;
    END LOOP;
END;