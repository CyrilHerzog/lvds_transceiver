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


## Kompilieren

Das Repository beinhaltet ein Makefile zum kompilieren der Hardwarebeschreibungen für Simulation und Zielhardware. Die entwickelten Module sind in Ordnerstrukturen organsisiert. Die make - Anweisungen werden jeweils auf den Modulordner referenziert.   
![Workflow](doc/graphics/workflow.png)

### Anweisungen
- Kompilieren mit IVerilog => mingw32-make "Modul"
- Ausführen der Simulation (Testbench + GTK Wave) => mingw32-make wave "Modul"
- Build für Xilinx Zynq7000 (Ausführen build.tcl) => mingw32-make build
- Laden des Zynq7000 (Ausführen prog.tcl) => mingw32-make prog  


## Funktionsweise Link - Layer
Der Link - Layer 

### DLLP - Frame

### TLP - Frame

### Sender (Packet Generator) 

Für den Verbindungsaufbau muss das Stecker-Icon rechts neben der Überschrift gedrückt werden. Bei erfolgreichem Kommunikationsaufbau wird die Steckverbindung symbolisch geschlossen und mit einer grünen Umrandung signalisiert. Sollte die Kommunikation Systemseitig unterbrochen werden, so stellt sich ein roter Hintergrund ein. Die Kommunikation kann jederzeit durch ancklicken

### Empfänger (Packet Checker)

Dieses Benutzerpanel dient zum Test und Überwachen des Datentransfers über die Uart Schnittstelle. Durch drücken des Tasters "Test" wird ein zufälliges Byte erzeugt, welches vom Test-Core zurückgeschickt wird. Ein passender Vergleich bestätigt die Verbindung, welche am Textfeld ausgegeben wird. Das LOG-Fenster protokolliert alle Transferaufträge mit Datum und Uhrzeit. 

### Link - Manager



## Funktionsweise Physical - Layer


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






