import serial
import time
import sys
import struct

# --- PARAMÈTRES À VÉRIFIER ---
PORT = 'COM3'
BAUD_RATE = 500000
CHEMIN_FICHIER = r"C:\Users\guill\Desktop\_prototype_boucle_courant_seulement_166.csv"
# -----------------------------

print(f"Tentative de connexion à l'Arduino sur {PORT}...")

try:
    arduino = serial.Serial(PORT, BAUD_RATE, timeout=1)
    time.sleep(2)
    arduino.reset_input_buffer()
    print("Connexion réussie !\n")

    with open(CHEMIN_FICHIER, "w", encoding="utf-8") as fichier:
        fichier.write("Temps(us),Consigne,A7_Bits\n")
        print(f"Fichier créé : {CHEMIN_FICHIER}")

        print("Démarrage du système (Envoi de 'S')...")
        arduino.write(b'S')

        print("\n*** ENREGISTREMENT EN COURS ***")
        print("-> Appuyez sur Ctrl+C dans ce terminal pour arrêter le test et fermer le fichier.\n")

        buffer = bytearray()

        while True:
            bloc = arduino.read(arduino.in_waiting or 256)
            if bloc:
                buffer.extend(bloc)

                while len(buffer) >= 8:
                    paquet = buffer[:8]
                    del buffer[:8]

                    temps_us, consigne, a7_bits = struct.unpack('<IHH', paquet)
                    fichier.write(f"{temps_us},{consigne},{a7_bits}\n")

except KeyboardInterrupt:
    print("\n\nArrêt manuel détecté (Ctrl+C).")

except serial.SerialException:
    print(f"\nERREUR : Impossible de se connecter au port {PORT}.")
    print("-> Le Moniteur Série de l'Arduino est-il resté ouvert ? FERMEZ-LE !")
    sys.exit()

finally:
    if 'arduino' in locals() and arduino.is_open:
        print("Arrêt de l'Arduino (Envoi de 'A')...")
        arduino.write(b'A')
        time.sleep(0.5)
        arduino.close()
        print(f"Port série fermé. Les données sont sauvegardées dans {CHEMIN_FICHIER}.")