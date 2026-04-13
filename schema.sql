-- Flight Delay & Aviation Disruption Tracker - MySQL Schema
-- Level 1: Dimension Tables (No FKs)

-- 1. AIRPORTS (Dimension)
CREATE TABLE AIRPORTS (
    airport_id INT AUTO_INCREMENT PRIMARY KEY,
    airport_name VARCHAR(100) NOT NULL,
    iata_code CHAR(3) NOT NULL,
    city VARCHAR(50) NOT NULL,
    state VARCHAR(50),
    country VARCHAR(50) NOT NULL,
    timezone VARCHAR(40) NOT NULL,
    INDEX idx_iata (iata_code)
) ENGINE=InnoDB;

-- 2. AIRLINES (Dimension)
CREATE TABLE AIRLINES (
    airline_id INT AUTO_INCREMENT PRIMARY KEY,
    airline_name VARCHAR(100) NOT NULL,
    iata_code CHAR(2) NOT NULL,
    country VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    INDEX idx_iata (iata_code)
) ENGINE=InnoDB;

-- 3. CANCELLATION_CODES (Dimension)
CREATE TABLE CANCELLATION_CODES (
    code CHAR(1) PRIMARY KEY,
    reason_description VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- Level 2: Fact Tables (FKs to Level 1)

-- 4. WEATHER
CREATE TABLE WEATHER (
    weather_id INT AUTO_INCREMENT PRIMARY KEY,
    airport_id INT NOT NULL,
    weather_date DATE NOT NULL,
    temperature DECIMAL(5,2),
    wind_speed DECIMAL(5,2),
    precipitation DECIMAL(5,2),
    visibility DECIMAL(5,2),
    weather_condition VARCHAR(50),
    FOREIGN KEY (airport_id) REFERENCES AIRPORTS(airport_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_airport_date (airport_id, weather_date)
) ENGINE=InnoDB;

-- 5. FLIGHTS (Central Fact)
CREATE TABLE FLIGHTS (
    flight_id INT AUTO_INCREMENT PRIMARY KEY,
    flight_date DATE NOT NULL,
    airline_id INT NOT NULL,
    origin_airport_id INT NOT NULL,
    dest_airport_id INT NOT NULL,
    scheduled_departure TIME NOT NULL,
    actual_departure TIME,
    scheduled_arrival TIME NOT NULL,
    actual_arrival TIME,
    departure_delay INT,
    arrival_delay INT,
    cancelled BOOLEAN DEFAULT FALSE,
    cancellation_code CHAR(1),
    distance INT,
    FOREIGN KEY (airline_id) REFERENCES AIRLINES(airline_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (origin_airport_id) REFERENCES AIRPORTS(airport_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (dest_airport_id) REFERENCES AIRPORTS(airport_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (cancellation_code) REFERENCES CANCELLATION_CODES(code)
        ON DELETE SET NULL ON UPDATE CASCADE,
    INDEX idx_flight_date (flight_date),
    INDEX idx_airport_id (origin_airport_id),
    INDEX idx_airport_id_dest (dest_airport_id),
    INDEX idx_airline (airline_id)
) ENGINE=InnoDB;

-- Level 3: Alert Table (FKs to Level 1 & 2)

-- 6. DELAY_ALERTS (Trigger-populated)
CREATE TABLE DELAY_ALERTS (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    airline_id INT NOT NULL,
    airport_id INT NOT NULL,
    alert_date DATE NOT NULL,
    total_delays INT NOT NULL,
    avg_delay_mins DECIMAL(6,2) NOT NULL,
    triggered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (airline_id) REFERENCES AIRLINES(airline_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (airport_id) REFERENCES AIRPORTS(airport_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    INDEX idx_alert_date (alert_date),
    INDEX idx_airline_airport (airline_id, airport_id),
    UNIQUE KEY unique_daily_alert (airline_id, airport_id, alert_date)
) ENGINE=InnoDB;

DELIMITER //

CREATE TRIGGER after_flight_insert
AFTER INSERT ON FLIGHTS
FOR EACH ROW
BEGIN
    -- Check if the flight we just added is actually delayed
    IF NEW.departure_delay > 15 THEN
        -- Insert or Update the Alert table for this airline/airport/day
        INSERT INTO DELAY_ALERTS (airline_id, airport_id, alert_date, total_delays, avg_delay_mins)
        SELECT 
            airline_id, 
            origin_airport_id, 
            flight_date, 
            COUNT(*), 
            AVG(departure_delay)
        FROM FLIGHTS
        WHERE airline_id = NEW.airline_id 
          AND origin_airport_id = NEW.origin_airport_id 
          AND flight_date = NEW.flight_date
          AND departure_delay > 0
        GROUP BY airline_id, origin_airport_id, flight_date
        HAVING COUNT(*) >= 5 -- The threshold for a "Pattern"
        ON DUPLICATE KEY UPDATE 
            total_delays = VALUES(total_delays),
            avg_delay_mins = VALUES(avg_delay_mins),
            triggered_at = CURRENT_TIMESTAMP;
    END IF;
END //

DELIMITER ;
