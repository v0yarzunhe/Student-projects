VARIABLE b_fecha VARCHAR2(6);
EXEC :b_fecha := '202106';

VARIABLE b_totalasilimite NUMBER;
EXEC :b_totalasilimite := 410000;

DECLARE
    v_msg VARCHAR2(255);
    v_msgusr VARCHAR2(255);
   
    v_comuna comuna.nom_comuna%TYPE;
    v_codemp NUMBER(2);
    v_pcteva NUMBER(4,2) := 0;
    v_pcttipoc NUMBER(8) := 0;
    v_asigmov NUMBER(8) := 0;
    v_asigeva NUMBER(8) := 0;
    v_asigtipoc NUMBER(8) := 0;
    v_asigprof NUMBER(8) := 0;
    v_asignaciones_profesional NUMBER(8) := 0;
    
    v_tot_asesorias NUMBER(8) := 0;
    v_tot_honorarios NUMBER(8) := 0;
    v_tot_asigmov NUMBER(8) := 0;
    v_tot_asigeva NUMBER(8) := 0;
    v_tot_asigprof NUMBER(8) := 0;
    v_tot_asigtipoc NUMBER(8) := 0;
    v_tot_asigprofesion NUMBER(8) := 0;
    
    CURSOR c_profesional (p_profesion VARCHAR2) IS
        SELECT numrun_prof RUN, p.cod_tpcontrato, p.cod_comuna, p.puntaje, p.sueldo, 
            P.nombre || ' ' || P.appaterno nombre, 
            pr.nombre_profesion, 
            SUM(A.honorario) honorarios, COUNT(*) asesorias
        FROM profesional P 
            JOIN profesion pr USING(cod_profesion)
            JOIN asesoria A USING(numrun_prof)
        WHERE TO_CHAR(A.inicio_asesoria, 'YYYYMM') = :b_fecha
        AND pr.nombre_profesion = p_profesion
        GROUP BY numrun_prof, P.nombre, P.appaterno, p.cod_comuna, p.puntaje, p.sueldo, p.cod_tpcontrato, pr.nombre_profesion
        ORDER BY pr.nombre_profesion, p.appaterno, p.nombre;
        
    
    CURSOR c_profesion IS 
        SELECT nombre_profesion, asignacion
        FROM profesion
        ORDER BY nombre_profesion;
    
    TYPE t_descuentos IS VARRAY(6) OF NUMBER;
    v_desctos t_descuentos := t_descuentos(0.02, 0.04, 0.05, 0.07, 0.09, 25000);
BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE errores_p';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE detalle_asignacion_mes';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE resumen_mes_profesion';
    
    EXECUTE IMMEDIATE 'DROP SEQUENCE sq_error';
    EXECUTE IMMEDIATE 'CREATE SEQUENCE sq_error';
    
    FOR r_profesion IN c_profesion LOOP
        v_tot_asesorias := 0;
        v_tot_honorarios := 0;
        v_tot_asigmov := 0;
        v_tot_asigeva := 0;
        v_tot_asigtipoc := 0;
        v_tot_asigprof := 0;
        v_tot_asigprofesion := 0;
        
        FOR r_profesional IN c_profesional (r_profesion.nombre_profesion) LOOP
            BEGIN
                SELECT nom_comuna, codemp_comuna
                  INTO v_comuna, v_codemp
                  FROM comuna
                 WHERE cod_comuna = r_profesional.cod_comuna;
                
                IF v_comuna != 'Providencia' THEN
                    v_asigmov :=
                        CASE v_codemp
                            WHEN 10 THEN ROUND(r_profesional.honorarios * v_desctos(1))
                            WHEN 20 THEN ROUND(r_profesional.honorarios * v_desctos(2))
                            WHEN 30 THEN ROUND(r_profesional.honorarios * v_desctos(3))
                            WHEN 40 THEN ROUND(r_profesional.honorarios * v_desctos(4))
                            ELSE ROUND(r_profesional.honorarios * v_desctos(5))
                        END;
                END IF;
                
            EXCEPTION
                WHEN no_data_found THEN
                    v_asigmov := v_desctos(6);
            END;
            --dbms_output.put_line(v_asigmov||' '||v_codemp);
        
            BEGIN
                SELECT porcentaje / 100
                INTO v_pcteva
                FROM evaluacion
                WHERE r_profesional.puntaje BETWEEN eva_punt_min AND eva_punt_max;        
            EXCEPTION    
                WHEN no_data_found THEN
                    v_msg := SQLERRM;
                    v_pcteva := 0; 
                    v_msgusr := 'No se encontró porcentaje de evaluación para el run Nro. ' || TO_CHAR(r_profesional.run,'09G999G999');
                    INSERT INTO errores_p
                        VALUES (sq_error.NEXTVAL, v_msg, v_msgusr);
                WHEN too_many_rows THEN
                    v_msg := SQLERRM;
                    v_pcteva := 0; 
                    v_msgusr := 'Se encontró más de un porcentaje de evaluación para el run Nro. ' || TO_CHAR(r_profesional.run,'09G999G999');
                    INSERT INTO errores_p
                        VALUES (sq_error.NEXTVAL, v_msg, v_msgusr);
            END;
            
            v_asigeva := ROUND(r_profesional.honorarios * v_pcteva);
            --dbms_output.put_line(v_asigeva);
        
            SELECT incentivo
            INTO v_pcttipoc  
            FROM tipo_contrato
            WHERE cod_tpcontrato = r_profesional.cod_tpcontrato;
            
            v_asigtipoc := ROUND(r_profesional.honorarios * v_pcttipoc / 100);
            
            --dbms_output.put_line(v_pcttipoc);
            
            v_asigprof := ROUND(r_profesional.sueldo * r_profesion.asignacion / 100);
            --dbms_output.put_line(v_asigprof);
            
            v_asignaciones_profesional  :=  v_asigmov + v_asigeva + v_asigtipoc + v_asigprof;
            
            IF v_asignaciones_profesional > :b_totalasilimite THEN
                v_asignaciones_profesional := :b_totalasilimite; 
            END IF;
            --dbms_output.put_line(v_asignaciones_profesional);
            
            INSERT INTO detalle_asignacion_mes 
                VALUES(
                    SUBSTR(:b_fecha, -2), SUBSTR(:b_fecha, 1, 4), 
                    r_profesional.run, r_profesional.nombre, r_profesional.nombre_profesion, r_profesional.asesorias, r_profesional.honorarios, 
                    v_asigmov, v_asigeva, v_asigtipoc, v_asigprof, v_asignaciones_profesional
                );
            
            v_tot_asesorias := v_tot_asesorias + r_profesional.asesorias;
            v_tot_honorarios := v_tot_honorarios + r_profesional.honorarios;
            v_tot_asigmov := v_tot_asigmov + v_asigmov;
            v_tot_asigeva := v_tot_asigeva + v_asigeva;
            v_tot_asigtipoc := v_tot_asigtipoc + v_asigtipoc;
            v_tot_asigprof := v_tot_asigprof + v_asigprof;
            v_tot_asigprofesion := v_tot_asigprofesion + v_asignaciones_profesional;
        END LOOP;
        
        INSERT INTO resumen_mes_profesion
            VALUES(
                :b_fecha, r_profesion.nombre_profesion, 
                v_tot_asesorias,v_tot_honorarios,
                v_tot_asigmov, v_tot_asigeva, v_tot_asigtipoc, v_tot_asigprof, v_tot_asigprofesion
            );
    END LOOP;
    
    COMMIT;
END;
/