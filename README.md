# Prueba Técnica – Data & Desarrollo MOVE

**Postulante:** Martina Sotelo  
**Posición:** Data & Desarrollo  
**Fecha de entrega:** Octubre 2026  

---

## 📌 Resumen Ejecutivo

Este repositorio contiene la resolución integral de la prueba técnica solicitada por **MOVE**, estructurada en un único Jupyter Notebook ejecutable de punta a punta (`prueba_tecnica_move.ipynb`), complementado con scripts de soporte y documentación analítica.

El proyecto aborda dos desafíos centrales de ciencia y análisis de datos:
1. **Ejercicio 1: Modelo de Predicción Electoral (Machine Learning):** Anticipación del ganador presidencial a nivel condado en Estados Unidos (`winner`: 1 Republicano, 0 Demócrata) a octubre de 2020 a partir de indicadores sociodemográficos del censo.
2. **Ejercicio 2: SQL sobre Base de Encuestas (PostgreSQL):** Modelado relacional, deduplicación temporal de respuestas y análisis de tracking de opinión pública mediante consultas SQL avanzadas ejecutadas directamente en la base de datos.
3. **Sección Final: Uso Transparente de IA:** Bitácora metodológica detallando las herramientas utilizadas, las decisiones propias de negocio y los momentos de corrección técnica.

---

## 📂 Estructura del Repositorio

```text
├── archive/
│   ├── county_census_and_election_result.csv   # Dataset panel con métricas censales y electorales
│   └── meta_data.csv                           # Diccionario de datos del American Community Survey
├── encuestas.sql                               # Script SQL provisto con la base de tracking de opinión
├── querys.sql                                  # Consultas SQL estructuradas y vistas de exploración
├── prueba_tecnica_move.ipynb                   # Notebook principal con la entrega integral
├── .gitignore                                  # Control de exclusiones (entornos y archivo .env)
└── README.md                                   # Documentación ejecutiva del proyecto
```

---

## 🔬 Ejercicio 1: Modelo de Predicción Electoral

### 1. Enfoque Metodológico y Rigor Técnico
- **Simulación temporal (Octubre 2020):** Para recrear la situación del cliente antes de la elección de 2020, se aplicó una partición temporal estricta:
  - **Entrenamiento ($Train$):** Comicios presidenciales históricos de **2008, 2012 y 2016** (1.236 observaciones $\times$ 35 variables censales).
  - **Evaluación ($Test$ fuera de muestra):** Elección presidencial de **2020** (430 observaciones).
- **Control estricto de *Data Leakage*:** Se descartaron todas las columnas de conteo directo de votos (`votes_dem`, `democrat`, `republican`, etc.) para asegurar que el modelo prediga exclusivamente a partir de clivajes sociodemográficos.
- **Auditoría de cobertura:** Se documentó que el dataset se basa en el programa *ACS 1-Year Estimates* de la Oficina del Censo de EE.UU. (jurisdicciones de $\ge 65.000$ habitantes), reconociendo la omisión de condados rurales como una limitación explícita del modelo.

### 2. Estrategias y Modelos Evaluados
1. **Línea de Base sin Machine Learning (Inercia Electoral 2016):**
   - Regla que asigna para 2020 el ganador del condado en 2016.
   - Refleja la alta rigidez partidaria de EE.UU. (**93.3% de exactitud global**).
2. **Modelo 1: Árbol de Decisión (`DecisionTreeClassifier`):**
   - Optimización de hiperparámetros mediante **Validación Cruzada de 5 pliegues (5-Fold CV)** en Train, detectando `max_depth=4` como el punto óptimo para evitar subajuste y sobreajuste.
3. **Modelo 2: Random Forest (`RandomForestClassifier`):**
   - Ensamble de 150 árboles que reduce la varianza y captura interacciones no lineales entre clivajes.

### 3. Resultados Comparativos (Evaluación en Test 2020)

| Estrategia / Modelo | Accuracy | Precision | Recall | F1-Score | ROC-AUC |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Línea de Base (Inercia 2016)** | 0.933 | 0.881 | 0.995 | 0.935 | 0.934 |
| **Árbol de Decisión (max_depth=4)** | 0.800 | 0.873 | 0.689 | 0.770 | 0.854 |
| **Random Forest (150 árboles)** | **0.872** | **0.928** | **0.799** | **0.859** | **0.940** |

### 4. Recomendaciones para el Cliente
- **Modelo recomendado:** **Random Forest**. Si bien la inercia electoral alcanza un 93.3% de acierto, es una regla determinística ciega que no explica causales. El Random Forest alcanza un **ROC-AUC sobresaliente del 94.0%** y ofrece probabilidades continuas para detectar los condados pendulares (*Swing Counties*, con propensión entre 40% y 60%).
- **Clivajes determinantes:** El factor más explicativo es el estado civil (`% Solteros nunca casados`, que favorece fuertemente al partido Demócrata), seguido por la composición familiar tradicional (`% Casados`, bastión Republicano), la diversidad étnica/migratoria y el nivel educativo formal (títulos de posgrado).
- **Perspectiva institucional futura:** Se advierte al cliente sobre la regla de *"Winner-Take-All"* del Colegio Electoral a nivel estatal, planteando como siguiente paso agregar las predicciones a nivel Estado para proyectar los 270 electores necesarios.

---

## 🗄️ Ejercicio 2: SQL sobre Base de Encuestas

### 1. Modelo Entidad-Relación y Arquitectura
El tracking de opinión pública se estructura en 6 tablas relacionales:

```text
┌──────────────┐       1:N       ┌────────────────┐       1:N       ┌──────────────┐
│  encuestas   ├────────────────>│  encuestados   ├────────────────>│  respuestas  │
└──────┬───────┘                 └───────▲────────┘                 └──────▲───────┘
       │ 1:N                             │ 1:N (por texto)                 │ 1:N
       ▼                                 │                                 │
┌──────────────┐                 ┌───────┴────────┐                        │
│  preguntas   ├─────────────────┼────────────────┼────────────────────────┘
└──────┬───────┘                 │   provincias   │
       │ 1:N                     └────────────────┘
       ▼
┌──────────────┐
│   opciones   │
└──────────────┘
```

### 2. Reglas de Negocio y Calidad de Datos
- **Filtro de encuestas completas:** Se analizan exclusivamente registros con `completa = TRUE`.
- **Deduplicación temporal de respuestas:** Implementada con la función de ventana `ROW_NUMBER() OVER (PARTITION BY encuestado_id, pregunta_id ORDER BY registrada_en DESC) = 1` para priorizar la última manifestación del votante.
- **Tratamiento de `edad = 999`:** Para no reducir la muestra ni perder encuestados con ponderador válido, se aisló el código de Ns/Nc mediante `NULLIF(edad, 999)` únicamente al calcular la media de edad.
- **Normalización geográfica:** Homogeneización de nombres de provincias y asignación a regiones oficiales con funciones de texto (`LOWER`, `TRIM` y tratamiento de CABA).

### 3. Consultas Resueltas
1. **Consulta 1:** Total de encuestados con encuesta completa y edad promedio por ola.
2. **Consulta 2:** Porcentaje de aprobación, desaprobación y Ns/Nc de la gestión por región en la última ola (sin ponderar, mediante agregaciones condicionales `CASE WHEN`).
3. **Consulta 3:** Intención de voto ponderada de cada ola (% por opción incluyendo Ns/Nc y voto en blanco).
4. **Consulta 4:** Variación en puntos porcentuales respecto de la ola anterior (`LAG()`) y ranking de intención de voto por espacio político (`DENSE_RANK()`).

---

## ⚙️ Instrucciones de Ejecución y Reproducción

### Requisitos
- **Python:** 3.12 o superior.
- **PostgreSQL:** Versión 13 o superior (local vía Docker o remota vía Neon/Supabase).

### Pasos para reproducir
1. **Clonar el repositorio:**
   ```bash
   git clone https://github.com/MartinaSotelo/PruebaTecnica.git
   cd PruebaTecnica
   ```

2. **Crear y activar entorno virtual:**
   ```bash
   python -m venv .venv
   # En Windows PowerShell:
   .\.venv\Scripts\Activate.ps1
   # En Linux/macOS:
   source .venv/bin/activate
   ```

3. **Instalar dependencias requeridas:**
   ```bash
   pip install pandas numpy scikit-learn matplotlib seaborn sqlalchemy psycopg2-binary
   ```

4. **Levantar base de datos PostgreSQL (Opción recomendada por la consigna):**
   ```bash
   docker run --name prueba-pg -e POSTGRES_PASSWORD=prueba -p 5432:5432 -d postgres:16
   docker exec -i prueba-pg psql -U postgres < encuestas.sql
   ```
   *(Nota de seguridad: Si se utiliza una base remota como Neon, crear un archivo `.env` con `DATABASE_URL="..."`. El código del notebook se conecta automáticamente sin exponer credenciales).*

5. **Ejecutar el Notebook:**
   Abrir `prueba_tecnica_move.ipynb` en VS Code o Jupyter Lab y ejecutar todas las celdas (*Run All*).

---

## 🤖 Transparencia en el Uso de Inteligencia Artificial

De acuerdo con lo solicitado explícitamente en la consigna, se detalla el uso de herramientas de inteligencia artificial durante el desarrollo de la prueba:

- **Herramienta:** Asistente de IA (Antigravity / Gemini 3.8).
- **Gestión eficiente del tiempo:** Utilizado como soporte estratégico de *pair-programming* para acelerar sintaxis repetitiva, configurar entornos y agilizar visualizaciones bajo una ventana temporal de trabajo intensiva. Esto permitió focalizar el esfuerzo analítico en la auditoría de datos, la formulación de hipótesis y el rigor metodológico.

---

### 1. Uso en el Ejercicio 2 (SQL sobre Base de Encuestas)

#### A. ¿Para qué se utilizó?
1. **Transición tecnológica de DuckDB a PostgreSQL remoto:**
   - Habiendo trabajado previamente con DuckDB en entornos analíticos locales leyendo archivos `.csv`, utilicé la IA para profundizar en la arquitectura cliente-servidor de PostgreSQL en la nube (Neon), el rol de los conectores `psycopg2` y SQLAlchemy, y para diagnosticar particularidades de configuración (requisito de `sslmode=require` para conexiones remotas seguras y dialecto `postgresql+psycopg2://` en SQLAlchemy 2.0).
2. **Consultoría y conceptualización de funciones avanzadas de SQL:**
   - La IA explicó el funcionamiento de herramientas analíticas avanzadas: funciones de ventana (`ROW_NUMBER()` para deduplicación temporal según `registrada_en` y `LAG()` para variaciones inter-ola), creación de vistas reutilizables (`CREATE OR REPLACE VIEW`) y modularización mediante Common Table Expressions (CTEs con `WITH`).
3. **Modelado visual (DER):**
   - Estructuración de las 6 tablas y sus relaciones en formato nativo Markdown (`mermaid`).

#### B. Momentos de criterio propio, correcciones y ajustes metodológicos:
1. **Tratamiento metodológico del valor `edad = 999`:**
   - Al detectar el código atípico `999` en la exploración inicial, evalué primero descartar esas filas. Sin embargo, al discutir las implicancias en sociología electoral, comprendí que esos encuestados completaron el cuestionario y cuentan con un factor de expansión válido (`ponderador`). Eliminarlos hubiera sesgado y reducido la muestra en intención de voto y aprobación. Decidí mantener a los individuos en la muestra y aislar el valor faltante únicamente para el cálculo de la media de edad mediante `NULLIF(edad, 999)`.
2. **Cálculo de aprobación: porcentaje condicional vs. promedio:**
   - En la Consulta 2 evalué inicialmente promediar la columna `valor`, pero al auditar las categorías (1=Aprueba, 2=Desaprueba, 99=Ns/Nc) identifiqué que un promedio numérico (`AVG`) carecía de sentido analítico y distorsionaría la métrica debido al código 99. Ajusté la lógica hacia un conteo condicional con `CASE WHEN` sobre el total de casos por región.
3. **Formato de datos en Consulta 3 (Vertical vs. Pivot):**
   - Mi idea inicial era presentar la intención de voto de forma horizontal con una columna por partido. Tras analizar que la Consulta 4 requería calcular rankings y variaciones inter-ola con funciones de ventana, acordamos mantener la query SQL en formato relacional vertical (estándar analítico en bases de datos) y realizar el pivoteo ejecutivo directamente en Pandas para la visualización.

---

### 2. Uso en el Ejercicio 1 (Machine Learning y Predicción Electoral)

#### A. ¿Para qué se utilizó?
1. **Aceleración de código y pipelines de scikit-learn:**
   - Redacción ágil de la sintaxis de entrenamiento, métricas (`accuracy_score`, `roc_auc_score`, `f1_score`, matrices de confusión) y visualizaciones con `matplotlib` y `seaborn`.
2. **Exploración de la estructura del dataset censal:**
   - Asistencia en la interpretación del diccionario de variables de `meta_data.csv` y filtrado riguroso de variables con riesgo de *Data Leakage* (conteos directos de votos).

#### B. Momentos de criterio propio, honestidad técnica y correcciones:
1. **Selección honesta de modelos (Rechazo de Regresión Logística):**
   - La IA sugirió inicialmente aplicar una Regresión Logística regularizada junto con Random Forest. Decidí **no incluir la regresión logística** porque todavía no la domino en profundidad a nivel de implementación e interpretación matemática, y preferí ser honesta con mis conocimientos en lugar de entregar un modelo generado por IA que no pudiera defender técnicamente en una entrevista. Opté por **Árbol de Decisión (`DecisionTreeClassifier`)** y **Random Forest (`RandomForestClassifier`)**, dos modelos cuya lógica entiendo y puedo fundamentar con solvencia.
2. **Ajuste y validación de hiperparámetros (Tuning con Validación Cruzada):**
   - Al notar que la IA fijaba valores de profundidad de forma directa, recordé mi experiencia previa con Árboles y KNN donde se prueban múltiples configuraciones. Solicité incorporar un barrido sistemático de profundidades con validación cruzada (`cross_val_score`) sobre Train para demostrar analíticamente por qué `max_depth=4` es el punto óptimo que balancea sesgo y varianza frente a árboles sobreajustados.
3. **Definición de la Línea de Base (Inercia Electoral vs. Dummy Classifier):**
   - Aunque la IA propuso un clasificador simple que siempre predijera la clase más frecuente, definí que la verdadera línea de base sociopolítica en elecciones estadounidenses es la **inercia electoral** (predecir en 2020 el ganador de 2016). Esto demostró que el 93.3% de los condados mantiene su preferencia y brindó una conclusión mucho más valiosa para el cliente.
4. **Criterio sobre el alcance de los condados y población:**
   - Al notar que el dataset solo incluía ~430 condados de más de 65.000 habitantes, decidí no hacer suposiciones ni estimaciones externas sobre qué porcentaje de la población total representaban (ya que el dataset no cuenta con una columna de población total). Preferí circunscribir el análisis estrictamente a los datos disponibles, documentando la omisión de los restantes condados y estados como una limitación concreta del modelo y dejándolo planteado como una línea de investigación futura para cruzar con datos censales de población.
5. **Perspectiva institucional (Colegio Electoral):**
   - Incorporé como oportunidad de mejora futura el entendimiento de las reglas del Colegio Electoral (*Winner-Take-All* a nivel estatal), señalando que ganar condados por amplia ventaja no suma electores y que el próximo paso del modelo debería ser agregar las predicciones a nivel estatal para apuntar al umbral de 270 electores.

