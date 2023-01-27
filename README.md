# transcribe
transcription@home with and for fyyd.de

ACHTUNG! Das hier ist nicht ready to go, wenn auf Deinem Rechner/Server nicht schon vorab einige Dinge installiert und lauffähig sind.
Das ist vor allem eine lauffähige Entwicklungsumgebung, weil die eigentliche Software, die das transkribieren übernimmt erst noch compiliert werden muss.
Dafür kann ich keinen Support leisten, also solltest Du wissen, wo links+rechts ist, schließlich ist das ein Beta-Test :)

Die Scripte sind auf macOS und Ubuntu getestet, sollten also soweit keine Probleme bereiten. 
Aktuell ist das alles noch ohne dauerhaftes Transkribieren angelegt. Du startest das Skript und es wird transkribiert, bis nichts mehr da ist. Dann endet die Software und startet erst wieder, wenn Du das Script noch einmal startest. Das wird sich aber noch ändern... irgendwann :)

Darüber hinaus müssen bereits installiert sein:

ffmpeg
curl
git
jq
bc

Benötigt wird auch ein accesstoken für fyyd (bzw die API). Das kannst Du Dir unter

https://fyyd.de/dev/app/

abholen. Erstelle eine neue App (Name egal) und trage eine Beschreibung und die zwei URLs ein (auch hier: völlig egal).
Dann drücke auf den roten Button "regenerate client credentials" und kopiere das Token rechts unten ("user access token FOR YOU").

Wechsel auf der Kommandozeile in den Ordner dieses repos und starte setup.sh. Entweder mit ./setup.sh oder /bin/bash setup.sh.

Das Script checkt jetzt, ob ffmpeg, curl und git da sind und lädt dann das repo von [whisper.cpp](https://github.com/ggerganov/whisper.cpp) herunter und compiliert es.

Danach wirst Du gefragt, wieviele Threads Du zur Verfügung stellen möchtest. Das ist Deine Entscheidung, aber die Transkription wird mit sehr niedriger
Prio gestartet, sodass es die Performance Deines Rechners nicht sonderlich stören sollte. Du kannst das später in der fyyd.cfg auch wieder ändern.

Danach wirst Du nach dem Token gefragt. Gib's ein und fertig.

Dann startet ein Test. Es wird eine 5min kurze Audiodatei von mir transkribiert. Aus dem Test folgt dann eine Empfehlung, ob das überhaupt lohnt :)

Wenn alles parat ist, kannst Du mal die transcribe.sh starten und schauen, was passiert...

Unterbrechung mit CTRL+C ist jederzeit möglich, dann wird fyyd signalisiert, dass die Transkription abgebrochen wurde. Oder Du legst im Ordner eine
Datei namens .fyyd-stop an, dann wird nach der Transkription gestoppt.

Und jetzt: los! :)