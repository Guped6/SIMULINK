import time
import serial
import sys
import struct

# --- PARAMÈTRES À VÉRIFIER ---
PORT = 'COM3'
BAUD_RATE = 500000
CHEMIN_FICHIER = r"C:\Users\guill\Desktop\prototype_test_position_dynamique_100gtest.csv"
# -----------------------------

print(f"Connexion à l'Arduino sur {PORT}...")

try:
    arduino = serial.Serial(PORT, BAUD_RATE, timeout=1)

    time.sleep(2)
    arduino.reset_input_buffer()
    print("Connexion réussie.\n")

    with open(CHEMIN_FICHIER, "w", encoding="utf-8") as fichier:
        fichier.write("Temps(us),Consigne_Pos,Mesure_Pos\n")
        print(f"Fichier créé avec succès : {CHEMIN_FICHIER}")

        print("Démarrage du test dynamique (Envoi de 'S')...")
        arduino.write(b'S')

        print("Récolte des données en cours...")
        print("-> Appuyez sur Ctrl+C pour arrêter le test.\n")

        buffer = bytearray()

        while True:
            bloc = arduino.read(arduino.in_waiting or 256)
            if bloc:
                buffer.extend(bloc)

                while len(buffer) >= 8:
                    paquet = buffer[:8]
                    del buffer[:8]

                    temps_us, consigne_pos, mesure_pos = struct.unpack('<IHH', paquet)
                    fichier.write(f"{temps_us},{consigne_pos},{mesure_pos}\n")

except KeyboardInterrupt:
    print("\nArrêt manuel détecté (Ctrl+C).")

except serial.SerialException:
    print(f"ERREUR : Impossible de se connecter à {PORT}. Le Moniteur Série est-il resté ouvert ?")
    sys.exit()

finally:
    if 'arduino' in locals() and arduino.is_open:
        print("Arrêt de sécurité de l'aimant (Envoi de 'A')...")
        arduino.write(b'A')
        time.sleep(0.5)
        arduino.close()
        print(f"Port série fermé. Les données sont sauvegardées dans {CHEMIN_FICHIER}.")