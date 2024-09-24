# LVDS - Transceiver

Dieses Dokument beschreibt grundlegende Informationen zum entwickelten Transceiver. Zwei Transceiver werden zusammen mit einer Testschaltung auf einem Zynq7000 synthesiert. Dabei wird der zweite Transceiver B (Sink) mit dem ersten Transceiver A (Source) synchronisiert. Die Testschaltung (Testcore) erlaubt das Transferieren von Datenpacketen zwischen den Transceivern. Das Steuern und Auswerten (Monitoring) erfolgt mittels Python - Skript, welcher Steuer - und Datenbytes an den Testcore mittels UART überträgt. Der Transceiver ist in der Lage Transaction - Layerpackete (TLP) sicher zu übertragen.  
## Abstract

Dieses Projekt beinhaltet Hardwarebeschreibungen (Verilog) zur Synthese eines Transceivers, welcher für das Zynq7000 - Boards entwickelt wurde. Die serielle Datenübertragung erreicht durch die Nutzung der IOSerDes - und IDelaye Primitiven die Chip-spezifische Maximaldatenrate.

### Spezifikationen
- Datenrate  von 1200Mbit/s (DDR bei 600MHz)
- Gleichstromfreie Datenübertragung durch Anwendung einer 8B10B - Kodierung
- Datenprüfung mittels CRC-8
- Ack/Nack - Mechanismus
- Bit Deskew
- Optimiertes Senden durch direkte Verkettung anliegender Daten
- Variable Datenbereite für parallele Datenübergabe (TLP) 

## Kompilieren

Das Repository beinhaltet ein Makefile zum kompilieren der Hardwarebeschreibungen für Simulation und Zielhardware. Die entwickelten Module sind in Ordnerstrukturen organsisiert. Die make - Anweisungen werden jeweils auf den Modulordner referenziert.   
![Workflow](doc/graphics/workflow.png]

### Anweisungen
- Kompilieren mit IVerilog => mingw32-make "Modul"
- Ausführen der Simulation (Testbench + GTK Wave) => mingw32-make wave "Modul"
- Build für Xilinx Zynq7000 (Ausführen build.tcl) => mingw32-make build
- Laden des Zynq7000 (Ausführen prog.tcl) => mingw32-make prog  

## Takt - Verteilung
Die Taktversorgung der physikalischen Schnittstelle ist ein extern zugeführter 600 MHz Takt über MMCM (Source) oder Taktleitung (Sink). Die Taktpufferung, repsektive Teilung erfolgt mit BUFIO (Direkte Taktversorgung IO - Primitiven) und BUFR (Regional). Der Link - Layer wird jeweils über globale Taktbuffer (BUFG) vom MMCM versorgt. Das Testsystem wird ebenfalls global über einen PLL in einer weiteren Taktdomäne versorgt. 
![Workflow](doc/graphics/clock_concept.png)

### Auflistung Taktversorgung
- Testcore => PLL 166 MHZ (BUFG)
- Transceiver - Link Layer => MMCM 120 MHZ (BUFG)
- Transceiver - Physical Layer => 600 MHZ (BUFIO) , 200 MHZ (BUFR), 120 MHZ (BUFR)

Die Taktquelle ist der Onboard - Clock des FPGA (GCLK), welcher direkt dem PLL zugeführt wird. Der MMCM wird vom PLL mit einem generierten 50 MHz Takt über LVDS versorgt. (Port FMC_CLKx)


### Elastic - Buffer
Die Datenübertragung von lokaler (BUFR) zur globalen (BUFG) Taktdomäne des Transceivers erfolgt über Elastische Buffer. Dieser ist in aktueller Ausführung aus einem Asynchronen FIFO mit Zusatzlogik für Lese- und Schreibbefehl zusammengebaut. Ziel des Buffers ist es, den Daten Füllstand mithilfe der Zu-, repsektive Abnahme von SKIP - Symbolen in der Mitte zu halten. Momentane implementierung nutzt nur SKIP - Symbole welche vom Packetgenerator am Ende einer Frameübertragung gesendet werden. Die Logik blockiert bei zu hohem Füllstand den Schreibzeiger wenn ein SKIP - Symbol am Eingang anliegt. Bei zu niedriegem Füllstand wird der Lesezeiger blockiert, wenn ein SKIP - Symbol am Ausgang anliegt. Diese Art der Implementierung erfordert eine dementsprechend grosse Speicherbreite, aufgrund fehlender SKIP - Symbolen bei übertragung längerer Nachrichten. Das führt zu hohen Latenzzeiten.

## Funktionsweise Link - Layer
Der Link - Layer wird unterteilt in einen Datengenerator und einem Datenprüfer. Der Generator baut die nachfolgend beschriebene Framestruktur auf welche Byteweise an den physikalischen - Layer übergeben wird. Die Prüfschaltung kontrolliert empfangenen Byte-Packete und stellt die Dateninformation zur Abholung durch den Transaction - Layer bereit.   
Der Datenrahmen wird mit K - Steuercodes der 8B10B - Kodierung bestimmt. 
- SLF (Start Link Frame) mit K28.0 (0x1C)
- SDF (Start Data Frame) mit K28.1 (0x3C)
- EOF (End of Frame) mit K28.2 (0x5C)
- SKP (Skip) mit K28.3 (0x7C)

Alle Frames werden zusammen mit einer Prüfsumme (CRC-8) gesendet, respektive validiert. Der Datentransfer erfolgt immer Byteweise. Datenbreiten die nicht dem Modulo 8 entsprechen, werden mit Zusatzbits erweitert, um eine Ganzzahlige Bytegrösse zu erreichen. (Datenbreite 34 Bits => 40 Bits) 

### DLLP (Data Link Layer Packet) - Frame
Wird für die Link - Kommunikation zwischen zwei Transceivern verwendet. Die Sender, respektive Empfängerlogik erlaubt eine variable Datenbreite. Für den aktuell vorliegenden Link - Controller ist eine breite von 16 Bit festgelegt.
![Workflow](doc/graphics/dllp_frame.png)

Für die Zustandsübermittlung werden nur zwei Bits des MSB Bytes verwendet. Das LSB - Byte dient zur übermittlung der Identifikationsnummer zur Verifizierung (ACK). Die Zustandsbits (c) werden den nachfolgenden Nachrichten zugeordnet.  

- 00 => Empfang nicht bereit (Empfangspuffer voll)
- 01 => Empfang bereit
- 10 => Ungültige Daten empfangen (Nack)
- 11 => Daten erfolgreich erhalten (Ack)

### TLP - Frame
Das Transaction Layer Packet beinhaltet zusätzliche Kopfdaten mit Angabe der Anzahl und einer Identifikationsnummer. Die Breite der Kopfinformation ist abhängig vom Parameter ID_WIDTH. Standartmässig ist der Bereich der Identifikationsnummer auf 0 - 15 festgelegt. Das entspricht jeweils der gleichen Anzahl möglicher hintereinanderfolgender TLP - Packete (0 - 15).
Die Kopfdaten benötigen in diesem Fall nur 1 Byte (4Bit + 4 Bit). Identifikationsnummern im Bereich 0 - 31 würde zu einer Kopfdatenbreite von 2 Bytes führen (5Bit + 5Bit) 

![Workflow](doc/graphics/tlp_frame.png)

Das Erhöhen des Nummernbereiches für die Identifikationsnummer macht dann Sinn, wenn der Sendepuffer jeweils immer mit mehr als 16 TLP - Packete nachgeladen wird. (Applikationsabhängig)

### Sender (Packet Generator) 
Der Packetgenerator wird zentral von einem Controller gesteuert. Dieser stellt die Weichen für den Datenfluss durch das steuern der Multiplexer. Zentral für die Funktionalität ist eine implementierte FIFO - Zeigerlogik für Bestätigte, respektive Fehlerhafte ID übertragungen im Controller. Das Senden von DLLP hat eine höhere Priorität als das Senden von TLP - Packeten. Der Transfer von TLP - Packeten muss vom Link - Manager freigegeben werden. (Erfolgt mit Steuerflags "Start" und "Stop")

![Workflow](doc/graphics/packet_generator.png)

Daten aus dem TLP - Buffer erhalten die jeweils nächste Verfügbare Identifikationsnummer des Zeigers für nicht bestätigter ID (NACK_PTR). Bei einer ID - Breichsbreite von 4 Bits können also maximal 16 TLP - Packete verschickt werden, bis ein weiteres Senden aufgrund fehlender Bestätigung blockiert wird. Kopfdatenzusammensetzung ist {Packet_Nummer, ID_Nummer}

Fallbeispiel 1:
- Im TLP Buffer liegt ein Datenpacket
- Die nächste ID ist 3
- Alle vorherigen Sendeaufträge sind bereits bestätigt

Die Kopfdaten des Transfers wären {4b0000, 4b0011} für 0 = 1 Datenpacket und ID 3. Der Zeiger für nicht bestätigte ID's wird um 1 erhöht. Neue Verfügbare Daten können sofort wieder gesendet werden.

Fallbeispiel 2:
- Im TLP Buffer liegen 4 Datenpackete
- Die nächste ID ist 3
- Alle vorherigen Sendeaufträge sind bereits bestätigt

Die Kopfdaten des Transfers wären {4b0011, 4b0011} für 3 = 4 Datenpacket und ID 3. Der Zeiger für nicht bestätigte ID's wird um 4 erhöht. Neue Verfügbare Daten können sofort wieder gesendet werden.

Fallbeispiel 3:
- Im TLP Buffer liegen 16 Datenpackete
- Die nächste ID ist 3
- Alle vorherigen Sendeaufträge sind bereits bestätigt

Die Kopfdaten des Transfers wären {4b1111, 4b0011} für 15 = 16 Datenpacket und ID 3. Der Zeiger für nicht bestätigte ID's wird um 16 erhöht. Neue Verfügbare Daten können nicht sofort wieder gesendet werden. Ein weiterer Transfer ist nur möglich, sobald mindestens eine Identifikationsnummer bestätigt wird. 

Fallbeispiel 4:
- Im TLP Buffer liegen 16 Datenpackete
- Die nächste ID ist 3
- Nicht alle vorherigen Sendeaufträge sind bestätigt

Die Kopfdaten des Transfers wären {4bxxxx, 4b0011} für xxxx = Soviele Datenpackete bis der Nack_Zeiger den Ack_Zeiger nicht überholt und ID 3.

### Replay Buffer
Das Schreiben in den Replay Buffer erfolgt mit der nicht bestätigten Identifikationsnummer. Die Speicherablage entspricht dem Identifikationsbereich. Das Widergeben gespeicherter Daten erfolgt mit dem Addresszeiger bestätigter ID's. Dieser wird während des Replay - Vorgangs auf den Wert der nicht bestätigten ID's inkrementiert. Ein Replay - Vorgang sendet also immer alle nicht bestätigten Datenpackete als "Multiframe".  
![Workflow](doc/graphics/replay_buffer.png)

### Byte - Splitter
Die Byteweise Ausgabe, respektive das zerlegten von TLP und DLLP - Daten erfolgt mit einer Register - Multiplexer Pipeline Struktur. Die Zusammensetzung ergibt sich aus Parametrierter Datenlänge für TLP und DLLP Packeten. Solange Daten im TLP - Buffer verfügbar sind, wird dieser kontinuierlich nachgeladen, sofern der Identifikationszeiger dies zulässt.   
![Workflow](doc/graphics/byte_splitter.png)


### Empfänger (Packet Checker)
Der Datenprüfer operiert ebenfalls mittels zentraler Steuerlogik. Eingehende DLLP und TLP's werden erkannt und nach erfolgreicher Datenprüfung (Frameaufbau, CRC) in die Empfangsbuffer geschrieben. Die Funktionalität der Steuereinheit in Bezug auf Auswertung von TLP's ist umfangreicher/koplexer als beim Packetgenerator. Aufgrund möglicher Multiframes müssen die TLP - Daten zwischengespeichert werden, bevor diese in die Endablage für den Zugriff des nächst höheren Layers geschrieben werden. TLP - Packete werden daher in zwei Prozessen geprüft. Im ersten werden TLP - Daten entsprechend der Parametrierten Datenlänge temporär abgelegt. Die Anzahl abgelegter Daten wird gezählt. Weiter werden die Transferinformationen mit Inhalt über Packetlänge und der Frameprüfung (CRC, Stop-Code) temporär abgelegt. (tr_info = {Gültigkeit (1Bit), Frame_Nummer (ID_WIDTH)}. Weiter werden die Kopfdaten des empfangenen TLP - Frames mitangefügt. Kopfdaten = {Frame_Nummer, Frame_ID} Das ergibt eine gesammte Prozessinformation von {Gültig, Frame_Nummer_Transfer, Frame_Nummer_Kopfdaten, ID_Nummer_Kopfdaten}
Basierend auf diesen Informationen werden die Temporären TLP - Daten in einem zweiten Prozess verworfen, oder übernommen. Die Ergebnisse aus dem zweiten Prüfprozess werden vom Link - Controller für den ACK/NACK Prozess verwendet. Resultat = {Gültig (1bit), ID}. Fehlgeschlagene Transfers führen zu einem ungültigen Resultat. Gültige Transfers führen je zu einem gültigen Resultat für jedes einzelen TLP - Datenpacket. 

![Workflow](doc/graphics/packet_checker.png)

Fallbeispiel 1:
- Empfang eines Multiframes mit 4 TLP's
- Identifikationsnummer ist 3 
- Keine Replay - Daten
- Transfer ist gültig

Es werden vier gültige Ergebnisse an den Link Controller gesendet. {1'b1, 4'b0011}, {1'b1, 4'b0100}, {1'b1, 4'b0101}, {1'b1, 4'b0110} => {Gültig, 3}, {Gültig, 4}....
Der Link Controller sendet vier mal ein Akzeptiert (ACK) an die Gegenstation. Die nächsten vier Temporären TLP - Daten werden in den Empfangsbuffer geschrieben.

Fallbeispiel 2:
- Empfang eines Multiframes mit 4 TLP's
- Identifikationsnummer ist 3 
- Keine Replay - Daten
- Transfer ist ungültig

Es wird ein Ergebniss an den Link - Controller übergeben. {1'b0, 4'bxxxx} Die Identifikationsnummer ist nicht relevant. (Kann ungültig sein => Kein Rückschluss möglich!). Der Link - Controller sendet ein Nicht Akzeptiert (NACK) an die Gegenstation. Alle Temporären Daten werden verworfen. Die nächsten vier Temporären TLP - Daten werden verworfen.

Fallbeispiel 3:
- Empfang eines Multiframes mit 4 TLP's
- Identifikationsnummer ist 3 
- Replay - Daten
- Transfer ist gültig

Es werden vier gültige Ergebnisse an den Link Controller gesendet. {1'b1, 4'b0011}, {1'b1, 4'b0100}, {1'b1, 4'b0101}, {1'b1, 4'b0110} => {Gültig, 3}, {Gültig, 4}....
Der Link Controller sendet vier mal ein Akzeptiert (ACK) an die Gegenstation. Temporäre TLP - Daten werden nur in die Endablage geschrieben, falls diese noch nicht vorgängig abgelegt wurden.

#### Fehlerfällte für ungültigen Transfer (NACK)
- Fehlerhafte CRC Prüfung
- Stop - Code nicht erkannt
- Kontrollierte Packetlänge führt zu einem Überlauf (Aufgrund Fehlerhaftem Stop - Code)
- Die Identifikationsnummer in den Kopfdaten ist grösse als die erwartete Identifikationsnummer

#### Wann wird ein ACK - Signal gesendet ?
- Wenn der Transfer gültig ist
- Wenn die Identifikationsnummer in den Kopfdaten kleiner oder gleich der erwarteten Identifikationsnummer ist

#### Wann werden TLP's in die Endablage übernommen ?
- Wenn der Transfer gültig ist
- Wenn die Identifikationsnummer genau der erwarteten Identifikationsnummer entspricht

#### Hinweise
- Der Packetprüfen kann theoretisch mit eingefügten (Zwischen den Datenbytes) SKIP - Symbolen in der Nachricht umgehen (Nicht getestet)


### Link - Controller
Dieser steuert die Transmitter und Receiver Schaltung und wertet deren Statussignale aus. Nach der Initialisierung erfolgt die Bearbeitung mit einem Sprungverteiler, welcher vier "Processe" repetierend ausführt.

Prozesse:
- Status - Update => Sendet Status DLLP mit Bereitschaftsbit
- Lesen DLLP => Auswertung empfangener DLLP - Daten
- Lesen Transfer-Ergebnisse => Senden von NACK / ACK - DLLP
- Status Transmitter => Auswertung ACK / NACK Timeout

#### Wann wird ein Replay Ausgeführt ?
- Ein NACK - DLLP wurde empfangen
- Timeout beim erwarteten (offener Sendeauftrag) Empfang von NACK/ACK - DLLP

#### Wann wird das Senden von TLP's blockiert ?
- Wenn der Empfangsbuffer der Gegenstation nicht bereit ist (FIFO voll)
- Wenn die Initialisierung der Gegenstation nicht abgeschlossen oder Fehlerhaft ist.

#### Hinweise
- Die Implementierte Zählerbreite für Initialisierungs - und Timeoutzeiten muss auf die Applikation angepasst sein. (Nachträgliche Anpassungen sind unter Umständen nötig)
- Das Status - DLLP wird sowohl bei Zustandsänderungen der Bereitsschaft als auch periodisch gesendet (Das führt auch bei DLLP - Verlust dazu, dass der aktualisierte Status am Empfänger ankommt)
- Ein Verbindungsstatus ist aktuell nicht implementiert. (Möglichkeit aufgrund periodischem Statusupdate, wäre ein Timeout für empfangene DLLP's zu implementieren)
- Ein Rücksprung in die Initialisierungsphase ist nicht implementiert. Umsetzung ist Applikationsabhängig. Ein Reinitialiseren ist nur möglich, wenn beide Transceiver über den Initialisierungszeitraum ein SKIP - Symbol senden. Die jeweilige Gegenstation muss also über einen Kommunikations - Timeout in den Initialisierungsschritt gezwungen werden. 

## Funktionsweise Physical - Layer


### Sender

### Empfänger


#### Gearbox

#### Wortausrichtung

#### Initiale Tab - Kalibration

#### Überwachung (Monitoring) und Justage der Leitungsverzögerung  



## Testsystem (Test - Core)

### Architektur


### Kommando 

## Test und Validierung

### Hardware

### Testbench


### Python

## Mögliche Optimierungen
- Erweiterung / Anpassen des Link - Controllers auf die entsprechende Endapplikation
- Implementierung von Statuswörtern ggf. mit zusätzlichem FIFO
- Effizienteres Design der CDC - Elastic Buffer's zur Reduzierung von Latenzzeiten (Empfohlen!)





