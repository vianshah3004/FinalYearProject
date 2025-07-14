#include <SoftwareSerial.h>
#include <TinyGPSPlus.h>
#include <math.h>

#define GPS_RX 10
#define GPS_TX 9
#define GSM_RX 7
#define GSM_TX 8
#define HC05_RX 2
#define HC05_TX 3
#define VIBRATION_PIN 4

SoftwareSerial gpsSerial(GPS_RX, GPS_TX);
SoftwareSerial gsmSerial(GSM_RX, GSM_TX);
SoftwareSerial HC05(HC05_RX, HC05_TX);
TinyGPSPlus gps;

#define VEHICLE_VIN ""
#define OBD_MAC ""
#define EMERGENCY_NUMBER ""
#define FIREBASE_HOST ""
#define FIREBASE_AUTH ""
#define BAUD_RATE 9600
#define BUFFER_RADIUS 0.5

const int MAX_TOLL_PLAZAS = 5;
double tollLat[MAX_TOLL_PLAZAS];
double tollLon[MAX_TOLL_PLAZAS];
float tollAmount[MAX_TOLL_PLAZAS];
int activeTollCount = 0;

bool isGPRSConnected = false;
bool isBluetoothConnected = false;
bool vehicleInTollZone = false;
bool entryDetected = false;
int currentTollIndex = -1;
float lastLat = 0, lastLon = 0;
bool vibrationActive = false;
unsigned long vibrationStartTime = 0;
bool systemActive = false;

unsigned long lastOBDCheck = 0;
unsigned long lastGPSCheck = 0;
unsigned long lastVibrationCheck = 0;
unsigned long lastFirebaseSync = 0;
unsigned long lastHeartbeat = 0;

double haversine(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371.0;
    double dLat = (lat2 - lat1) * M_PI / 180.0;
    double dLon = (lon2 - lon1) * M_PI / 180.0;
    
    double a = sin(dLat / 2) * sin(dLat / 2) +
               cos(lat1 * M_PI / 180.0) * cos(lat2 * M_PI / 180.0) * 
               sin(dLon / 2) * sin(dLon / 2);
    
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
}

String sendATCommand(String command, const int timeout) {
    gsmSerial.println(command);
    
    String response = "";
    long int time = millis();
    
    while ((time + timeout) > millis()) {
        while (gsmSerial.available()) {
            response += (char)gsmSerial.read();
        }
    }
    
    return response;
}

void sendSMS(String message) {
    gsmSerial.listen();
    
    sendATCommand("AT+CMGF=1", 1000);
    sendATCommand("AT+CMGS=\"" + String(EMERGENCY_NUMBER) + "\"", 1000);
    sendATCommand(message + (char)26, 10000);
}

void setupGPRS() {
    gsmSerial.listen();
    
    sendATCommand("AT", 1000);
    sendATCommand("AT+CMGF=1", 1000);
    sendATCommand("AT+CGATT=1", 2000);
    sendATCommand("AT+SAPBR=3,1,\"CONTYPE\",\"GPRS\"", 2000);
    sendATCommand("AT+SAPBR=3,1,\"APN\",\"airtelgprs.com\"", 2000);
    sendATCommand("AT+SAPBR=1,1", 10000);
    
    String response = sendATCommand("AT+SAPBR=2,1", 2000);
    isGPRSConnected = (response.indexOf("+SAPBR: 1,1") >= 0);
}

void setupHC05() {
    HC05.listen();
    
    HC05.println("AT");
    delay(500);
    HC05.println("AT+ROLE=0");
    delay(500);
    HC05.println("AT+BIND=" + String(OBD_MAC));
    delay(500);
    HC05.println("AT+INIT");
    delay(500);
    HC05.println("AT+LINK=" + String(OBD_MAC));
    delay(1000);
    
    String response = "";
    while (HC05.available()) {
        response += (char)HC05.read();
    }
    
    isBluetoothConnected = (response.indexOf("OK") >= 0);
}

String sendOBDCommand(String command) {
    HC05.println(command);
    
    String response = "";
    long int time = millis();
    
    while ((time + 1000) > millis()) {
        while (HC05.available()) {
            response += (char)HC05.read();
        }
    }
    
    return response;
}

void getOBDData(float &battery, float &coolant, float &load, String dtcCodes[], int &numDtcs) {
    HC05.listen();
    
    sendOBDCommand("ATZ");
    delay(200);
    sendOBDCommand("ATE0");
    delay(200);
    
    String response = sendOBDCommand("0142");
    battery = 12.0;
    int index = response.indexOf("41 42");
    if (index >= 0) {
        String data = response.substring(index + 6);
        data.trim();
        int value = strtol(data.c_str(), NULL, 16);
        battery = value / 1000.0;
    }
    
    response = sendOBDCommand("0105");
    coolant = 85.0;
    index = response.indexOf("41 05");
    if (index >= 0) {
        String data = response.substring(index + 6);
        data.trim();
        int value = strtol(data.c_str(), NULL, 16);
        coolant = value - 40;
    }
    
    response = sendOBDCommand("0104");
    load = 50.0;
    index = response.indexOf("41 04");
    if (index >= 0) {
        String data = response.substring(index + 6);
        data.trim();
        int value = strtol(data.c_str(), NULL, 16);
        load = (value * 100.0) / 255.0;
    }
    
    response = sendOBDCommand("03");
    numDtcs = 0;
    index = response.indexOf("43");
    if (index >= 0) {
        String data = response.substring(index + 3);
        data.trim();
        char* token = strtok((char*)data.c_str(), " ");
        
        while (token != NULL && numDtcs < 3) {
            String code = String(token);
            if (code.length() == 4) {
                dtcCodes[numDtcs] = "P" + code;
                numDtcs++;
            }
            token = strtok(NULL, " ");
        }
    }
}

bool getGPSData(float* lat, float* lon) {
    gpsSerial.listen();
    unsigned long start = millis();
    
    while (millis() - start < 1000) {
        while (gpsSerial.available() > 0) {
            if (gps.encode(gpsSerial.read())) {
                if (gps.location.isValid()) {
                    *lat = gps.location.lat();
                    *lon = gps.location.lng();
                    return true;
                }
            }
        }
    }
    
    return false;
}

void firebaseOperation(String method, String path, String data = "") {
    if (!isGPRSConnected) return;
    
    gsmSerial.listen();
    
    sendATCommand("AT+HTTPTERM", 1000);
    sendATCommand("AT+HTTPINIT", 1000);
    sendATCommand("AT+HTTPSSL=1", 1000);
    sendATCommand("AT+HTTPPARA=\"CID\",1", 1000);
    
    String url = "https://" + String(FIREBASE_HOST) + path;
    if (String(FIREBASE_AUTH).length() > 0) {
        url += "?auth=" + String(FIREBASE_AUTH);
    }
    
    sendATCommand("AT+HTTPPARA=\"URL\",\"" + url + "\"", 1000);
    
    if (method != "GET") {
        sendATCommand("AT+HTTPPARA=\"CONTENT\",\"application/json\"", 1000);
        sendATCommand("AT+HTTPDATA=" + String(data.length()) + ",10000", 1000);
        sendATCommand(data, 10000);
    }
    
    int actionType = (method == "GET") ? 0 : (method == "POST") ? 1 : 3;
    sendATCommand("AT+HTTPACTION=" + String(actionType), 10000);
    sendATCommand("AT+HTTPTERM", 1000);
}

void syncFirebaseData() {
    if (!isGPRSConnected) return;
    
    gsmSerial.listen();
    
    sendATCommand("AT+HTTPTERM", 1000);
    sendATCommand("AT+HTTPINIT", 1000);
    sendATCommand("AT+HTTPSSL=1", 1000);
    sendATCommand("AT+HTTPPARA=\"CID\",1", 1000);
    
    String url = "https://" + String(FIREBASE_HOST) + "/tollPlazas.json";
    if (String(FIREBASE_AUTH).length() > 0) {
        url += "?auth=" + String(FIREBASE_AUTH);
    }
    
    sendATCommand("AT+HTTPPARA=\"URL\",\"" + url + "\"", 1000);
    String response = sendATCommand("AT+HTTPACTION=0", 10000);
    
    if (response.indexOf("+HTTPACTION: 0,200") >= 0) {
        response = sendATCommand("AT+HTTPREAD", 10000);
        
        int dataStart = response.indexOf("\r\n") + 2;
        if (dataStart > 2) {
            response = response.substring(dataStart);
            
            activeTollCount = 0;
            int startPos = 0;
            
            while (activeTollCount < MAX_TOLL_PLAZAS) {
                int latPos = response.indexOf("\"lat\":", startPos);
                if (latPos < 0) break;
                
                int latValueStart = latPos + 6;
                int latValueEnd = response.indexOf(",", latValueStart);
                String latValue = response.substring(latValueStart, latValueEnd);
                tollLat[activeTollCount] = latValue.toFloat();
                
                int lonPos = response.indexOf("\"lon\":", latValueEnd);
                if (lonPos < 0) break;
                
                int lonValueStart = lonPos + 6;
                int lonValueEnd = response.indexOf(",", lonValueStart);
                String lonValue = response.substring(lonValueStart, lonValueEnd);
                tollLon[activeTollCount] = lonValue.toFloat();
                
                int amountPos = response.indexOf("\"amount\":", lonValueEnd);
                if (amountPos < 0) break;
                
                int amountValueStart = amountPos + 9;
                int amountValueEnd = response.indexOf("}", amountValueStart);
                String amountValue = response.substring(amountValueStart, amountValueEnd);
                tollAmount[activeTollCount] = amountValue.toFloat();
                
                activeTollCount++;
                startPos = amountValueEnd;
            }
        }
    }
    
    sendATCommand("AT+HTTPTERM", 1000);
    lastFirebaseSync = millis();
}

void processTollDeduction() {
    if (!isGPRSConnected || currentTollIndex < 0) return;
    
    String data = "{";
    data += "\"vin\":\"" + String(VEHICLE_VIN) + "\",";
    data += "\"tollId\":" + String(currentTollIndex) + ",";
    data += "\"amount\":" + String(tollAmount[currentTollIndex], 2) + ",";
    data += "\"timestamp\":\"" + String(millis()/1000) + "\"";
    data += "}";
    
    firebaseOperation("POST", "/transactions.json", data);
    
    String message = "Toll deducted: Rs." + String(tollAmount[currentTollIndex], 2);
    message += " at toll plaza " + String(currentTollIndex);
    sendSMS(message);
}

void checkVibration() {
    bool vibrationDetected = (digitalRead(VIBRATION_PIN) == LOW);
    
    if (vibrationDetected && !vibrationActive) {
        vibrationActive = true;
        vibrationStartTime = millis();
    } 
    else if (vibrationDetected && vibrationActive) {
        if (millis() - vibrationStartTime > 2000) {
            float battery, coolant, load;
            String dtcCodes[3];
            int numDtcs;
            getOBDData(battery, coolant, load, dtcCodes, numDtcs);
            
            if (load > 90 || numDtcs > 0) {
                String message = "EMERGENCY: Accident detected at location: ";
                message += String(lastLat, 6) + ", " + String(lastLon, 6);
                sendSMS(message);
                
                String data = "{";
                data += "\"type\":\"accident\",";
                data += "\"lat\":" + String(lastLat, 6) + ",";
                data += "\"lon\":" + String(lastLon, 6) + ",";
                data += "\"timestamp\":\"" + String(millis()/1000) + "\"";
                data += "}";
                
                firebaseOperation("POST", "/devices/" + String(VEHICLE_VIN) + "/events.json", data);
                
                vibrationActive = false;
            }
        }
    }
    else if (!vibrationDetected && vibrationActive) {
        vibrationActive = false;
    }
}

void checkGPSAndToll() {
    float latitude, longitude;
    bool gpsDataValid = getGPSData(&latitude, &longitude);
    
    if (gpsDataValid) {
        lastLat = latitude;
        lastLon = longitude;
        
        for (int i = 0; i < activeTollCount; i++) {
            double distance = haversine(latitude, longitude, tollLat[i], tollLon[i]);
            
            if (distance <= BUFFER_RADIUS) {
                if (!vehicleInTollZone) {
                    vehicleInTollZone = true;
                    entryDetected = true;
                    currentTollIndex = i;
                    
                    String message = "Entered toll zone " + String(i);
                    sendSMS(message);
                }
                break;
            }
        }
        
        if (vehicleInTollZone) {
            double distance = haversine(latitude, longitude, tollLat[currentTollIndex], tollLon[currentTollIndex]);
            
            if (distance > BUFFER_RADIUS) {
                if (entryDetected && isGPRSConnected) {
                    processTollDeduction();
                }
                
                vehicleInTollZone = false;
                entryDetected = false;
                currentTollIndex = -1;
            }
        }
    }
}

void setup() {
    Serial.begin(BAUD_RATE);
    gpsSerial.begin(BAUD_RATE);
    gsmSerial.begin(BAUD_RATE);
    HC05.begin(38400);
    
    pinMode(VIBRATION_PIN, INPUT);
    
    delay(2000);
    
    setupGPRS();
    
    if (isGPRSConnected) {
        sendSMS("Smart Toll System initializing...");
        syncFirebaseData();
        setupHC05();
        systemActive = true;
    }
}

void loop() {
    if (millis() - lastVibrationCheck > 100) {
        checkVibration();
        lastVibrationCheck = millis();
    }
    
    if (millis() - lastGPSCheck > 5000) {
        checkGPSAndToll();
        lastGPSCheck = millis();
    }
    
    if (millis() - lastOBDCheck > 30000 && isBluetoothConnected) {
        float battery, coolant, load;
        String dtcCodes[3];
        int numDtcs;
        getOBDData(battery, coolant, load, dtcCodes, numDtcs);
        lastOBDCheck = millis();
    }
    
    if (millis() - lastFirebaseSync > 900000 && isGPRSConnected) {
        syncFirebaseData();
    }
    
    if (!isGPRSConnected && millis() % 60000 < 100) {
        setupGPRS();
    }
    if (!isBluetoothConnected && millis() % 120000 < 100) {
        setupHC05();
    }
}
