# 🚗 Toll Seva – GPS-Based Smart Toll Collection & Vehicle Assistance System

Toll Seva is a modern, IoT-powered toll collection system that eliminates the need for traditional toll booths using real-time GPS tracking and mobile payments. The system ensures smooth traffic flow, faster toll deduction, and emergency roadside support—all from a mobile app integrated with smart vehicle sensors.

---

## 🧠 Key Features

- 📍 **Automatic Toll Deduction** via GPS and geo-fencing
- 🔋 **OBD-II Live Vehicle Monitoring** (battery, RPM, engine load)
- 💸 **Mobile Wallet Integration** using Razorpay
- 📲 **Push Notifications** for toll charges and low balance alerts
- 🆘 **Roadside Assistance** via WhatsApp/SMS
- ⚠️ **Accident Detection** with SW-420 vibration sensor
- 🔐 **Secure Data Handling** with Firebase and WebSocket APIs

---

## 📱 Technologies Used


| Technology           | Purpose                                |
|----------------------|----------------------------------------|
| **Flutter**          | Mobile app development                 |
| **Firebase**         | Real-time database, authentication     |
| **Arduino Uno**      | Microcontroller for IoT device         |
| **ELM327 (MODAXE)**  | OBD-II vehicle diagnostics             |
| **NEO-6M GPS**       | Location tracking                      |
| **SIM800L GSM**      | Emergency SMS alerts                   |
| **HC-05 Bluetooth**  | Device-phone communication             |
| **SW-420 Sensor**    | Vibration detection for accidents      |
| **Razorpay SDK**     | Wallet top-up & online payments        |
| **Tesseract OCR**    | Vehicle registration text reading      |

---

## 🛠️ System Architecture

- Embedded device plugged into car’s OBD-II port
- Real-time GPS tracking detects toll zone entry
- Toll calculated dynamically based on vehicle type and zone
- Toll auto-deducted from user’s app wallet
- Emergency events trigger automatic alerts via GSM
- Admin dashboard and user app synchronized through Firebase

---

## 📦 Installation & Setup

### Mobile App
1. Clone the repository:
   ```bash
   git clone https://github.com/vianshah3004/FinalYearProject.git
   ```
2. Navigate to the Flutter app:
   ``` bash
   cd toll-seva/mobile
   ```
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run on emulator or device:
   ```bash
   flutter run
   ```
---

## Team Members
Vian Shah 

Tirrth Mistry 

Shloka Shetiya 

Guided by: Mrs. Sharyu Kadam, Lecturer – Computer Engineering Dept., SBMP

---

## 📷 Project Snapshots

### 🔧 IoT Hardware Device
![Image](https://github.com/user-attachments/assets/441f69a6-fea7-4c4b-be76-b74c29c258df)

![Image](https://github.com/user-attachments/assets/200b60c6-e1c2-4aa0-83af-4a0de7e4fbfd)

![Image](https://github.com/user-attachments/assets/73decf30-cc71-4d33-a19b-53e2edfee13c)

### 📱 Mobile App 
![Image](https://github.com/user-attachments/assets/29fd0211-dba1-4827-8892-033f7a011ea3)

![Image](https://github.com/user-attachments/assets/3afd4edc-f0c6-4d02-9d0a-2b154fbeec9c)

![Image](https://github.com/user-attachments/assets/488a0a0d-6069-4d2f-a807-40902d385a47)

![Image](https://github.com/user-attachments/assets/ebdadc9c-a43c-4897-ad18-7c5027e12de2)

![Image](https://github.com/user-attachments/assets/3ce198df-4e9b-48e5-b8b2-88cb16beff03)

![Image](https://github.com/user-attachments/assets/7be6642a-3264-4100-92a0-66b478c560c5)

![Image](https://github.com/user-attachments/assets/a35d02c8-3a93-447b-8310-777141d3903c)

![Image](https://github.com/user-attachments/assets/a7f600c5-b23c-4849-b94b-ad224d482f6f)

![Image](https://github.com/user-attachments/assets/3277ec38-cbf4-454f-bac0-c9a817a35706)

![Image](https://github.com/user-attachments/assets/ac04fa96-051e-4d4c-9ca2-84751996e3d8)

![Image](https://github.com/user-attachments/assets/20b25cba-17d9-483d-9766-485567325fb2)

![Image](https://github.com/user-attachments/assets/cada8945-d241-4fcb-b5e0-3e2739b3d3fa)

![Image](https://github.com/user-attachments/assets/41f7ea12-109f-43ae-a3a1-88bf2eb0e6f3)

![Image](https://github.com/user-attachments/assets/0f33f4c5-ca06-421f-b775-d9565de8ca49)

---

## 🙌 Acknowledgements
Grateful for the collaboration and teamwork with Shloka Shetiya and Tirrth Mistry — this project wouldn't have been possible without them! 




