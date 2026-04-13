import mysql.connector
import os
from dotenv import load_dotenv

# This looks for the .env file we created earlier
load_dotenv()

def get_db_connection():
    """Establishes and returns a connection to the MySQL database."""
    try:
        connection = mysql.connector.connect(
            host=os.getenv("DB_HOST"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME")
        )
        if connection.is_connected():
            return connection
    except mysql.connector.Error as err:
        print(f"❌ Database Error: {err}")
        return None