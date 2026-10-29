-- =====================================================================
-- EXPLORACIÓN, LIMPIEZA Y NORMALIZACIÓN DE DATOS (EJERCICIO 2)
-- Base de datos: PostgreSQL en Neon (Tracking de Opinión Pública)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. CHEQUEO DE CLAVES Y DISTRIBUCIÓN DEMOGRÁFICA
-- ---------------------------------------------------------------------

-- 1.1 Verificar que no existan ID duplicados en encuestados (debe dar 0 filas)
SELECT id, COUNT(*) AS cantidad
FROM encuestados
GROUP BY id
HAVING COUNT(*) > 1;

-- 1.2 Distribución de encuestas completas vs incompletas
-- Nota: Las 78 incompletas no tienen ponderador y se descartarán por regla de negocio
SELECT completa, COUNT(*) AS total_casos
FROM encuestados
GROUP BY completa;

-- 1.3 Distribución por sexo (en encuestas completas)
SELECT 
    sexo, 
    COUNT(*) AS cantidad, 
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS porcentaje
FROM encuestados
WHERE completa = TRUE
GROUP BY sexo;

-- 1.4 Diagnóstico de edad: mínimo, máximo y anomalía del código 999
-- Nota: 999 es el código estándar de Ns/Nc. Usamos NULLIF para calcular el promedio real sin distorsión.
SELECT 
    COUNT(*) AS total_encuestados,
    MIN(edad) AS edad_minima,
    MAX(edad) AS edad_maxima,
    COUNT(CASE WHEN edad = 999 THEN 1 END) AS casos_codigo_999,
    ROUND(AVG(edad), 2) AS edad_promedio_cruda,
    ROUND(AVG(NULLIF(edad, 999)), 2) AS edad_promedio_limpia
FROM encuestados
WHERE completa = TRUE;


-- ---------------------------------------------------------------------
-- 2. DEDUPLICACIÓN DE RESPUESTAS (REGLA DE NEGOCIO 2)
-- ---------------------------------------------------------------------

-- 2.1 Cantidad de combinaciones (encuestado_id, pregunta_id) con más de una respuesta
SELECT encuestado_id, pregunta_id, COUNT(*) AS cantidad_respuestas
FROM respuestas
GROUP BY encuestado_id, pregunta_id
HAVING COUNT(*) > 1;

-- 2.2 Ver casos concretos de duplicados ordenados cronológicamente
-- Se observa que algunos encuestados cambiaron su respuesta con segundos/minutos de diferencia
SELECT encuestado_id, pregunta_id, valor, registrada_en
FROM respuestas
WHERE encuestado_id IN (
    SELECT encuestado_id 
    FROM respuestas 
    GROUP BY encuestado_id, pregunta_id 
    HAVING COUNT(*) > 1
)
ORDER BY encuestado_id, pregunta_id, registrada_en DESC;


-- ---------------------------------------------------------------------
-- 3. NORMALIZACIÓN DE PROVINCIAS Y REGIONES
-- ---------------------------------------------------------------------

-- 3.1 Normalizar texto: TRIM quita espacios, LOWER unifica mayúsculas y 'caba' se asigna a CABA
-- Verificamos que el 100% de los encuestados machee con la tabla oficial de provincias y su región
SELECT DISTINCT 
    e.provincia AS provincia_original,
    p.nombre AS provincia_oficial,
    p.region
FROM encuestados e
LEFT JOIN provincias p 
    ON LOWER(TRIM(e.provincia)) = LOWER(p.nombre)
    OR (LOWER(TRIM(e.provincia)) = 'caba' AND p.nombre = 'Ciudad Autónoma de Buenos Aires')
ORDER BY p.region, p.nombre;

-- 2da verificación
SELECT e.provincia, COUNT(*) AS casos_sin_region
FROM encuestados e
LEFT JOIN provincias p 
    ON LOWER(TRIM(e.provincia)) = LOWER(p.nombre)
    OR (LOWER(TRIM(e.provincia)) = 'caba' AND p.nombre = 'Ciudad Autónoma de Buenos Aires')
WHERE p.region IS NULL
GROUP BY e.provincia;
-- ---------------------------------------------------------------------
-- 4. CAPA DE DATOS LIMPIA: VISTAS (VIEWS) REUTILIZABLES
-- ---------------------------------------------------------------------

-- Vista A: Encuestados limpios
-- Filtra completas, vincula provincia y región normalizadas, y genera edad_limpia (excluyendo 999)
CREATE OR REPLACE VIEW v_encuestados_limpios AS
SELECT 
    e.id AS encuestado_id,
    e.encuesta_id,
    e.sexo,
    e.edad,
    NULLIF(e.edad, 999) AS edad_limpia,
    p.nombre AS provincia,
    p.region,
    e.ponderador
FROM encuestados e
JOIN provincias p 
    ON LOWER(TRIM(e.provincia)) = LOWER(p.nombre)
    OR (LOWER(TRIM(e.provincia)) = 'caba' AND p.nombre = 'Ciudad Autónoma de Buenos Aires')
WHERE e.completa = TRUE;

-- Vista B: Respuestas deduplicadas
-- Aplica ROW_NUMBER() por encuestado y pregunta ordenando descendente por fecha para tomar solo la última
CREATE OR REPLACE VIEW v_respuestas_dedup AS
WITH ranking_respuestas AS (
    SELECT 
        r.encuestado_id,
        r.pregunta_id,
        r.valor,
        r.registrada_en,
        ROW_NUMBER() OVER (
            PARTITION BY r.encuestado_id, r.pregunta_id 
            ORDER BY r.registrada_en DESC
        ) AS orden_reciente
    FROM respuestas r
)
SELECT encuestado_id, pregunta_id, valor, registrada_en
FROM ranking_respuestas
WHERE orden_reciente = 1;

SELECT * FROM v_encuestados_limpios LIMIT 10;
SELECT * FROM v_respuestas_dedup LIMIT 10;


--Query 1:
SELECT 
    enc.id AS ola_id,
    enc.nombre AS ola,
    COUNT(*) AS total_encuestados,
    ROUND(AVG(el.edad_limpia), 2) AS edad_promedio
FROM v_encuestados_limpios el
JOIN encuestas enc ON enc.id = el.encuesta_id
GROUP BY enc.id, enc.nombre
ORDER BY enc.id;

--query 2:
SELECT 
    el.region,
    COUNT(*) AS total_casos,
    ROUND(100.0 * COUNT(CASE WHEN rd.valor = 1 THEN 1 END) / COUNT(*), 2) AS pct_aprobacion,
    ROUND(100.0 * COUNT(CASE WHEN rd.valor = 2 THEN 1 END) / COUNT(*), 2) AS pct_desaprobacion,
    ROUND(100.0 * COUNT(CASE WHEN rd.valor = 99 THEN 1 END) / COUNT(*), 2) AS pct_ns_nc
FROM v_encuestados_limpios el
JOIN preguntas pr ON pr.encuesta_id = el.encuesta_id AND pr.codigo = 'APROB'
JOIN v_respuestas_dedup rd ON rd.encuestado_id = el.encuestado_id AND rd.pregunta_id = pr.id
WHERE el.encuesta_id = (SELECT MAX(id) FROM encuestas)
GROUP BY el.region
ORDER BY pct_aprobacion DESC;

--query 3:
SELECT 
    enc.id AS ola_id,
    enc.nombre AS ola,
    op.etiqueta AS opcion,
    ROUND(SUM(el.ponderador), 2) AS peso_total_opcion,
    ROUND(100.0 * SUM(el.ponderador) / SUM(SUM(el.ponderador)) OVER (PARTITION BY enc.id), 2) AS pct_ponderado
FROM v_encuestados_limpios el
JOIN encuestas enc ON enc.id = el.encuesta_id
JOIN preguntas pr ON pr.encuesta_id = enc.id AND pr.codigo = 'VOTO'
JOIN v_respuestas_dedup rd ON rd.encuestado_id = el.encuestado_id AND rd.pregunta_id = pr.id
JOIN opciones op ON op.pregunta_id = pr.id AND op.valor = rd.valor
GROUP BY enc.id, enc.nombre, op.etiqueta
ORDER BY enc.id, pct_ponderado DESC;

--query 4:
WITH intencion_voto AS (
    -- Acá va la Consulta 3 tal cual la pensaste:
    SELECT 
        enc.id AS ola_id,
        enc.nombre AS ola,
        op.etiqueta AS espacio_politico,
        ROUND(100.0 * SUM(el.ponderador) / SUM(SUM(el.ponderador)) OVER (PARTITION BY enc.id), 2) AS pct_ponderado
    FROM v_encuestados_limpios el
    JOIN encuestas enc ON enc.id = el.encuesta_id
    JOIN preguntas pr ON pr.encuesta_id = enc.id AND pr.codigo = 'VOTO'
    JOIN v_respuestas_dedup rd ON rd.encuestado_id = el.encuestado_id AND rd.pregunta_id = pr.id
    JOIN opciones op ON op.pregunta_id = pr.id AND op.valor = rd.valor
    GROUP BY enc.id, enc.nombre, op.etiqueta
)
SELECT 
    ola,
    espacio_politico,
    pct_ponderado,
    ROUND(pct_ponderado - LAG(pct_ponderado) OVER (PARTITION BY espacio_politico ORDER BY ola_id), 2) AS var_puntos_ola_anterior,
    RANK() OVER (PARTITION BY ola_id ORDER BY pct_ponderado DESC) AS ranking_ola
FROM intencion_voto
WHERE espacio_politico NOT IN ('Ns/Nc', 'En blanco / Ninguno')
ORDER BY ola_id, ranking_ola;