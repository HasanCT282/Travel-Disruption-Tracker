from database import get_db_connection

def verify_system():
    print("--- Database Connection Test ---")
    connection = get_db_connection()
    
    if connection and connection.is_connected():
        print("✅ SUCCESS: Python is talking to MySQL!")
        
        # Let's try to list the tables we just created
        cursor = connection.cursor()
        cursor.execute("SHOW TABLES;")
        tables = cursor.fetchall()
        
        print(f"✅ Tables found in 'disruption_tracker':")
        for (table_name,) in tables:
            print(f"   - {table_name}")
            
        cursor.close()
        connection.close()
        print("--- Test Complete ---")
    else:
        print("❌ FAILED: Could not connect to the database.")
        print("Tip: Check your .env file password and ensure MySQL is running.")

if __name__ == "__main__":
    verify_system()