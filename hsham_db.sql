/* HSHAM Database Management System
   Company : HSHAM for Tech Solutions (my made-up company from the
             Akamai courses, it helps small offices and home offices
             (SOHO) in Bahrain with cybersecurity)
   Course  : Managing Relational Databases - Capstone Project
             Akamai Network Engineering Professional Certificate
   Author  : Hussain Ali Merza Shamlooh
   Tested  : MySQL 8.0 and MariaDB 10.11

   This database is the backend for the company website. It saves the
   customers, the employees, their logins, and the security incidents
   that we get from packet captures on the customers' devices.

   How to run: just run the whole file from top to bottom. The first
   line deletes HSHAM_DB if it is already there, so you can run the
   script again many times without getting errors. */


/* Create the database
   I added utf8mb4 so the database can also save Arabic names later. */
DROP DATABASE IF EXISTS HSHAM_DB;
CREATE DATABASE HSHAM_DB
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE HSHAM_DB;


/* PART 1 - CREATE THE TABLES */

/* 1 A - customers table
   Every row is one small business that uses our service. These are the
   same fields from the contact form on the company website.
   I used the Bahrain address style (building, road, block) and
   "governorate" instead of "state", because we don't have states here. */
CREATE TABLE customers (
    customerID      INT          NOT NULL AUTO_INCREMENT,
    firstName       VARCHAR(50)  NOT NULL,
    lastName        VARCHAR(50)  NOT NULL,
    companyName     VARCHAR(100) NOT NULL,
    address         VARCHAR(200) NOT NULL,   -- building, road and block
    city            VARCHAR(50)  NOT NULL,
    governorate     VARCHAR(50)  NOT NULL,   -- like a "state" in the US
    postalCode      VARCHAR(20),
    email           VARCHAR(100) NOT NULL UNIQUE,   -- two customers can't share an email
    phone           VARCHAR(20)  NOT NULL,
    preferredContact ENUM('email', 'phone') DEFAULT 'email',  -- extra field (optional in the instructions)
    PRIMARY KEY (customerID)
);

/* 1 B - employees table
   Every row is one person who works at HSHAM. They are the same people
   who have accounts on my Linux file server from the OS course.
   employeeType is a short code:
       'M' = management, 'T' = technician, 'I' = intern
   supervisorID points to another employee in the SAME table, so we can
   know who is the boss of who.
   endDate stays NULL for full-time staff. Interns have an end date
   because their contract is only 6 months. */
CREATE TABLE employees (
    employeeID      INT          NOT NULL AUTO_INCREMENT,
    firstName       VARCHAR(50)  NOT NULL,
    lastName        VARCHAR(50)  NOT NULL,
    email           VARCHAR(100) NOT NULL UNIQUE,
    position        VARCHAR(100) NOT NULL,
    employeeType    CHAR(1)      NOT NULL,
    supervisorID    INT          NULL,       -- NULL for the top manager
    hireDate        DATE         NOT NULL,
    endDate         DATE         NULL,
    PRIMARY KEY (employeeID),
    -- only allow the three codes, so nobody types a wrong letter
    CONSTRAINT chk_employee_type CHECK (employeeType IN ('M', 'T', 'I')),
    CONSTRAINT fk_employee_supervisor
        FOREIGN KEY (supervisorID) REFERENCES employees (employeeID)
);

/* 1 C - login table
   Usernames and passwords for customers AND employees.
   userType tells us who it is: 'C' = customer, 'E' = employee.

   At first I used one column called personID for both, but then I
   found a problem: one column can't be a foreign key to two different
   tables, so the database can't check if the person really exists.
   So I made two columns (customerID and employeeID). Only one of them
   is filled in, and the CHECK below makes sure it matches userType.

   The passwords are saved as SHA-256 hashes, not as plain text. */
CREATE TABLE login (
    loginID         INT          NOT NULL AUTO_INCREMENT,
    userType        CHAR(1)      NOT NULL,
    customerID      INT          NULL,
    employeeID      INT          NULL,
    username        VARCHAR(50)  NOT NULL UNIQUE,
    passwordHash    CHAR(64)     NOT NULL,   -- a SHA-256 hash is always 64 characters
    PRIMARY KEY (loginID),
    CONSTRAINT chk_login_owner CHECK (
        (userType = 'C' AND customerID IS NOT NULL AND employeeID IS NULL) OR
        (userType = 'E' AND employeeID IS NOT NULL AND customerID IS NULL)
    ),
    -- if a customer or employee is deleted, their login is deleted too
    CONSTRAINT fk_login_customer
        FOREIGN KEY (customerID) REFERENCES customers (customerID)
        ON DELETE CASCADE,
    CONSTRAINT fk_login_employee
        FOREIGN KEY (employeeID) REFERENCES employees (employeeID)
        ON DELETE CASCADE
);

/* 1 D and 1 E - incidents table
   Every row is one packet that we took from a customer's packet capture.
   Some notes to understand the columns:
     - sourceIP / destinationIP = where the traffic started and where it
       finally goes (for example a website on the internet)
     - hostIP / serverIP = only the local part of the trip, the
       customer's computer (host) and their router (server)
   customerID is a foreign key, so every incident must belong to a
   real customer. */
CREATE TABLE incidents (
    incidentID      INT          NOT NULL AUTO_INCREMENT,
    packetDateTime  DATETIME     NOT NULL,
    sourceIP        VARCHAR(45)  NOT NULL,   -- 45 so IPv6 can also fit
    destinationIP   VARCHAR(45)  NOT NULL,
    protocol        VARCHAR(10)  NOT NULL,
    sourcePort      INT          NULL,       -- NULL because ICMP (ping) has no ports
    destinationPort INT          NULL,
    hostIP          VARCHAR(45)  NOT NULL,
    serverIP        VARCHAR(45)  NOT NULL,
    sourceMAC       CHAR(17)     NOT NULL,   -- MAC format is XX:XX:XX:XX:XX:XX = 17 chars
    destinationMAC  CHAR(17)     NOT NULL,
    info            VARCHAR(255),
    customerID      INT          NOT NULL,
    PRIMARY KEY (incidentID),
    INDEX idx_incidents_customer (customerID),   -- makes searching by customer faster
    CONSTRAINT fk_incident_customer
        FOREIGN KEY (customerID) REFERENCES customers (customerID)
        ON DELETE CASCADE
);


/* PART 2 - ADD THE SAMPLE RECORDS */

/* 2 A - customer records
   Three small businesses in different cities in Bahrain.
   All the names and details are made up. */
INSERT INTO customers
    (firstName, lastName, companyName, address, city, governorate, postalCode, email, phone, preferredContact)
VALUES
    ('Ahmed',    'Al-Mansoori', 'Gulf Tech Solutions',
     'Bldg 123, Road 1702, Block 317', 'Manama',   'Capital',     '317', 'ahmed@gulftech.bh',        '+973 1712 3456', 'email'),
    ('Fatima',   'Hassan',      'Bahrain Digital Services',
     'Bldg 456, Road 2015, Block 920', 'Riffa',    'Southern',    '920', 'fatima@bahraindigital.bh', '+973 1723 4567', 'phone'),
    ('Mohammed', 'Al-Khalifa',  'Desert IT Consulting',
     'Bldg 789, Road 214, Block 202',  'Muharraq', 'Muharraq',    '202', 'mohammed@desertit.bh',     '+973 1734 5678', 'email');

/* 2 B - employee records
   The same team from my Linux file server:
     - Mohammed: the manager, he supervises everyone
     - Abdullah: full-time technician
     - Ahmed and Ali: interns for 6 months (July 2025 to January 2026)
   Ali's supervisor is Abdullah, the others report to Mohammed. */
INSERT INTO employees
    (firstName, lastName, email, position, employeeType, supervisorID, hireDate, endDate)
VALUES
    ('Mohammed', 'Al-Rashid',  'mohammed@hsham.bh', 'Security Operations Manager', 'M', NULL, '2025-01-15', NULL),
    ('Abdullah', 'Al-Zahra',   'abdullah@hsham.bh', 'Network Security Technician', 'T', 1,    '2025-02-01', NULL),
    ('Ahmed',    'Al-Sabah',   'ahmed@hsham.bh',    'Security Analyst Intern',     'I', 1,    '2025-07-18', '2026-01-18'),
    ('Ali',      'Al-Mahmood', 'ali@hsham.bh',      'Network Operations Intern',   'I', 2,    '2025-07-18', '2026-01-18');

/* 2 C - login records
   One login for every customer (3) and every employee (4) = 7 rows.
   SHA2(..., 256) turns each password into a hash when we insert it,
   so the real password is never saved in the table. */
INSERT INTO login (userType, customerID, employeeID, username, passwordHash)
VALUES
    ('C', 1,    NULL, 'ahmed_gulf',      SHA2('Demo#Cust1', 256)),
    ('C', 2,    NULL, 'fatima_digital',  SHA2('Demo#Cust2', 256)),
    ('C', 3,    NULL, 'mohammed_desert', SHA2('Demo#Cust3', 256)),
    ('E', NULL, 1,    'mohammed.hsham',  SHA2('Demo#Emp1',  256)),
    ('E', NULL, 2,    'abdullah.hsham',  SHA2('Demo#Emp2',  256)),
    ('E', NULL, 3,    'ahmed.intern',    SHA2('Demo#Emp3',  256)),
    ('E', NULL, 4,    'ali.intern',      SHA2('Demo#Emp4',  256));

/* 2 D - incident records
   9 incidents in total, like the instructions asked:
     customer 1 = 2 incidents, customer 2 = 3 incidents, customer 3 = 4 incidents
   Each customer has their own LAN, and their router is always .1
   (that's why serverIP ends with .1). */
INSERT INTO incidents
    (packetDateTime, sourceIP, destinationIP, protocol, sourcePort, destinationPort,
     hostIP, serverIP, sourceMAC, destinationMAC, info, customerID)
VALUES
    -- Customer 1: Gulf Tech Solutions (LAN 192.168.10.0/24)
    ('2025-07-02 09:14:22', '192.168.10.25', '93.184.216.34',  'TCP',  51522, 443,
     '192.168.10.25', '192.168.10.1', 'A4:5E:60:1A:2B:01', '00:1A:2B:3C:4D:01',
     'TLS handshake to unrecognised domain', 1),
    ('2025-07-09 16:40:05', '192.168.10.31', '185.199.108.153','UDP',  53011, 53,
     '192.168.10.31', '192.168.10.1', 'A4:5E:60:1A:2B:02', '00:1A:2B:3C:4D:01',
     'DNS query to external resolver bypassing company DNS', 1),

    -- Customer 2: Bahrain Digital Services (LAN 192.168.20.0/24)
    ('2025-07-03 11:02:47', '192.168.20.14', '8.8.8.8',        'ICMP', NULL,  NULL,
     '192.168.20.14', '192.168.20.1', 'B8:27:EB:20:00:14', '00:1A:2B:3C:4D:02',
     'High-rate ICMP echo requests (possible ping flood)', 2),
    ('2025-07-11 02:17:33', '192.168.20.22', '45.33.32.156',   'TCP',  49812, 22,
     '192.168.20.22', '192.168.20.1', 'B8:27:EB:20:00:22', '00:1A:2B:3C:4D:02',
     'Repeated SSH connection attempts', 2),
    ('2025-07-15 13:55:10', '192.168.20.14', '104.16.85.20',   'TCP',  50233, 80,
     '192.168.20.14', '192.168.20.1', 'B8:27:EB:20:00:14', '00:1A:2B:3C:4D:02',
     'Unencrypted HTTP login form submission', 2),

    -- Customer 3: Desert IT Consulting (LAN 192.168.30.0/24)
    ('2025-07-04 08:12:30', '192.168.30.40', '162.159.200.1',  'UDP',  123,   123,
     '192.168.30.40', '192.168.30.1', 'DC:A6:32:30:00:40', '00:1A:2B:3C:4D:03',
     'NTP request to non-approved time server', 3),
    ('2025-07-08 14:25:51', '192.168.30.41', '142.250.181.109','TCP',  52144, 993,
     '192.168.30.41', '192.168.30.1', 'DC:A6:32:30:00:41', '00:1A:2B:3C:4D:03',
     'IMAPS session at unusual hour', 3),
    ('2025-07-17 19:48:09', '192.168.30.42', '198.51.100.77',  'TCP',  53390, 445,
     '192.168.30.42', '192.168.30.1', 'DC:A6:32:30:00:42', '00:1A:2B:3C:4D:03',
     'Outbound SMB traffic to internet (blocked by policy)', 3),
    ('2025-07-21 10:08:22', '192.168.30.40', '203.0.113.25',   'TCP',  54001, 25,
     '192.168.30.40', '192.168.30.1', 'DC:A6:32:30:00:40', '00:1A:2B:3C:4D:03',
     'Direct SMTP from workstation (possible spam bot)', 3);


/* PART 3 - THE QUERIES */

/* 3 A - customer info
   Shows the name, company, email and username of every customer.
   I join customers with login using customerID. */
SELECT c.firstName,
       c.lastName,
       c.companyName,
       c.email,
       l.username
FROM customers AS c
JOIN login     AS l ON l.customerID = c.customerID
ORDER BY c.customerID;

/* 3 B - employee info
   Shows ALL the employee columns (that's why I used e.*) plus the
   username from the login table. */
SELECT e.*,
       l.username
FROM employees AS e
JOIN login     AS l ON l.employeeID = e.employeeID
ORDER BY e.employeeID;

/* 3 C - incidents with customer info
   For every incident, it shows who the customer is, the source and
   destination IP, and the info. It should return 9 rows. */
SELECT c.firstName,
       c.lastName,
       c.companyName,
       i.sourceIP,
       i.destinationIP,
       i.info
FROM incidents AS i
JOIN customers AS c ON c.customerID = i.customerID
ORDER BY i.packetDateTime;

/* 3 D - mailing list
   Makes one address label for each customer, and every part is on
   a new line:
     line 1: first and last name
     line 2: company name
     line 3: building, road and block
     line 4: city, governorate and postal code
     line 5: country
   CHAR(10) is the "new line" character, and CONCAT_WS puts it
   between every part.
   Tip: in MySQL Workbench the cell looks like one line. Right-click it
   and choose "Open Value in Viewer" to see all the lines. */
SELECT CONCAT_WS(CHAR(10),
           CONCAT(c.firstName, ' ', c.lastName),
           c.companyName,
           c.address,
           CONCAT(c.city, ', ', c.governorate, ' ', c.postalCode),
           'Kingdom of Bahrain'
       ) AS mailingLabel
FROM customers AS c
ORDER BY c.lastName, c.firstName;

/* 3 E - number of incidents for each company
   I used LEFT JOIN, not JOIN, so a customer with zero incidents will
   still show up with a count of 0 instead of disappearing. */
SELECT c.companyName,
       COUNT(i.incidentID) AS incidentCount
FROM customers      AS c
LEFT JOIN incidents AS i ON i.customerID = c.customerID
GROUP BY c.customerID, c.companyName
ORDER BY incidentCount DESC;

/* 3 F - customers with the highest and lowest incident counts
   This was the hardest query for me. The instructor said it must still
   work if we add more incidents later, so I can't just write 2 and 4.
   How it works:
     1. The inner subquery counts the incidents for every customer.
     2. MAX() and MIN() take the highest and lowest of those counts.
     3. HAVING keeps only the customers whose count equals one of them.
   If two customers have the same highest count, both will show.
   The result is sorted from the lowest count to the highest. */
SELECT c.firstName,
       c.lastName,
       c.companyName,
       COUNT(i.incidentID) AS incidentCount
FROM customers      AS c
LEFT JOIN incidents AS i ON i.customerID = c.customerID
GROUP BY c.customerID, c.firstName, c.lastName, c.companyName
HAVING COUNT(i.incidentID) = (
           SELECT MAX(t.cnt) FROM (
               SELECT COUNT(i2.incidentID) AS cnt
               FROM customers      AS c2
               LEFT JOIN incidents AS i2 ON i2.customerID = c2.customerID
               GROUP BY c2.customerID
           ) AS t
       )
    OR COUNT(i.incidentID) = (
           SELECT MIN(t.cnt) FROM (
               SELECT COUNT(i2.incidentID) AS cnt
               FROM customers      AS c2
               LEFT JOIN incidents AS i2 ON i2.customerID = c2.customerID
               GROUP BY c2.customerID
           ) AS t
       )
ORDER BY incidentCount ASC;

/* 3 G - days since the last incident
   For every customer it shows:
     - the customer number
     - the date of their newest incident (MAX gives the latest date)
     - how many days passed between today and that incident
   CURDATE() is the date when you run the script, so the number of
   days will be different every day. */
SELECT c.customerID,
       DATE(MAX(i.packetDateTime))                  AS lastIncidentDate,
       DATEDIFF(CURDATE(), MAX(i.packetDateTime))   AS daysSinceLastIncident
FROM customers AS c
JOIN incidents AS i ON i.customerID = c.customerID
GROUP BY c.customerID
ORDER BY c.customerID;
