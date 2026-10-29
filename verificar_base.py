import psycopg2

# URL de conexión a base de datos en Neon
DB_URL = "postgresql://neondb_owner:npg_nkU0oE6LAuWx@ep-red-salad-b5gtg77y-pooler.c-7.us-east-2.aws.neon.tech/neondb?sslmode=require"

def cargar_y_verificar():
    print("1. Conectando a PostgreSQL en Neon...")
    conn = psycopg2.connect(DB_URL)
    cur = conn.cursor()

    print("2. Leyendo el archivo encuestas.sql...")
    with open("encuestas.sql", "r", encoding="utf-8") as f:
        sql_script = f.read()

    print("3. Ejecutando el script SQL en la base de datos...")

    cur.execute(sql_script)
    conn.commit()
    print("   -> Tablas creadas y registros insertados con éxito.")

    print("\n4. Verificando cantidad de registros por tabla:")
    tablas = [
        "encuestas",
        "provincias",
        "encuestados",
        "preguntas",
        "opciones",
        "respuestas"
    ]

    for tabla in tablas:
        cur.execute(f"SELECT COUNT(*) FROM {tabla};")
        total = cur.fetchone()[0]
        print(f"   • {tabla:<12}: {total:>5} registros")

    cur.close()
    conn.close()
    print("\n✓ ¡Base de datos cargada y verificada correctamente!")

if __name__ == "__main__":
    cargar_y_verificar()
