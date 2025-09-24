-- CASO 1
SELECT TO_CHAR(SUBSTR(RUNEMPLEADO, 0, 8), '00G000G000')||'-'||SUBSTR(RUNEMPLEADO, -1, 1) "RUN EMPLEADO",
       NOMBREEMP||' '||PATERNOEMP||' '||MATERNOEMP "NOMBRE EMPLEADO",
       FECHA_ING "FECHA INGRESO",
       NVL(DIR_SUC, 'Trabaja en l�nea') SUCURSAL,
       TO_CHAR(SUELDOBASE, '$9G999G999') SUELDO,
       COUNT(ID_PEDIDO) "NRO. PEDIDOS",
       NVL(TO_CHAR(SUM(TOTAL), '$999G999G999'), '           $0') "TOTAL PEDIDOS"
FROM EMPLEADO em
LEFT JOIN SUCURSAL su
  ON (em.ID_SUC = su.ID_SUC)
FULL JOIN PEDIDO pe
  ON (em.NUMEMPLEADO = pe.NUMEMPLEADO)
WHERE EXTRACT(YEAR FROM SYSDATE)-1 = EXTRACT(YEAR FROM FEC_PEDIDO)
GROUP BY RUNEMPLEADO, NOMBREEMP, PATERNOEMP, MATERNOEMP, FECHA_ING, DIR_SUC, SUELDOBASE
HAVING COUNT(ID_PEDIDO) < (SELECT AVG(COUNT(ID_PEDIDO))
                             FROM PEDIDO
                            WHERE EXTRACT(YEAR FROM FEC_PEDIDO) = TO_CHAR(SYSDATE, 'yyyy') -1
                         GROUP BY NUMEMPLEADO)
ORDER BY PATERNOEMP;

-- CASO 2
INSERT INTO ASIGNACION_MES
SELECT TO_CHAR(FEC_PEDIDO, 'YYYY') ANNIO_PROCESO,
       em.NUMEMPLEADO NUMERO_EMPLEADO,
       COUNT(ID_PEDIDO) NRO_VENTAS_MES,
       ROUND(SUM(SUBTOTAL) * 0.002 + SUELDOBASE) ASIGNACION_MES,
       NOM_CATEG CATEGORIA_EMPLEADO
FROM EMPLEADO em
JOIN PEDIDO pe
  ON (em.NUMEMPLEADO = pe.NUMEMPLEADO)
JOIN CATEGORIA ca
  ON (em.ID_CATEG = ca.ID_CATEG)
WHERE TO_CHAR(FEC_PEDIDO, 'YYYY') IN (TO_CHAR(SYSDATE, 'YYYY') - 1, TO_CHAR(SYSDATE, 'YYYY') - 2)
GROUP BY TO_CHAR(FEC_PEDIDO, 'YYYY'), em.NUMEMPLEADO, NOM_CATEG, SUELDOBASE
HAVING COUNT(ID_PEDIDO) > 40
ORDER BY ANNIO_PROCESO, NUMERO_EMPLEADO;

-- CASO 2 OP. SET
SELECT to_char(sysdate, 'YYYY') -1 annio, E.numempleado,  
       COUNT(P.id_pedido) pedidos,
       round(E.sueldobase * (COUNT(P.id_pedido) * 0.002)) asi,
       C.nom_categ categoria
FROM empleado E JOIN pedido P
ON E.numempleado = P.numempleado
JOIN categoria C ON C.id_categ = E.id_categ
WHERE to_char(P.fec_pedido, 'yyyy') =  to_char(sysdate, 'YYYY') -1
GROUP BY E.numempleado, E.sueldobase,C.nom_categ
HAVING COUNT(P.id_pedido) > 40
UNION
SELECT to_char(sysdate, 'YYYY') -2, E.numempleado,  
       COUNT(P.id_pedido),
       round(E.sueldobase * (COUNT(P.id_pedido) * 0.002)),
       C.nom_categ categoria
FROM empleado E JOIN pedido P
ON E.numempleado = P.numempleado
JOIN categoria C ON C.id_categ = E.id_categ
WHERE to_char(P.fec_pedido, 'yyyy') =  to_char(sysdate, 'YYYY') -2
GROUP BY E.numempleado, E.sueldobase,C.nom_categ
HAVING COUNT(P.id_pedido) > 40
ORDER BY 1,2;

-- ACTUALIZAR TABLA EMPLEADO
UPDATE EMPLEADO
   SET ASIGNACION_BASE = asignacion_base + (SELECT SUM(asignacion_mes)
                                              FROM asignacion_mes asi
                                             WHERE asi.numero_empleado = E.numempleado
                                          GROUP BY numero_empleado)
WHERE E.numempleado IN (SELECT numero_empleado
                        FROM asignacion_mes);

-- REINICIAR TABLA
TRUNCATE TABLE ASIGNACION_MES;

-- COMPROBAR ASIGNACION
SELECT NUMEMPLEADO,
       ASIGNACION_BASE
FROM EMPLEADO;