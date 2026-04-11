#pragma once
#include <Arduino.h>
#include "buffer_circulaire.h"
#include "etat_systeme.h"


// Mode asservissement
// PIDF position: KP_POS, KI_POS, KD_POS, TAUF_POS
// PI courant: KP_COU, KI_COU
#ifdef P3

volatile uint16_t consignePosition = 243;     // consigne de position
const float referenceCou = 512.0f;            // référence du courant


// RÉGLAGES UTILISATEUR
// Boucle externe: 50 Hz  -> Ts = 0.02 s
// Boucle interne: 500 Hz -> Ts = 0.002 s
const float TS_POS = 0.02f;   // s
const float TS_COU = 0.002f;  // s

// Gains boucle externe position
volatile float KP_POS   = 2.325f;
volatile float KI_POS   = -27.5f;
volatile float KD_POS   = -0.207f;
volatile float TAUF_POS = 0.09f;

// Gains boucle interne courant
volatile float KP_COU = -0.575f;
volatile float KI_COU = -325.0f;

// PIDF externe :
// Coefficients discrets calculés automatiquement avec Tustin
volatile float POS_A1 = (4.0f * TAUF_POS) / (TS_POS + 2.0f * TAUF_POS);
volatile float POS_A2 = (TS_POS - 2.0f * TAUF_POS) / (TS_POS + 2.0f * TAUF_POS);

volatile float POS_B0 = (4.0f * KD_POS + KI_POS * TS_POS * TS_POS + 2.0f * KI_POS * TS_POS * TAUF_POS +
                      2.0f * KP_POS * TS_POS + 4.0f * KP_POS * TAUF_POS) /
                     (2.0f * TS_POS + 4.0f * TAUF_POS);

volatile float POS_B1 = (-8.0f * KD_POS + 2.0f * KI_POS * TS_POS * TS_POS - 8.0f * KP_POS * TAUF_POS) /
                     (2.0f * TS_POS + 4.0f * TAUF_POS);

volatile float POS_B2 = (4.0f * KD_POS + KI_POS * TS_POS * TS_POS - 2.0f * KI_POS * TS_POS * TAUF_POS -
                      2.0f * KP_POS * TS_POS + 4.0f * KP_POS * TAUF_POS) /
                     (2.0f * TS_POS + 4.0f * TAUF_POS);

// PI interne : C(s) = Kp + Ki/s
volatile float COU_B0 = KP_COU + 0.5f * KI_COU * TS_COU;
volatile float COU_B1 = -KP_COU + 0.5f * KI_COU * TS_COU;

volatile float kp_P;
volatile float ki_P;
volatile float kd_P;
volatile float kp_C;
volatile float ki_C;


// Boucle externe
volatile float erreurPreced2Pos = 0.0f;
volatile float erreurPrecedPos  = 0.0f;
volatile float erreurActuPos    = 0.0f;

volatile float sortieActuPos    = 0.0f;
volatile float sortiePrecedPos  = 0.0f;
volatile float sortiePreced2Pos = 0.0f;

volatile uint8_t compteurExt = 0;

// Boucle interne
volatile float erreurActuCou   = 0.0f;
volatile float erreurPrecedCou = 0.0f;

volatile float sortieActuCou = 0.0f;

// anti-windup
volatile float sortieFinalCou = 0.0f;
volatile float sortieSatCou   = 0.0f;
volatile float sortiePrecedCou = 0.0f;

volatile uint8_t compteurInt = 0;
volatile float moyenneInt = 0.0f;
volatile uint32_t sommeInt = 0;

// Commande envoyé au PWM (0 à 1023)
volatile float valeurDutyFloat = 0.0f;
volatile uint16_t valeurDuty = 0;

// Flag pour prendre la bonne valeur d'ADC
volatile bool bonneValADC = 0;

// État global du système
volatile uint8_t canal = 0;
volatile bool asservissement = false;
volatile bool acquisition = false;
volatile uint16_t adcVal = 0;

bool pret;
uint16_t bitsADCTransmMasse;
uint16_t bitsADCTransmCapt;

String ligne = "";

BufferCirculaire bufferCapteur;
BufferCirculaire bufferMasse;

// Utilisé pour allumer l'indicateur de stabilité'
bool stable = 0;

// Hard-reset de toutes les mémoires des filtres et PID
static inline void resetEtatAsservissementComplet() {
  erreurPreced2Pos = 0.0f;
  erreurPrecedPos  = 0.0f;
  erreurActuPos    = 0.0f;
  sortieActuPos    = 0.0f;
  sortiePrecedPos  = 0.0f;
  sortiePreced2Pos = 0.0f;
  compteurExt      = 0;

  erreurActuCou    = 0.0f;
  erreurPrecedCou  = 0.0f;
  sortieActuCou    = 0.0f;
  sortieFinalCou   = 0.0f;
  sortieSatCou     = 0.0f;
  sortiePrecedCou  = 0.0f;
  compteurInt      = 0;

  moyenneInt       = 0.0f;
  sommeInt         = 0;
  valeurDutyFloat  = 0.0f;
  valeurDuty       = 512;

  bonneValADC      = 0;
  canal            = 0;
}

// Parsing de la communication série
int SerialInterface() {
  char comByte1 = 0;
  char comByte2 = 0;
  bool commandGood = 0;

  if (Serial.available() > 0) {
    comByte1 = Serial.read();

    // DEBUG très important
    Serial.print(F("[ARDUINO] recu ascii="));
    Serial.print((int)comByte1);
    Serial.print(F(" char='"));
    Serial.print(comByte1);
    Serial.println(F("'"));

    switch (comByte1) {

      //Quand activé alors instable
      case 'E': {
        stable = false;
        digitalWrite(8, LOW);
        break;
      }

      //quand activé alors stable
      case 'D': {
        stable = true;
        digitalWrite(8, HIGH);
        
        break;
      }

      // Mise à jour des gains du PI courant
      case 'I': {
        Serial.println("ALLO");
        // On lit jusqu'au saut de ligne \n envoyé par Python
        ligne = Serial.readStringUntil('\n');

        Serial.print("LIGNE RECUE: [");
        Serial.print(ligne);
        Serial.println("]");

        // Extraction des valeurs séparées par des virgules
        int comma1 = ligne.indexOf(',');
        int comma2 = ligne.indexOf(',', comma1 + 1);

        if (comma1 >= 0 && comma2 >= 0) {
          String kp_str = ligne.substring(comma1 + 1, comma2);
          String ki_str = ligne.substring(comma2 + 1);

          float kp_C = kp_str.toFloat();
          float ki_C = ki_str.toFloat();

          Serial.print("KP=");
          Serial.println(kp_C);
          Serial.print("KI=");
          Serial.println(ki_C);

          // Ici on coupe les interruptions pendant qu'on modifie les variables
          noInterrupts();
          KP_COU = kp_C;
          KI_COU = ki_C;

          // Recalcul de Tustin
          COU_B0 = KP_COU + 0.5f * KI_COU * TS_COU;
          COU_B1 = -KP_COU + 0.5f * KI_COU * TS_COU;
          interrupts();

          Serial.println("I_OK");
          commandGood = 1;
        } 
        else {
          Serial.println("I_ERREUR");
        }
        break;
      }

      // Mise à jour des gains du PIDF position
      case 'P': {
          ligne = Serial.readStringUntil('\n');

          Serial.print("LIGNE RECUE: [");
          Serial.print(ligne);
          Serial.println("]");

          int comma1 = ligne.indexOf(',');
          int comma2 = ligne.indexOf(',', comma1 + 1);
          int comma3 = ligne.indexOf(',', comma2 + 1);

          if (comma1 >= 0 && comma2 >= 0 && comma3 >= 0) {
              String kp_str = ligne.substring(comma1 + 1, comma2);
              String ki_str = ligne.substring(comma2 + 1, comma3);
              String kd_str = ligne.substring(comma3 + 1);

              // Nettoyage au cas où Python enverrait des espaces
              kp_str.trim();
              ki_str.trim();
              kd_str.trim();

              float kp_P = kp_str.toFloat();
              float ki_P = ki_str.toFloat();
              float kd_P = kd_str.toFloat();

              Serial.print("KP=");
              Serial.println(kp_P);
              Serial.print("KI=");
              Serial.println(ki_P);
              Serial.print("KD=");
              Serial.println(kd_P);

              // Zone critique pour le recalcul mathématique
              noInterrupts();
              KP_POS = kp_P;
              KI_POS = ki_P;
              KD_POS = kd_P;

              POS_A1 = (4.0f * TAUF_POS) / (TS_POS + 2.0f * TAUF_POS);
              POS_A2 = (TS_POS - 2.0f * TAUF_POS) / (TS_POS + 2.0f * TAUF_POS);

              POS_B0 = (4.0f * KD_POS + KI_POS * TS_POS * TS_POS + 2.0f * KI_POS * TS_POS * TAUF_POS +
                        2.0f * KP_POS * TS_POS + 4.0f * KP_POS * TAUF_POS) /
                      (2.0f * TS_POS + 4.0f * TAUF_POS);

              POS_B1 = (-8.0f * KD_POS + 2.0f * KI_POS * TS_POS * TS_POS - 8.0f * KP_POS * TAUF_POS) /
                      (2.0f * TS_POS + 4.0f * TAUF_POS);

              POS_B2 = (4.0f * KD_POS + KI_POS * TS_POS * TS_POS - 2.0f * KI_POS * TS_POS * TAUF_POS -
                        2.0f * KP_POS * TS_POS + 4.0f * KP_POS * TAUF_POS) /
                      (2.0f * TS_POS + 4.0f * TAUF_POS);

              interrupts();

              Serial.println("P_OK");
              commandGood = 1;
          }
          else {
              Serial.println("P_ERREUR");
          }

          break;
      }


      // Changement de la consigne (Position)
      case 'C':
        while (Serial.available() < 2) {}
        {
          uint8_t lsb = Serial.read();
          uint8_t msb = Serial.read();
          // Reconstruction de la valeur sur 16 bits
          consignePosition = lsb | (msb << 8);
        }

        Serial.print(F("[ARDUINO] consignePosition="));
        Serial.println(consignePosition);
        commandGood = 1;
        break;

        // Mode Acquisition Pure (Pas d'asservissement)
      case 'X':
        noInterrupts();

        bufferCapteur.clear();
        bufferMasse.clear();
        resetEtatAsservissementComplet();

        // Réglage du multiplexeur ADC
        ADMUX = (ADMUX & 0xE0) | (canal & 0x0F);
        // Activation du Timer3 pour trigger l'ADC
        TIMSK3 |= (1 << OCIE3A);

        OCR1B = 512; // PWM au neutre
        asservissement = false;
        acquisition = true;

        interrupts();

        Serial.println(F("[ARDUINO] commande X OK -> acquisition simple demarree"));
        commandGood = 1;
        break;

      // Arrêt de l'Acquisition
      case 'Y':
        noInterrupts();

        asservissement = false;
        acquisition = false;
        resetEtatAsservissementComplet();
        OCR1B = 512;
        ADMUX = (ADMUX & 0xE0) | (canal & 0x0F);
        // On coupe le Timer3
        TIMSK3 &= ~(1 << OCIE3A);

        interrupts();

        Serial.println(F("[ARDUINO] commande Y OK -> acquisition simple stoppee"));
        commandGood = 1;
        break;

      // Mode Asservissement Complet
      case 'S':
        if (!asservissement) {
          Serial.println("ALLO");
          noInterrupts();

          bufferMasse.clear();
          bufferCapteur.clear();
          resetEtatAsservissementComplet();

          OCR1B = 512;

          ADMUX = (ADMUX & 0xE0) | (canal & 0x0F);

          acquisition = true;
          asservissement = true;
          TIMSK3 |= (1 << OCIE3A);

          interrupts();

          Serial.println(F("[ARDUINO] commande S OK -> asservissement demarre"));
        } else {
          Serial.println(F("[ARDUINO] commande S recue mais asservissement deja actif"));
        }

        commandGood = 1;
        break;

      // Arrêt de l'Asservissement
      case 'A':
        if (asservissement) {
          noInterrupts();

          asservissement = false;
          acquisition = false;
          resetEtatAsservissementComplet();

          OCR1B = 512;

          ADMUX = (ADMUX & 0xE0) | (canal & 0x0F);
          TIMSK3 &= ~(1 << OCIE3A);

          interrupts();

          Serial.println(F("[ARDUINO] commande A OK -> asservissement stoppe"));
        } else {
          Serial.println(F("[ARDUINO] commande A recue mais asservissement deja inactif"));
        }

        commandGood = 1;
        break;

      default:
        Serial.print(F("[ARDUINO] commande inconnue: "));
        Serial.print((int)comByte1);
        Serial.print(F(" ('"));
        Serial.print(comByte1);
        Serial.println(F("')"));
        break;
    }

    // Vide le buffer des caractères qui auraient pu s'empiler
    while (Serial.available()) {
      comByte2 = Serial.read();
      Serial.print(F("[ARDUINO] flush byte ascii="));
      Serial.println((int)comByte2);
    }

    return 1 + commandGood;
  }

  return 0;
}

// Fonction d'interruption du timer3
ISR(TIMER3_COMPA_vect) {
  if (!(ADCSRA & (1 << ADSC))) {
    ADCSRA |= (1 << ADSC);
  }
}

// Fonction d'interruption de l'ADC
// Cette fonction doit s'exécuter le plus vite possible pour ne pas ralentir le microcontrôleur
ISR(ADC_vect) {
  if (!acquisition) {
    return;
  }

  adcVal = ADC;

  // Boucle de position sur A0
  if (canal == 0) {
    if (bonneValADC) {
      bufferCapteur.push(adcVal);
      compteurExt++;
    }

    if (asservissement) {
      // 12kHz / 2 (A0/A7) / 2 (1 lecture jetée) = 3kHz, puis /60 = 50 Hz
      // On exécute le PIDF seulement tous les 60 coups (50 Hz)
      if (compteurExt >= 60 && bonneValADC) {
        // Calcul de l'erreur (E = Consigne - Mesure)
        erreurActuPos = (float)((int)consignePosition - (int)adcVal);

        // PIDF discret (Tustin)
        sortieActuPos =
            POS_A1 * sortiePrecedPos +
            POS_A2 * sortiePreced2Pos +
            POS_B0 * erreurActuPos +
            POS_B1 * erreurPrecedPos +
            POS_B2 * erreurPreced2Pos;

        // Saturation : on borne la sortie de la boucle externe pour 
        // ne pas demander un courant impossible à la boucle interne
        if (sortieActuPos > 512.0f) {
          sortieActuPos = 512.0f;
        }
        if (sortieActuPos < -511.0f) {
          sortieActuPos = -511.0f;
        }

        // Mise à jour des mémoires
        erreurPreced2Pos = erreurPrecedPos;
        erreurPrecedPos  = erreurActuPos;
        sortiePreced2Pos = sortiePrecedPos;
        sortiePrecedPos  = sortieActuPos;

        compteurExt = 0;
      }
    }

    // Bascule (Toggle) vers le canal 7 pour le prochain coup d'horloge
    if (bonneValADC) {
      bonneValADC = 0;
      canal = 7;
    } else {
      bonneValADC = 1;
      canal = 0;
    }
  } else { // Boucle interne sur A7
    if (bonneValADC) {
      bufferMasse.push(adcVal);
      compteurInt++;
    }

    if (asservissement) {
      // On exécute le PI tous les 6 coups (500 Hz)
      if (compteurInt >= 6 && bonneValADC) {
        erreurActuCou = (referenceCou + sortieActuPos) - (float)adcVal;

        // PI discret (Tustin)
        sortieActuCou = sortiePrecedCou + COU_B0 * erreurActuCou + COU_B1 * erreurPrecedCou;

        // Saturation + anti-windup
        sortieSatCou = sortieActuCou;
        if (sortieActuCou > 512.0f) {
          sortieSatCou = 512.0f;
        }
        if (sortieActuCou < -511.0f) {
          sortieSatCou = -511.0f;
        }

        // Si on est saturé et que l'erreur pousse encore dans la direction de la saturation, on gèle la mémoire
        if ((sortieActuCou > 512.0f && erreurActuCou > 0.0f) ||
            (sortieActuCou < -511.0f && erreurActuCou < 0.0f)) {
          sortieFinalCou  = sortieSatCou;
          sortiePrecedCou = sortieSatCou;
        } else {
          sortieFinalCou  = sortieSatCou;
          sortiePrecedCou = sortieActuCou;
        }

        // Conversion mathématique vers commande physique (PWM)
        valeurDutyFloat = 512.0f - sortieFinalCou;
        if (valeurDutyFloat < 0.0f) {
          valeurDutyFloat = 0.0f;
        }
        if (valeurDutyFloat > 1023.0f) {
          valeurDutyFloat = 1023.0f;
        }

        valeurDuty = uint16_t(valeurDutyFloat);
        // Application du PWM sur le registre matériel (Timer1)
        OCR1B = valeurDuty;

        erreurPrecedCou = erreurActuCou;
        compteurInt = 0;
      }
    }

    if (bonneValADC) {
      bonneValADC = 0;
      canal = 0;
    } else {
      bonneValADC = 1;
      canal = 7;
    }
  }

  // Application matérielle du changement de canal au multiplexeur
  ADMUX = (ADMUX & 0xE0) | (canal & 0x0F);
}

void setup() {
  Serial.begin(500000); // Vitesse pour évacuer les données à 3kHz
  pinMode(12, OUTPUT);
  pinMode(8, OUTPUT);

  // Initialisation de l'ADC
  ADCSRA = 0;
  ADCSRA |= (1 << ADEN) | (1 << ADIE) | (1 << ADPS1) | (1 << ADPS2);

  ADMUX = 0;
  ADMUX |= (1 << REFS0);

  // Initialisation du Timer1 (PWM)
  noInterrupts();
  TCCR1A = 0;
  TCCR1B = 0;
  TCCR1A |= (1 << WGM10) | (1 << WGM11) | (1 << COM1B1);
  TCCR1B |= (1 << WGM12) | (1 << CS10);
  OCR1B = 512;
  interrupts();

  // Initialisation du Timer3 (fréquence échantillonnage des ADCs)
  noInterrupts();
  TCCR3A = 0;
  TCCR3B = 0;
  TCCR3B |= (1 << CS30) | (1 << WGM32);
  OCR3A = 1332;  // 12 kHz
  interrupts();
}

void loop() {
  // La loop sert à gérer les tâches lentes pendants que les interruptions matérielle gèrent l'asservissement
  SerialInterface();

  if (acquisition) {
    // Évacuation du buffer de courant (A7)
    noInterrupts();
    pret = bufferMasse.pop(bitsADCTransmMasse);
    interrupts();

    if (pret) {
      Serial.write((uint8_t)7);
      Serial.write((uint8_t)(bitsADCTransmMasse & 0xFF));
      Serial.write((uint8_t)((bitsADCTransmMasse & 0x0300) >> 8));
    }

    // Évacuation du buffer de position
    noInterrupts();
    pret = bufferCapteur.pop(bitsADCTransmCapt);
    interrupts();

    if (pret) {
      Serial.write((uint8_t)0);
      Serial.write((uint8_t)(bitsADCTransmCapt & 0xFF));
      Serial.write((uint8_t)((bitsADCTransmCapt & 0x0300) >> 8));
    }
  }
}

#endif