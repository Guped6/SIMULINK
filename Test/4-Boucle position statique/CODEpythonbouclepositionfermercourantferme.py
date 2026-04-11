import time
import serial

# --- PARAMÈTRES À VÉRIFIER ---
PORT = 'COM3' 
BAUD_RATE = 500000
CHEMIN_FICHIER = r"C:\Users\guill\Desktop\test_position_echelon243_avecmasse50g.csv"
# -----------------------------

print(f"Connexion à l'Arduino sur {PORT}...")

try:
    arduino = serial.Serial(PORT, BAUD_RATE, timeout=1)
    
    # On donne 2 secondes à l'Arduino pour faire son reset
    time.sleep(2)
    arduino.reset_input_buffer()
    
    with open(CHEMIN_FICHIER, "w", encoding="utf-8") as fichier:
        print(f"Fichier créé avec succès : {CHEMIN_FICHIER}")
        
        # On écrit l'en-tête du CSV directement dans le fichier
        fichier.write("Temps(s),Consigne_Pos,Mesure_Pos\n")
        
        # On envoie la commande 'S' pour démarrer l'asservissement (Ce qui lance l'échelon)
        print("Démarrage du test d'échelon (Envoi de la commande 'S')...")
        arduino.write(b'S')
        
        print("Récolte des données en cours... (Durée estimée : 4 secondes)")
        
        while True:
            if arduino.in_waiting > 0:
                ligne_brute = arduino.readline()
                try:
                    ligne_texte = ligne_brute.decode('utf-8').strip()
                except UnicodeDecodeError:
                    continue # Ignore les caractères parasites au démarrage
                
                # Si l'Arduino a fini ses 200 ticks
                if "FIN_DU_TEST" in ligne_texte:
                    print("\nTest terminé ! L'Arduino a signalé la fin.")
                    
                    # On envoie la commande 'A' pour arrêter l'électro-aimant
                    print("Arrêt de sécurité de l'aimant (Envoi de la commande 'A')...")
                    arduino.write(b'A')
                    time.sleep(0.5) 
                    break
                
                # Écriture dans le terminal et dans le CSV
                # On s'assure de ne pas écrire les messages de debug dans le fichier CSV
                if ligne_texte and not ligne_texte.startswith("[ARDUINO]"):
                    print(ligne_texte)
                    fichier.write(ligne_texte + "\n")
                    
    print("\nFichier CSV fermé et sauvegardé avec succès sur le bureau.")
    
except serial.SerialException:
    print(f"ERREUR : Impossible de se connecter à {PORT}. Le Moniteur Série est-il resté ouvert ?")
finally:
    if 'arduino' in locals() and arduino.is_open:
        arduino.close()