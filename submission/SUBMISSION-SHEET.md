# Fiche de soumission — Riskelo US 1.0

Tout ce que demande App Store Connect, dans l'ordre où il le demande.

**Les consignes sont en français, les textes à coller sont en anglais.** Chaque
bloc encadré se colle tel quel dans le site d'Apple, sans le retoucher : il est
écrit pour le marché américain et compté contre la limite du champ. Ce qui
reste à décider est marqué **à décider** ; ce qui ferait refuser la soumission
est marqué **bloquant**.

C'est l'application américaine. La française a son propre dossier et son propre
enregistrement ; les deux ne partagent qu'un ancêtre.

---

## 0. Ce qui reste entre ceci et une soumission

À lire avant le reste : la suite du document suppose ces points réglés.

1. **Fait — le site est en ligne.** `docs/` porte quatre pages anglaises,
   GitHub Pages les sert depuis `main` ▸ `/docs`, et les quatre adresses
   répondent 200. Les trois que l'application ouvre fonctionnent depuis
   l'application. Section 2.
2. **L'application ne déclare toujours aucune adresse d'assistance.**
   `ManualView` publie un site, une page de confidentialité et une page de
   conditions — les trois liens de l'accueil et des réglages — mais rien pour
   l'assistance. `support.html` existe pour le champ Support URL exigé par
   Apple ; le câbler dans l'application est facultatif. Section 2.
3. **bloquant — Les captures d'écran sont celles de l'app française.** Les
   dix-huit fichiers de `soumission/captures/` montrent du texte français sur
   chaque panneau. Inutilisables pour une fiche anglaise. Section 7.
4. **à décider — Le nom sur l'App Store.** Les noms d'app sont uniques sur tout
   le magasin : la française et celle-ci ne peuvent pas s'appeler toutes les
   deux « Riskelo ». Section 4.

---

## 1. Les identifiants

| Champ | Valeur |
|---|---|
| Nom de l'app | `Riskelo US` — **à décider**, voir section 4 |
| Identifiant du bundle | `com.oulhen.riskelo.us` |
| Équipe | `38DQ8FW23J` |
| SKU (interne, invisible du public, jamais réutilisable) | `riskelo-us-2026` |
| Identifiant Apple de l'app | attribué par App Store Connect à la création |
| Langue principale | Anglais (États-Unis) |
| Version | `1.0` |
| Build | `1` |
| Plateformes | iOS et macOS (une seule cible, deux plateformes sur la fiche) |
| Version minimale | iOS 17.0 · macOS 14.0 |
| Appareils | iPhone et iPad (`TARGETED_DEVICE_FAMILY = 1,2`) et Mac |
| Orientations | portrait et paysage ; portrait inversé en plus sur iPad |
| Catégorie principale | Games ▸ **Strategy** |
| Catégorie secondaire | Games ▸ **Trivia** |
| Classification par âge | **4+** |
| Game Center | non |
| Achats intégrés | dix-sept packs, non consommables — section 4 bis |
| Prix de l'app | **à décider** |
| Territoires | tous |
| Publication | **à décider** — automatique à l'approbation, ou manuelle |

Les deux numéros se lisent dans `project.yml` (`MARKETING_VERSION`,
`CURRENT_PROJECT_VERSION`) et nulle part ailleurs : le manuel intégré prend
dans le bundle celui qu'il affiche. Le build monte à chaque envoi ; la version
monte quand ce qui part mérite un nom.

C'est une première version, donc les deux partent à 1.

## 2. Les adresses

**Les quatre répondent 200**, servies par GitHub Pages depuis `main` ▸ `/docs`.

| Champ App Store Connect | Adresse | Page |
|---|---|---|
| URL marketing (facultative) | `https://boboul-cloud.github.io/riskelo-us/` | `docs/index.html` |
| **URL d'assistance** (obligatoire) | `https://boboul-cloud.github.io/riskelo-us/support.html` | `docs/support.html` |
| **URL de confidentialité** (obligatoire) | `https://boboul-cloud.github.io/riskelo-us/privacy.html` | `docs/privacy.html` |
| CLUF personnalisé (facultatif) | `https://boboul-cloud.github.io/riskelo-us/terms.html` | `docs/terms.html` |
| Dépôt du code et du site | `https://github.com/boboul-cloud/riskelo-us` | — |

Les noms de fichiers ne sont pas décoratifs : `privacy.html` et `terms.html`
sont ce que publient `Manual.privacyURL` et `Manual.termsURL`, et ces deux
liens sont sur l'écran d'accueil, sur l'écran de réglages et dans le chapitre
légal du manuel. Renommer un fichier casse trois boutons dans l'application.

`support.html` n'est pas lié depuis l'application : elle n'a pas de bouton
d'assistance. La page existe parce que le champ Support URL d'Apple est
obligatoire et doit répondre. Ajouter un `supportURL` à `Manual` et un
quatrième lien à côté des trois autres, c'est cinq lignes si tu le veux.

À revérifier avant de soumettre. Autre chose que 200 et la revue s'arrête là :

```bash
for p in "" support.html privacy.html terms.html; do
  printf "%-16s " "/$p"
  curl -s -o /dev/null -w "%{http_code}\n" https://boboul-cloud.github.io/riskelo-us/$p
done
```

## 3. Les coordonnées pour la revue

| Champ | Valeur |
|---|---|
| Prénom | Robert |
| Nom | Oulhen |
| Téléphone | **à décider** — Apple l'exige, il n'est jamais rendu public |
| Adresse électronique | `bob.oulhen@gmail.com` |
| Identifiant de démonstration | *aucun — l'app n'a pas de compte* |
| Mot de passe de démonstration | *aucun* |
| Compte requis | **Non** |

---

## 4. Les textes à coller

Tout ce qui suit est en anglais et se colle sans retouche. Les longueurs
indiquées ont été comptées, pas estimées.

### Nom de l'app — 30 signes max

```
Riskelo US
```

**à décider.** Les noms d'app sont uniques sur tout l'App Store, pour tous les
développeurs, toi compris. Celle des deux qui est créée en premier prend
« Riskelo », et l'autre doit différer. La française est en 1.3 et plus avancée :
elle prendra le nom simple, ce qui laisse celle-ci en chercher un.

`Riskelo US` est le choix sûr : il correspond à `CFBundleDisplayName`, donc le
nom sur le magasin et le nom sous l'icône s'accordent. Sa faiblesse est que
« US » se lit comme une variante régionale pour un Américain, ce qui n'est pas
ce qui vend un jeu.

Trois autres, toutes sous trente signes et toutes cherchables :

- `Riskelo: Trivia Conquest` (24) — porte deux mots-clés, au prix de ne plus
  correspondre au nom sous l'icône
- `Riskelo Conquest` (16)
- `Riskelo Trivia Wars` (19)

Quel que soit le choix, aligner `CFBundleDisplayName` dessus est une ligne de
`project.yml`.

### Sous-titre — 30 signes max

```
The conquest game without dice
```

Exactement 30. Variantes : `Conquer by knowing the answer` (29) ·
`No dice — just what you know` (28) · `Trivia conquest, 2-4 players` (28)

### Mots-clés — 100 signes max, virgules sans espace après

```
trivia,quiz,strategy,board,territory,turn-based,offline,multiplayer,family,geography,history,solo
```

97 signes. Le nom et le sous-titre sont déjà indexés, donc « conquest »,
« dice » et « Riskelo » en sont volontairement absents : les répéter gâcherait
le champ.

**Aucune marque de jeu de société, sous aucune forme.** La ressemblance de
genre ne donne aucun droit sur le nom d'autrui, et en utiliser un est un rejet
immédiat. Cela exclut le mot de quatre lettres auquel ce jeu va être comparé.

De quoi échanger s'il faut faire de la place : `knowledge`, `pass and play`,
`brain`, `study`, `middle school`.

### Texte promotionnel — 170 signes max, modifiable sans nouvelle version

```
2,400 questions in the game, three boards, two ways to duel. No ads, no account, no connection needed — the whole thing runs on the device, even on a plane.
```

156 signes. C'est le champ à changer quand les packs passent en promotion ou
qu'un prix bouge ; il ne demande pas de nouveau build.

### Description — 4 000 signes max

```
Riskelo is a turn-based conquest game where the roll of the dice is replaced by a trivia question.

The attacker picks the subject and how many questions — those are the dice. The defender answers against the clock. A right answer and it is the attacker who loses a man; a wrong answer, or time running out, and it is the defender. One question is worth exactly one roll: it costs a man to one side or the other.

TWO WAYS TO FIGHT

• Classic — the attacker asks and picks the ground; the defender answers alone. What you know is your armor.
• Showdown — both players get the same question. Both know it? The clock settles it. Neither? The territory holds, the way a tied roll holds it. And the defender can double the stake before answering.

THE PRESSURE OF A SIEGE

Without chance, a player who knows would never lose a place. What replaces the statistics of the dice is time: fifteen seconds on the first question, and the clock tightens with every question the same territory takes in the same turn. Pressing a place eventually pays — but it is the defender's breath that gives out, not their luck.

THREE BOARDS

• The Ring — an invented world, five lands in a circle, 28 territories. The short game.
• Europe — from the Atlantic to the Black Sea, 38 territories.
• World — six continents, 42 territories.

TWO TO FOUR PLAYERS

• Alone against the machine, whose knowledge sets anywhere from 35% to 90% correct answers and whose play has three levels — knowing and playing well are two different things.
• Around one device, passed from hand to hand.
• On several devices, one per player: no account, no setup, no server. The local Wi-Fi does it, or a direct link between the devices when there is no network — it works on a train.

Everyone can enter a name: a side reads "Blue · Marie", and the name travels from device to device.

THE RULES FROM THE BOX, OPTIONAL

• Territory cards, with the trade-in climbing at every exchange.
• Total war: every territory, no exception — a whole evening in one game.
• Personal conquests: each player is dealt an objective only they can see — two continents, so many places held, one side to bring down. Filling it wins outright, and the territory count no longer tells you who is winning.
• Scholar's reinforcement: one extra man for every few right answers in the same subject.

2,400 QUESTIONS IN THE GAME

Six subjects — Geography, History, Science & Nature, Arts & Literature, Sports & Games, Screen & Music — four hundred questions each, at three levels of difficulty. The mix is set before the game: easy for playing with children, mixed the way a boxed game would be, tough for anyone who finds the rest too easy. The draw never leaves the subject asked for: when you choose the ground, it is held. A seventh choice leaves the subject to chance, for anyone who would rather not pick. And a question does not come back: the device remembers what has already been asked, and puts the ones you have never seen in front.

QUESTION PACKS, IF YOU WANT THEM

Seventeen optional packs add 3,600 more questions. Sixteen school decks — History, Geography, English and Science, for grades 6 through 9, two hundred questions each — and Rock 70-80, four hundred questions on the music of the 1970s and 1980s. The base game is whole without them. And at a table of several devices, everyone plays the host's packs, bought or not.

THE GAME KEEPS

You find it where you left it. And the library records every turn without being asked: you can go back to the moment it all turned and play the rest again, without erasing the original.

WHAT RISKELO DOES NOT DO

No ads. No account. No tracker, no analytics. No internet connection is needed: the questions are in the app, and your games never leave your device.

iPhone, iPad and Mac — one app, in English.
```

3 794 signes.

> La description française se termine sur « aucun achat intégré ». **Ne
> reprends pas cette phrase.** Cette application en embarque dix-sept, et une
> description qui contredit la fiche est un rejet de métadonnées qui attend son
> heure. Le bloc ci-dessus dit ce qui est vrai : pas de publicité, pas de
> compte, pas de traceur, pas de connexion, et des packs si on veut.

### Nouveautés de cette version — 4 000 signes max

App Store Connect ne pose pas la question sur une première version, et un
joueur n'y chercherait rien. Si le champ apparaît quand même :

```
First release.
```

### Droits d'auteur

```
2026 Robert Oulhen
```

---

## 4 bis. Les achats intégrés

> **À ne créer qu'au moment de les soumettre.** Un article créé dans App Store
> Connect ne se supprime jamais et son identifiant ne se réutilise pas. Une
> version soumise avec l'écran des packs mais sans articles joints montrerait
> « indisponible » à tout le monde.

Dix-sept packs de questions, **non consommables** : achetés une fois, gardés
pour toujours. Seize packs scolaires — History, Geography, English et Science
sur quatre niveaux — et Rock 70-80.

Ce qui s'achète n'est pas le contenu : les fichiers sont dans l'application,
sur tous les appareils. C'est le droit de **choisir** un pack. C'est ce qui
permet à celui qui rejoint une table de jouer les packs de l'hôte sans les
avoir achetés, et c'est voulu.

Les identifiants sont ceux que le code demande. Une lettre de travers et
l'article n'est jamais trouvé — et un identifiant ne se corrige ni ne se
réutilise.

App Store Connect s'y prend en **deux temps**, et c'est là qu'on se trompe.

**1. Le dialogue « Créer un achat intégré »** ne demande que trois choses, dans
cet ordre :

| Champ du dialogue | Ce qu'on y met |
|---|---|
| Type | **Non consommable**, pour les dix-sept |
| Nom de référence | La colonne « Nom de référence » ci-dessous — une étiquette interne, invisible du public |
| Identifiant de produit | La colonne « Identifiant » ci-dessous — celui que le code demande, en `com.oulhen…` |

Ne pas les intervertir : l'identifiant est celui qui commence par `com.oulhen`,
et il ne se corrige plus après coup. Apple n'y accepte que des lettres, des
chiffres, des points et des tirets bas — nos dix-sept sont dans ce jeu, mais
une description collée là sera refusée, avec raison.

**2. Une fois l'article créé**, sa fiche s'ouvre et c'est là que se saisissent
le nom affiché et la description, sous **Localisations** (anglais États-Unis),
puis le prix et la disponibilité.

**3. La capture de vérification**, dans « Informations pour la vérification »,
est obligatoire pour chaque article. Elle n'est jamais montrée aux clients :
elle sert à prouver au relecteur que l'article existe dans l'application.

Elle est prête : `submission/screenshots/iap-review-packs.png` — l'écran Packs,
1206 × 2622, prix affichés. **Le même fichier se dépose pour les dix-sept** :
ils sont tous sur cet écran, il n'y a pas dix-sept captures à faire.

Pour la refaire, si l'écran change : elle ne peut pas se prendre depuis le
simulateur seul, où StoreKit ne répond pas et où chaque pack affiche
« unavailable ». Il faut lancer depuis **Xcode** (`⌘R`), qui attache
`Resources/RiskeloUS.storekit` au schéma — c'est de là que viennent les 2,99 $.
Puis, l'écran Packs ouvert :

```bash
xcrun simctl io booted screenshot submission/screenshots/iap-review-packs.png
```

| Nom de référence | Identifiant de produit | Nom affiché (35) | Description (55) |
|---|---|---|---|
| Rock 70 80 Pack | `com.oulhen.riskelo.us.pack.rock7080` | Rock 70-80 | `Bands and voices of the 1970s and 80s. 400 questions.` |
| History Grade 6 Pack | `com.oulhen.riskelo.us.pack.history6` | History — Grade 6 | `Mesopotamia, Egypt, Greece and Rome. 200 questions.` |
| Geography Grade 6 Pack | `com.oulhen.riskelo.us.pack.geography6` | Geography — Grade 6 | `Map skills, landforms, Africa, Asia. 200 questions.` |
| English Grade 6 Pack | `com.oulhen.riskelo.us.pack.english6` | English — Grade 6 | `Grammar, punctuation, roots and myths. 200 questions.` |
| Science Grade 6 Pack | `com.oulhen.riskelo.us.pack.science6` | Science — Grade 6 | `Earth science: rocks, weather, space. 200 questions.` |
| History Grade 7 Pack | `com.oulhen.riskelo.us.pack.history7` | History — Grade 7 | `The medieval and early modern world. 200 questions.` |
| Geography Grade 7 Pack | `com.oulhen.riskelo.us.pack.geography7` | Geography — Grade 7 | `Europe, the Americas, the Pacific. 200 questions.` |
| English Grade 7 Pack | `com.oulhen.riskelo.us.pack.english7` | English — Grade 7 | `Poetry, fiction, drama and novels. 200 questions.` |
| Science Grade 7 Pack | `com.oulhen.riskelo.us.pack.science7` | Science — Grade 7 | `Life science: cells, plants, animals. 200 questions.` |
| History Grade 8 Pack | `com.oulhen.riskelo.us.pack.history8` | History — Grade 8 | `Colonial America to Reconstruction. 200 questions.` |
| Geography Grade 8 Pack | `com.oulhen.riskelo.us.pack.geography8` | Geography — Grade 8 | `The fifty states and their geography. 200 questions.` |
| English Grade 8 Pack | `com.oulhen.riskelo.us.pack.english8` | English — Grade 8 | `American literature, Poe to Morrison. 200 questions.` |
| Science Grade 8 Pack | `com.oulhen.riskelo.us.pack.science8` | Science — Grade 8 | `Atoms, reactions, forces and waves. 200 questions.` |
| History Grade 9 Pack | `com.oulhen.riskelo.us.pack.history9` | History — Grade 9 | `The modern world, 1750 to today. 200 questions.` |
| Geography Grade 9 Pack | `com.oulhen.riskelo.us.pack.geography9` | Geography — Grade 9 | `Population, cities and world trade. 200 questions.` |
| English Grade 9 Pack | `com.oulhen.riskelo.us.pack.english9` | English — Grade 9 | `Shakespeare and world literature. 200 questions.` |
| Science Grade 9 Pack | `com.oulhen.riskelo.us.pack.science9` | Science — Grade 9 | `Biology: DNA, genetics and evolution. 200 questions.` |

Les deux premières colonnes vont dans le dialogue de création, les deux
dernières dans « Ajouter la langue dans l'App Store », en anglais États-Unis.

Le nom affiché est limité à **35** signes et la description à **55**. Attention
au compteur d'App Store Connect : il affiche le **restant**, pas le saisi — un
champ vide marque donc la limite du champ, et non zéro.

La ligne `! detail` en tête de chaque fichier de questions, celle que montre la
boutique de l'application, en fait quatre-vingts ou quatre-vingt-dix : là-bas
la place existe. Les formes ci-dessus sont écrites pour le champ d'Apple et ne
servent nulle part ailleurs. Toutes ont été comptées, avec deux signes de marge
sous la limite — assez pour qu'une divergence de comptage d'un caractère ne
casse rien.

### Ce qui reste à décider

**Le prix.** Le fichier d'essai porte 2,99 $ : un nombre inventé pour pouvoir
cliquer, pas une proposition. Les paliers américains commencent à 0,99 $.

**Le partage familial.** Un pack scolaire acheté une fois et joué par les deux
enfants de la maison est plus juste qu'un pack acheté deux fois, et Apple le
propose article par article. Le fichier d'essai l'a activé.

**Les packs scolaires sont américains, et c'est tout l'argument.** History suit
la séquence classique des États-Unis, Science suit Earth / Life / Physical /
Biology, et English va de la grammaire à la littérature mondiale en passant par
les lettres américaines en grade 8. Si un relecteur demande ce qui justifie de
les vendre, la réponse est là : ils sont écrits sur le programme américain, pas
traduits d'ailleurs.

### La première fois, ils partent avec la version

Apple relit les achats intégrés en même temps que l'application. Il faut donc
les **joindre à la version** sur la fiche avant de soumettre : créés mais non
joints, ils restent « en attente d'envoi » et l'écran des packs dira
« indisponible » à tout le monde.

### Pour les essayer sans rien envoyer

`Resources/RiskeloUS.storekit` est un App Store de bureau, attaché au schéma.
On lance depuis Xcode, on achète pour rien, et **Debug ▸ StoreKit** rembourse
ou annule. Rien ne remonte chez Apple.

Le fichier ne part pas dans le paquet : il est dans le projet sans phase de
construction, pour qu'on puisse en changer les prix sans rien livrer. Il est
reconstruit depuis les en-têtes des fichiers de questions — les lignes `! id`,
`! name`, `! detail`, `! product` et `! rank` — pour que la boutique, la
boutique d'essai et le tableau ci-dessus ne puissent jamais diverger.

---

## 5. Les questionnaires

### Confidentialité de l'app

> **Collectez-vous des données depuis cette app ?** → **Non, nous ne collectons
> aucune donnée de cette app.**

Vérifiable : aucune dépendance externe, aucune requête vers un serveur, aucun
identifiant publicitaire. Les fichiers de partie restent dans le conteneur de
l'app et disparaissent avec elle. Des données écrites localement et jamais
envoyées ne comptent pas comme collectées.

### Les réponses annexes

| Question | Réponse |
|---|---|
| Identifiant publicitaire (IDFA) ? | Non |
| Suivi (App Tracking Transparency) ? | Non |
| Achats intégrés ? | Oui — dix-sept packs non consommables |
| Publicité dans l'app ? | Non |
| Contenu de tiers soumis à droits ? | Non — code, questions, plateaux et icône sont l'œuvre de l'éditeur |
| Chiffrement / conformité export | `ITSAppUsesNonExemptEncryption = false`, déjà dans l'Info.plist : plus rien à répondre à chaque envoi |
| Connexion à un compte | Aucune |

### Classification par âge

Répondre **Aucun / Jamais** à tout : pas de violence figurée (le jeu est fait
d'hexagones et de nombres), pas de contenu sexuel, pas de jeu d'argent, pas
d'alcool ni de tabac, pas de contenu généré par les utilisateurs, pas d'accès
web libre. Résultat attendu : **4+**.

Une question mérite d'y penser plutôt que d'y répondre par réflexe : les
questions sont écrites pour les grades 6 à 9, et touchent la guerre,
l'esclavage et le génocide comme le fait un manuel scolaire — le Passage du
milieu, la Shoah, le génocide rwandais. C'est une référence historique dans un
questionnaire à choix multiple, pas de la violence figurée, et cela ne change
pas la classification. Mieux vaut connaître la réponse avant qu'on la demande.

### La seule autorisation demandée

| Autorisation | Quand | Texte affiché |
|---|---|---|
| Réseau local | À la première ouverture de « Play on several devices » | « Riskelo US uses it to find the other device and play a two-player game. » |

Refusée, l'app reste entièrement jouable : seul le jeu à plusieurs appareils
est indisponible. Aucune autre autorisation — ni position, ni photos, ni
contacts, ni micro, ni notifications.

### Le point que personne ne déclare, et qu'il vaut mieux avoir écrit

Le nom de l'appareil (« iPhone de Camille ») est visible des appareils proches
pendant la recherche d'une table : l'annonce Bonjour s'en sert comme étiquette.
Ce n'est pas une collecte — rien n'est enregistré ni transmis à l'éditeur — et
c'est dit à la section 4 de la politique de confidentialité. Si un relecteur
pose la question, la réponse y est déjà.

---

## 6. Notes pour la revue

Ce bloc est lu par Apple : il est en anglais et se colle tel quel.

```
Hello,

Riskelo US is a turn-based conquest game: the outcome of each battle is decided
by a multiple-choice trivia question instead of a roll of the dice.

NO ACCOUNT IS NEEDED
The app has no sign-up, no sign-in and no advertising. Every part of the base
game is reachable from launch, so there are no demo credentials to provide.

TO TRY IT IN A MINUTE
1. Tap "Start" (the default settings are fine).
2. Tap your own territories to place your reinforcements, then "Attack".
3. Tap one of your territories holding at least two men, then a neighboring
   enemy territory.
4. Pick a subject and tap "Launch the assault": a question appears.

The full manual is inside the app: the "Manual" button on the home screen, or
the question mark in the top bar during a game.

IN-APP PURCHASES
Seventeen non-consumable question packs. The files themselves ship inside the
app on every device; what is purchased is the right to select a pack. This is
why a player joining a multi-device table can play the host's packs without
having bought them — it is deliberate, and it is stated on the packs screen.

A FEATURE THAT NEEDS TWO DEVICES
"Play on several devices" links two to four nearby devices using Apple's
Network framework: Bonjour to find each other, TCP to talk. The devices use the
local Wi-Fi network, or a direct device-to-device Wi-Fi link when there is no
network. No server is involved and nothing is stored: only the moves of the
game travel.

The feature therefore needs two physical devices in the same room, Wi-Fi on at
both ends, and the local network permission granted. It is optional: refusing
that permission leaves the rest of the game fully working (solo against the
computer, or several players around one device).

PERMISSIONS
One, and it is optional: the local network, for the feature above. Nothing else
— no location, no photos, no contacts, no microphone, no notifications.

PRIVACY
No data is collected or transmitted. The app embeds no third-party kit and
makes no request to any server. It works entirely offline: all six thousand
questions are in the bundle.

CONTENT
The questions, the boards, the artwork and the icon are original work. Riskelo
US is an independent game, inspired by the genre of territorial conquest games;
it uses no trademark, no artwork and no text belonging to any board game
publisher.

LANGUAGE
The app is in English, questions included. That is its only language. A
separate French app exists under its own record; the two do not share content
and cannot join each other's games.

Thank you for your time,
Robert Oulhen — bob.oulhen@gmail.com
```

---

## 7. Les captures d'écran

**bloquant — celles qui existent ne servent pas.** Les dix-huit fichiers de
`soumission/captures/` sont l'app française : questions, boutons et panneaux en
français. Il faut les reprendre sur ce build.

| Dossier | Taille | Résolution | Exigée ? |
|---|---|---|---|
| `submission/screenshots/iphone-6.9/` | iPhone 6,9 pouces | 1320 × 2868 | oui |
| `submission/screenshots/iphone-6.5/` | iPhone 6,5 pouces | 1242 × 2688 | non — la fournir quand même |
| `submission/screenshots/ipad-13/` | iPad 13 pouces | 2064 × 2752 | oui, si l'iPad est proposé |
| — | Mac | 2880 × 1800 (16:10) | seulement si le Mac part aussi |

Une capture d'iPhone 6,9" couvre toutes les autres tailles d'iPhone. Minimum
une par taille, maximum dix.

**Les six écrans, dans cet ordre** — le premier est celui qui sort dans les
résultats de recherche :

1. **Un duel en cours** — la question par-dessus le plateau, le sablier entamé.
2. **Le panneau d'assaut** — les six thèmes, les scores du défenseur, la
   lunette sur son point faible.
3. **Le plateau du Monde** en milieu de partie — deux ou trois camps
   enchevêtrés, un continent tenu.
4. **La feuille du verdict en face à face** — les deux réponses, leurs temps,
   la couronne.
5. **L'écran de mise en place** — tout ce qui se règle, d'un coup d'œil.
6. **L'accueil** — il ne dit pas ce qu'est le jeu, d'où la dernière place, mais
   il montre l'icône et le seul bouton dont on ait besoin pour commencer.

`outils/captures.py` joue une partie tout seul sur les trois appareils, prend
les six écrans, règle la barre d'état à 9:41 et range le tout. **Il n'a jamais
été lancé sur cette application** : il a été écrit pour la française et porte
encore son nom de schéma et ses libellés d'écrans français. Il faudra le
corriger avant qu'il fonctionne :

```bash
xcodebuild -project RiskeloUS.xcodeproj -scheme RiskeloUS \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
    -derivedDataPath build/dd build
cp -R build/dd/Build/Products/Debug-iphonesimulator/RiskeloUS.app build/
python3 outils/captures.py
```

Celles du Mac se prennent à la main, et seulement si la version Mac part aussi
— `⌘⇧4` puis la barre d'espace ajoute une ombre portée qu'Apple refuse :

```bash
screencapture -o -w ~/Desktop/riskelo-us-mac-01.png
```

Ce qui fait rejeter une capture : une maquette d'appareil dessinée autour de
l'écran, un montage qui ne vient pas de l'app, des barres d'état incohérentes
d'une capture à l'autre (le simulateur affiche 9:41 partout), du texte
promotionnel qui recouvre l'interface.

L'icône de l'App Store est déjà au catalogue en 1024 × 1024 sans canal alpha,
et se refait d'une commande — verte et rouge ici, là où la française est bleue
et rouge :

```bash
swiftc -O -parse-as-library -o /tmp/icone outils/icone.swift && /tmp/icone
```

---

## 8. Fabriquer et envoyer

```bash
xcodegen generate
xcodebuild -scheme RiskeloUS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -scheme RiskeloUS -destination 'generic/platform=iOS' \
           -archivePath ~/Desktop/RiskeloUS-ios.xcarchive archive
```

Puis Xcode ▸ Window ▸ Organizer ▸ l'archive ▸ **Distribute App** ▸ *App Store
Connect* ▸ *Upload*. La build apparaît dans App Store Connect au bout de
quelques minutes, le temps du traitement.

Le numéro de build doit **monter à chaque envoi** : un même `1` ne se dépose
pas deux fois. Il se change dans `project.yml` (`CURRENT_PROJECT_VERSION`),
jamais dans Xcode — `xcodegen generate` réécrit le projet.

---

## 9. Le Mac App Store

Une seule cible pour iPhone, iPad et Mac ; sur la fiche, cela fait **deux
plateformes sous le même enregistrement**, chacune avec ses captures et son
envoi. Les textes peuvent être identiques.

Le Mac App Store impose le **bac à sable**, et le projet l'a, dans
`Resources/RiskeloUS-mac.entitlements` :

| Clé | Ce qu'elle dit |
|---|---|
| `com.apple.security.app-sandbox` | Enferme l'application. Exigé par le Mac App Store. |
| `com.apple.security.network.client` | La laisse sortir chercher l'autre appareil. |
| `com.apple.security.network.server` | La laisse se faire trouver par lui. |

Les deux dernières comptent autant que la première : **le bac à sable coupe le
réseau**, et sans elles le Mac et l'iPhone cesseraient de se voir sans que rien
à l'écran ne dise pourquoi. Le réglage ne s'applique qu'au Mac — `project.yml`
le pose sous `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`.

**Non vérifié sur cette application.** La française a été essayée sur du
matériel réel et la liaison tenait avec le bac à sable ; la configuration ici
est le même fichier sous un nouveau nom, mais le nom de service Bonjour a
changé (`_riskelo-us._tcp`) et c'est exactement le genre de chose qui échoue en
silence. À vérifier avant de livrer le Mac :

1. Wi-Fi allumé des deux côtés, les deux machines dans la même pièce.
2. Sur le Mac : ouvrir le projet et lancer (`⌘R`).
3. Sur l'iPhone : le brancher, le choisir comme destination, lancer (`⌘R`).
4. Sur l'une des deux : **Play on several devices** ▸ *Open a table*.
5. Sur l'autre : **Play on several devices** ▸ *Join a table*, puis toucher le
   nom qui apparaît.
6. Si le Mac demande l'autorisation d'utiliser le réseau local, **accepter**.
7. Si rien ne vient au bout d'une minute : **inverser les rôles**. C'est le
   remède habituel, et il ne veut pas dire que le bac à sable est en cause.

Rien n'oblige à sortir les deux plateformes le même jour. L'iPhone peut partir
seul et le Mac s'ajouter plus tard sous le même enregistrement.

---

## 10. L'ordre des opérations

- [ ] Adhésion **Apple Developer Program** active (99 $/an)
- [ ] Contrat **Applications gratuites** signé dans App Store Connect ▸
      Contrats, taxes et opérations bancaires — un contrat non signé bloque la
      publication sans rien expliquer
- [ ] Si l'app est payante, ou si les packs sont vendus : contrat payant,
      coordonnées bancaires et fiscales
- [x] GitHub Pages activé, les quatre adresses de la section 2 répondent 200
- [ ] *(facultatif)* `supportURL` ajouté à `Manual` et un quatrième lien dans
      l'application
- [ ] Identifiant d'app `com.oulhen.riskelo.us` enregistré sur le portail
- [ ] Enregistrement créé dans App Store Connect (le nom est réservé à ce
      moment-là — régler la section 4 d'abord)
- [ ] Tests verts, une partie jouée sur chaque machine, une partie à deux
      appareils dans les deux sens
- [ ] Archive envoyée, build traitée et visible sur la fiche
- [ ] Essai TestFlight sur un appareil réel
- [ ] Textes de la section 4 collés
- [ ] Captures **reprises en anglais** et déposées
- [ ] Questionnaires de la section 5 remplis
- [ ] Notes de la section 6 collées
- [ ] Prix et disponibilité choisis
- [ ] Les dix-sept achats intégrés créés et **joints à la version**
- [ ] Achats essayés avec un compte sandbox sur un appareil réel
- [ ] Soumis à la revue

Compter de deux à quarante-huit heures. Répondre vite à toute question du
relecteur : un fil qui traîne repart en bas de la file.

---

## 11. Ce qui reste à décider

| Point | Pourquoi c'est à toi |
|---|---|
| Le nom sur le magasin | Deux apps ne peuvent pas partager un nom. La section 4 pose le compromis ; à régler avant de créer l'enregistrement, puisque c'est là que le nom est réservé. |
| Le prix de l'app | Gratuit fait des joueurs, payant fait un revenu. Avec dix-sept packs à vendre, gratuit plus packs est la forme habituelle — mais c'est une décision, pas un défaut. |
| Le prix des packs | 2,99 $ est une valeur de remplissage dans le fichier d'essai. |
| Le partage familial sur les packs | Activé dans le fichier d'essai. Plus juste pour une maison avec deux enfants. |
| Le numéro de téléphone de la revue | Apple l'exige ; il n'est jamais rendu public. |
| Publication automatique ou manuelle | Manuelle si tu veux choisir le jour. |
| macOS maintenant ou plus tard | Le bac à sable est posé mais la liaison n'a pas été essayée sur cette app. Section 9. |
| Le sous-titre | Quatre candidats en section 4 ; c'est le seul texte lu avant la description. |

---

## 12. Ce qui est encore en français dans le projet

Rien qui bloque le binaire, mais tout cela se montre à un utilisateur ou à un
relecteur :

| Quoi | État |
|---|---|
| `docs/` | Fait — quatre pages anglaises, aux noms que l'application publie. |
| `soumission/` | Le dossier de l'app française. Ce fichier remplace sa fiche. Les captures qui y sont montrent l'interface française. |
| `README.md` | En français. |
| `outils/icone.swift` | Commentaires et identifiants en français. Fonctionne. |
| `outils/listen.swift`, `outils/captures.py` | En français. `captures.py` nomme en plus le schéma et les écrans français. |
