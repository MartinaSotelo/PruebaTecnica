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

De acuerdo con lo solicitado en la consigna:
- **Herramienta:** Asistente de IA (Antigravity / Gemini 3.8).
- **Aplicación práctica:** Apoyo como herramienta de *pair-programming* para acelerar sintaxis repetitiva, configurar conexiones y optimizar visualizaciones bajo una ventana temporal de trabajo intensiva.
- **Criterio propio y correcciones metodológicas:**
  - **Rechazo de Regresión Logística:** Desestimación de la sugerencia inicial de la IA para optar por Árbol de Decisión y Random Forest, priorizando modelos dominados técnicamente por la postulante.
  - **Tuning de hiperparámetros:** Decisión de no aceptar profundidades fijas y exigir una búsqueda con validación cruzada para justificar empíricamente la complejidad del modelo.
  - **Línea de base de inercia electoral:** Elección de la persistencia de 2016 por sobre un clasificador mayoritario genérico.
  - **Límites de los datos censales:** Rechazo de estimaciones externas de población para circunscribirse rigurosamente a las 430 jurisdicciones relevadas.
