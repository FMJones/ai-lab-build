# ai-lab-build

Ricetta di compilazione degli installer di AI-Lab per macOS, Windows e Linux.
Non contiene codice del programma: solo i workflow di GitHub Actions.

- `Cerca novità`: ogni mezz'ora controlla se c'è un nuovo tag o commit da costruire.
- `Build installer`: compila i tre installer e li allega alla release del repository dei sorgenti.
- `Pulizia`: ogni lunedì toglie esecuzioni, Artifacts e pacchetti vecchi.
