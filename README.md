# LVDS - Transceiver

## Abstract

Dieses Projekt beinhaltet Hardwarebeschreibungen (Verilog) zur Synthese eines Transceivers, welcher für das Zynq7000 - Boards entwickelt wurde. Die serielle Datenübertragung erreicht durch die Nutzung der IOSerDes - und IDelaye Primitiven die Chip-spezifische Maximaldatenrate.

### Spezifikationen
- Datenrate  von 1200Mbit/s (DDR bei 600MHz)
- Gleichstromfreie Datenübertragung durch Anwendung einer 8B10B - Kodierung
- Datenprüfung mittels CRC-8
- Ack/Nack - Mechanismus
- Bit Deskew
- Optimiertes Senden durch direkte Verkettung anliegender Daten
- Variable Datenbereite für parallele Datenübergabe


---

## Kompilieren


## Funktionsweise Link - Layer

![Benutzerinterface](hmi.png)

### Sender (Packet Generator) 

Für den Verbindungsaufbau muss das Stecker-Icon rechts neben der Überschrift gedrückt werden. Bei erfolgreichem Kommunikationsaufbau wird die Steckverbindung symbolisch geschlossen und mit einer grünen Umrandung signalisiert. Sollte die Kommunikation Systemseitig unterbrochen werden, so stellt sich ein roter Hintergrund ein. Die Kommunikation kann jederzeit durch ancklicken

### Empfänger (Packet Checker)

Dieses Benutzerpanel dient zum Test und Überwachen des Datentransfers über die Uart Schnittstelle. Durch drücken des Tasters "Test" wird ein zufälliges Byte erzeugt, welches vom Test-Core zurückgeschickt wird. Ein passender Vergleich bestätigt die Verbindung, welche am Textfeld ausgegeben wird. Das LOG-Fenster protokolliert alle Transferaufträge mit Datum und Uhrzeit. 

### Link - Manager

Der Datengenerator lässt 56 zufällige bytes auf dem Server erzeugen und sendet diese an das FPGA-Testsytsem. Dabei werden die erzeugten Daten zum direkten Verlgeich an die Client-Anwendung geshcickt und im Textfeld angezeigt. Das Datenpaket wird in einem RAM-Block innerhalb des Testsystems gesichert. esultate auf dem Client zusammen ausgegeben. Weiter folgt im Feld der Resultate (Rechte Seite) die Anzahl der Zyklen, welche ein Durchlauf vom Start-RAM in den Ziel-RAM beschreibt. Dieser Wert sowi

## Funktionsweise Physical - Layer

Jeder

### SerDes


### Gearbox

### Wortausrichtung

### Initiale Tab - Kalibration

### Überwachung der 



## Testsystem (Test - Core)

### Architektur

## Test und Validierung

### Hardware

### Testbench

### Python

## Offene Punkte

### Link - Controller

### Test




