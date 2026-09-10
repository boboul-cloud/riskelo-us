# Submission sheet — Riskelo US 1.0

Everything App Store Connect asks for, in the order it asks. Each fenced block
is meant to be pasted as it stands. What is still open is marked **to decide**;
what would get the submission refused is marked **blocker**.

This is the American app. The French one has its own dossier and its own
record; the two share nothing but an ancestor.

---

## 0. Four things stand between this and a submission

Read this section before anything else. The rest of the document assumes these
are settled.

1. **blocker — The website does not exist.** Apple requires a live Support URL
   and a live Privacy Policy URL, and refuses the submission without examining
   anything else if either fails. All four candidate addresses return 404
   today, because GitHub Pages has never been switched on for
   `boboul-cloud/riskelo-us` and `docs/` still holds the French pages under
   French filenames. See section 2.
2. **blocker — The app declares no support address at all.** `ManualView`
   publishes a site, a privacy page and a terms page, but nothing for support.
   Apple asks for one and it has to resolve. See section 2.
3. **blocker — The screenshots are of the French app.** The eighteen files in
   `soumission/captures/` show French text on every panel. They cannot be used
   for an English listing. See section 7.
4. **to decide — The app's Store name.** App Store names are unique across the
   whole store, so the French app and this one cannot both be called
   "Riskelo". See section 4.

---

## 1. Identifiers

| Field | Value |
|---|---|
| App name | `Riskelo US` — **to decide**, see section 4 |
| Bundle ID | `com.oulhen.riskelo.us` |
| Team | `38DQ8FW23J` |
| SKU (internal, never public, never reusable) | `riskelo-us-2026` |
| Apple ID for the app | assigned by App Store Connect at creation |
| Primary language | English (U.S.) |
| Version | `1.0` |
| Build | `1` |
| Platforms | iOS and macOS (one target, two platforms on the record) |
| Minimum OS | iOS 17.0 · macOS 14.0 |
| Devices | iPhone and iPad (`TARGETED_DEVICE_FAMILY = 1,2`) and Mac |
| Orientations | portrait and landscape; upside-down as well on iPad |
| Primary category | Games ▸ **Strategy** |
| Secondary category | Games ▸ **Trivia** |
| Age rating | **4+** |
| Game Center | no |
| In-app purchases | seventeen packs, non-consumable — section 4 bis |
| App price | **to decide** |
| Territories | all |
| Release | **to decide** — automatic on approval, or manual |

Both numbers live in `project.yml` (`MARKETING_VERSION`,
`CURRENT_PROJECT_VERSION`) and nowhere else: the in-app manual reads the one it
displays from the bundle. The build number has to climb with every upload; the
version climbs when what ships deserves a name.

This is a first version, so both start at 1.

## 2. Addresses

**None of these resolve today.** This is the first blocker, and it is the
cheapest one to clear.

| App Store Connect field | Address | Status |
|---|---|---|
| Marketing URL (optional) | `https://boboul-cloud.github.io/riskelo-us/` | 404 |
| **Support URL** (required) | `https://boboul-cloud.github.io/riskelo-us/support.html` | 404 — and not declared in the app |
| **Privacy Policy URL** (required) | `https://boboul-cloud.github.io/riskelo-us/privacy.html` | 404 |
| Custom EULA (optional) | `https://boboul-cloud.github.io/riskelo-us/terms.html` | 404 |
| Code and site repository | `https://github.com/boboul-cloud/riskelo-us` | live |

Three things have to line up, and today none of them do:

- **`docs/` is still the French site**, with French filenames:
  `assistance.html`, `conditions.html`, `confidentialite.html`. The app asks
  for `privacy.html` and `terms.html`. Even translated, the files have to be
  renamed to what the app publishes — or `ManualView` changed to match.
- **There is no support page** in either language, and no `supportURL` in
  `ManualView`. Apple will accept the marketing URL as the Support URL if that
  page offers a way to get help — an email address is enough — so the cheapest
  fix is a contact line on the home page and the same URL in both fields.
- **GitHub Pages is off.** Repository ▸ Settings ▸ Pages ▸ Source: `main`,
  folder `/docs`. It takes a minute or two to go live.

Check before submitting. Anything other than 200 and the review stops there:

```bash
for p in "" support.html privacy.html terms.html; do
  printf "%-16s " "/$p"
  curl -s -o /dev/null -w "%{http_code}\n" https://boboul-cloud.github.io/riskelo-us/$p
done
```

## 3. Review contact

| Field | Value |
|---|---|
| First name | Robert |
| Last name | Oulhen |
| Phone | **to decide** — Apple requires it, it is never made public |
| Email | `bob.oulhen@gmail.com` |
| Demo account username | *none — the app has no accounts* |
| Demo account password | *none* |
| Sign-in required | **No** |

---

## 4. The text to paste

### App name — 30 characters max

```
Riskelo US
```

**to decide.** App Store names are unique across the entire store, for every
developer including yourself. Whichever of the two apps is created first takes
"Riskelo", and the other has to differ. The French app is at 1.3 and further
along, so it will take the plain name — which leaves this one needing its own.

`Riskelo US` is the safe choice: it matches `CFBundleDisplayName`, so the name
on the Store and the name under the icon agree. Its weakness is that "US" reads
as a regional variant to an American, which is not what sells a game.

Alternatives, all inside thirty characters and all searchable:

- `Riskelo: Trivia Conquest` (24) — carries two keywords, at the cost of no
  longer matching the name under the icon
- `Riskelo Conquest` (16)
- `Riskelo Trivia Wars` (19)

Whatever is chosen, changing `CFBundleDisplayName` to match is one line in
`project.yml`.

### Subtitle — 30 characters max

```
The conquest game without dice
```

Exactly 30. Variants: `Conquer by knowing the answer` (29) · `No dice — just
what you know` (28) · `Trivia conquest, 2-4 players` (28)

### Keywords — 100 characters max, commas with no space after

```
trivia,quiz,strategy,board,territory,turn-based,offline,multiplayer,family,geography,history,solo
```

97 characters. The name and subtitle are already indexed, so "conquest",
"dice" and "Riskelo" are deliberately absent — repeating them wastes the field.

**No board-game trademark, in any form.** The genre resemblance gives no right
to anyone else's name, and using one is an immediate rejection. That rules out
the obvious three-letter word this game will be compared to.

Swap candidates if something needs room: `knowledge`, `pass and play`,
`brain`, `study`, `middle school`.

### Promotional text — 170 characters max, editable without a new version

```
2,400 questions in the game, three boards, two ways to duel. No ads, no account, no connection needed — the whole thing runs on the device, even on a plane.
```

154 characters. This is the field to change when the packs go on sale or a
price moves; it does not need a new build.

### Description — 4,000 characters max

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

> The French description ends on "no in-app purchases". **Do not carry that
> sentence over.** This app ships seventeen of them, and a description that
> denies what the record declares is a metadata rejection waiting to happen.
> The block above says what is true: no ads, no account, no tracking, no
> connection, and packs you may buy if you want them.

### What's New in This Version — 4,000 characters max

App Store Connect does not ask for this on a first version, and there is
nothing a player would look for in it. If the field appears anyway:

```
First release.
```

### Copyright

```
2026 Robert Oulhen
```

---

## 4 bis. In-app purchases

> **Only create these when you are ready to submit them.** An item created in
> App Store Connect is never deleted and its identifier is never reused. A
> version submitted with the packs screen but with no items attached would show
> "unavailable" to everyone.

Seventeen question packs, **non-consumable**: bought once, kept for good.
Sixteen school decks — History, Geography, English and Science across four
grades — and Rock 70-80.

What is bought is not the content: the files ship inside the app, on every
device. What is bought is the right to **choose** a pack. That is what lets
somebody joining a table play the host's packs without owning them, and it is
deliberate.

The identifiers are the ones the code asks for. One letter out of place and the
item is never found.

| Identifier | Reference name | Display name (30) | Description (45) |
|---|---|---|---|
| `com.oulhen.riskelo.us.pack.rock7080` | Rock 70 80 Pack | Rock 70-80 | `Rock of the 1970s and 80s. 400 questions.` |
| `com.oulhen.riskelo.us.pack.history6` | History Grade 6 Pack | History — Grade 6 | `Egypt, Greece and Rome. 200 questions.` |
| `com.oulhen.riskelo.us.pack.geography6` | Geography Grade 6 Pack | Geography — Grade 6 | `Maps, landforms, Africa, Asia. 200 questions.` |
| `com.oulhen.riskelo.us.pack.english6` | English Grade 6 Pack | English — Grade 6 | `Grammar, word roots, myths. 200 questions.` |
| `com.oulhen.riskelo.us.pack.science6` | Science Grade 6 Pack | Science — Grade 6 | `Earth science and space. 200 questions.` |
| `com.oulhen.riskelo.us.pack.history7` | History Grade 7 Pack | History — Grade 7 | `Medieval and early modern. 200 questions.` |
| `com.oulhen.riskelo.us.pack.geography7` | Geography Grade 7 Pack | Geography — Grade 7 | `Europe, the Americas, Pacific. 200 questions.` |
| `com.oulhen.riskelo.us.pack.english7` | English Grade 7 Pack | English — Grade 7 | `Poetry, fiction and drama. 200 questions.` |
| `com.oulhen.riskelo.us.pack.science7` | Science Grade 7 Pack | Science — Grade 7 | `Cells, plants, animals, body. 200 questions.` |
| `com.oulhen.riskelo.us.pack.history8` | History Grade 8 Pack | History — Grade 8 | `US history to Reconstruction. 200 questions.` |
| `com.oulhen.riskelo.us.pack.geography8` | Geography Grade 8 Pack | Geography — Grade 8 | `The fifty states. 200 questions.` |
| `com.oulhen.riskelo.us.pack.english8` | English Grade 8 Pack | English — Grade 8 | `American literature. 200 questions.` |
| `com.oulhen.riskelo.us.pack.science8` | Science Grade 8 Pack | Science — Grade 8 | `Matter, atoms, forces, waves. 200 questions.` |
| `com.oulhen.riskelo.us.pack.history9` | History Grade 9 Pack | History — Grade 9 | `The modern world since 1750. 200 questions.` |
| `com.oulhen.riskelo.us.pack.geography9` | Geography Grade 9 Pack | Geography — Grade 9 | `People, cities and trade. 200 questions.` |
| `com.oulhen.riskelo.us.pack.english9` | English Grade 9 Pack | English — Grade 9 | `Shakespeare and the classics. 200 questions.` |
| `com.oulhen.riskelo.us.pack.science9` | Science Grade 9 Pack | Science — Grade 9 | `Biology: DNA and evolution. 200 questions.` |

The three fields have hard limits in App Store Connect, and the last one is
tighter than it looks: **45 characters**. The `! detail` line at the top of
each question file — what the app's own shop shows — runs to eighty or ninety,
because there the room exists. The short forms above are written for Apple's
field and belong nowhere else. Every one has been counted.

### Still to decide

**The price.** The test file carries $2.99, which is a number invented so the
buttons could be clicked, not a proposal. US tier pricing starts at $0.99.

**Family Sharing.** A school pack bought once and played by both children in a
house is fairer than the same pack bought twice, and Apple offers it item by
item. The test file has it on.

**The school packs are American, and that is the whole point.** History follows
the classic US sequence, Science follows Earth / Life / Physical / Biology, and
English runs from grammar to world literature by way of American literature in
grade 8. If a reviewer asks what makes them worth money, that is the answer:
they are written to the American curriculum, not translated from somewhere
else.

### First time out, they ship with the version

Apple reviews in-app purchases alongside the app, so they have to be
**attached to the version** on the record before submitting. Created but not
attached, they sit in "waiting for upload" and the packs screen says
"unavailable" to everybody.

### Trying them without sending anything

`Resources/RiskeloUS.storekit` is a desk-sized App Store, attached to the
scheme. Run from Xcode, buy for nothing, and **Debug ▸ StoreKit** will refund
or cancel. None of it reaches Apple.

The file is not in the bundle: it sits in the project with no build phase, so
prices can change without shipping anything. It is rebuilt from the question files' headers — the
`! id`, `! name`, `! detail`, `! product` and `! rank` lines — so the shop, the
test store and the table above can never drift apart.

---

## 5. The questionnaires

### App Privacy

> **Do you collect data from this app?** → **No, we do not collect data from
> this app.**

Checkable: no external dependency, no request to any server, no advertising
identifier. Save files stay in the app container and go when it goes. Data
written locally and never sent does not count as collected.

### The side questions

| Question | Answer |
|---|---|
| Advertising identifier (IDFA)? | No |
| Tracking (App Tracking Transparency)? | No |
| In-app purchases? | Yes — seventeen non-consumable packs |
| Advertising in the app? | No |
| Third-party copyrighted content? | No — code, questions, boards and icon are the publisher's own work |
| Encryption / export compliance | `ITSAppUsesNonExemptEncryption = false`, already in Info.plist: nothing to answer at each upload |
| Account sign-in | None |

### Age rating

Answer **None / Never** to everything: no depicted violence (the game is
hexagons and numbers), no sexual content, no gambling, no alcohol or tobacco,
no user-generated content, no unrestricted web access. Expected result: **4+**.

One question deserves a moment's thought rather than a reflex: the questions
are written for grades 6 through 9, and touch war, slavery and genocide as a
school textbook does — the Middle Passage, the Holocaust, the Rwandan genocide.
This is historical reference in a multiple-choice question, not depicted
violence, and it does not move the rating. It is worth knowing the answer
before being asked it.

### The only permission requested

| Permission | When | Text shown |
|---|---|---|
| Local network | The first time "Play on several devices" is opened | "Riskelo US uses it to find the other device and play a two-player game." |

Refused, the app stays entirely playable: only multi-device play is
unavailable. No other permission — no location, no photos, no contacts, no
microphone, no notifications.

### The point nobody declares, and that is better written down

The device name ("Camille's iPhone") is visible to nearby devices while a table
is being looked for: the Bonjour advertisement uses it as a label. It is not a
collection — nothing is recorded and nothing reaches the publisher — and it
belongs in section 4 of the privacy policy. If a reviewer asks, the answer is
already in writing.

---

## 6. App Review Information

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

## 7. Screenshots

**blocker — the existing ones cannot be used.** The eighteen files in
`soumission/captures/` are the French app: French questions, French buttons,
French panels. They have to be retaken against this build.

| Folder | Size | Resolution | Required? |
|---|---|---|---|
| `submission/screenshots/iphone-6.9/` | iPhone 6.9-inch | 1320 × 2868 | yes |
| `submission/screenshots/iphone-6.5/` | iPhone 6.5-inch | 1242 × 2688 | no — supply anyway |
| `submission/screenshots/ipad-13/` | iPad 13-inch | 2064 × 2752 | yes, if iPad is offered |
| — | Mac | 2880 × 1800 (16:10) | only if the Mac ships too |

One iPhone 6.9" screenshot covers every other iPhone size. Minimum one per
size, maximum ten.

**The six screens, in this order** — the first is the one that shows in search
results:

1. **A duel under way** — the question over the board, the clock already
   running.
2. **The assault panel** — the six subjects, the defender's scores, the glass
   on their weak spot.
3. **The World board** mid-game — two or three sides tangled, one continent
   held.
4. **The showdown verdict sheet** — both answers, their times, the crown.
5. **The setup screen** — everything that can be set, at a glance.
6. **The home screen** — it does not say what the game is, hence last, but it
   shows the icon and the one button needed to begin.

`outils/captures.py` plays a game by itself on the three devices, takes the six
screens, sets the status bar to 9:41 and files everything. **It has not been
run against this app** — it was written for the French one and still carries
its scheme name and its French screen labels. Expect to fix it before it
works:

```bash
xcodebuild -project RiskeloUS.xcodeproj -scheme RiskeloUS \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
    -derivedDataPath build/dd build
cp -R build/dd/Build/Products/Debug-iphonesimulator/RiskeloUS.app build/
python3 outils/captures.py
```

Mac screenshots are taken by hand, and only if the Mac version ships —
`⌘⇧4` then space adds a drop shadow that Apple refuses:

```bash
screencapture -o -w ~/Desktop/riskelo-us-mac-01.png
```

What gets a screenshot rejected: a device frame drawn around the screen, a
composite that does not come from the app, status bars that disagree from one
shot to the next (the simulator shows 9:41 everywhere), promotional text
covering the interface.

The App Store icon is already in the catalogue at 1024 × 1024 with no alpha
channel, and is remade with one command — green and red here, where the French
app is blue and red:

```bash
swiftc -O -parse-as-library -o /tmp/icone outils/icone.swift && /tmp/icone
```

---

## 8. Build and upload

```bash
xcodegen generate
xcodebuild -scheme RiskeloUS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
xcodebuild -scheme RiskeloUS -destination 'generic/platform=iOS' \
           -archivePath ~/Desktop/RiskeloUS-ios.xcarchive archive
```

Then Xcode ▸ Window ▸ Organizer ▸ the archive ▸ **Distribute App** ▸ *App Store
Connect* ▸ *Upload*. The build shows up in App Store Connect a few minutes
later, once processing finishes.

The build number has to **climb with every upload**: the same `1` cannot be
sent twice. Change it in `project.yml` (`CURRENT_PROJECT_VERSION`), never in
Xcode — `xcodegen generate` rewrites the project.

---

## 9. The Mac App Store

One target for iPhone, iPad and Mac; on the record that is **two platforms
under one app**, each with its own screenshots and its own upload. The text can
be identical.

The Mac App Store requires the **sandbox**, and the project has it, in
`Resources/RiskeloUS-mac.entitlements`:

| Key | What it says |
|---|---|
| `com.apple.security.app-sandbox` | Shuts the app in. Required by the Mac App Store. |
| `com.apple.security.network.client` | Lets it go out and find the other device. |
| `com.apple.security.network.server` | Lets it be found by that device. |

The last two matter as much as the first: **the sandbox cuts the network off**,
and without them the Mac and the iPhone would stop seeing each other with
nothing on screen to explain why. The setting applies to the Mac only —
`project.yml` puts it under `CODE_SIGN_ENTITLEMENTS[sdk=macosx*]`.

**Not verified on this app.** The French app was tested on real hardware and
the link held with the sandbox on; the configuration here is the same file
under a new name, but the Bonjour service name changed (`_riskelo-us._tcp`) and
that is exactly the kind of thing that fails silently. Run the check before
shipping the Mac:

1. Wi-Fi on at both ends, both machines in the same room.
2. On the Mac: open the project and run (`⌘R`).
3. On the iPhone: plug it in, select it as the destination, run (`⌘R`).
4. On one of them: **Play on several devices** ▸ *Open a table*.
5. On the other: **Play on several devices** ▸ *Join a table*, then tap the
   name that appears.
6. If the Mac asks for the local network permission, **accept**.
7. If nothing comes after a minute: **swap the roles**. That is the usual
   remedy, and it does not mean the sandbox is at fault.

Nothing forces both platforms out on the same day. The iPhone can go alone and
the Mac join later under the same record.

---

## 10. Order of operations

- [ ] **Apple Developer Program** membership active ($99/year)
- [ ] **Free Applications** contract signed in App Store Connect ▸ Agreements,
      Tax and Banking — an unsigned contract blocks the release without
      explaining itself
- [ ] If the app is paid, or the packs are sold: paid contract, banking and tax
      details
- [ ] GitHub Pages switched on, `docs/` translated and renamed, the four
      addresses in section 2 returning 200
- [ ] A support page that exists, and `supportURL` added to `ManualView`
- [ ] App ID `com.oulhen.riskelo.us` registered on the portal
- [ ] Record created in App Store Connect (the name is reserved at that moment
      — settle section 4 first)
- [ ] Tests green, a game played on each machine, a two-device game both ways
- [ ] Archive uploaded, build processed and visible on the record
- [ ] TestFlight run on a real device
- [ ] Section 4 text pasted
- [ ] Screenshots **retaken in English** and uploaded
- [ ] Section 5 questionnaires answered
- [ ] Section 6 notes pasted
- [ ] Price and availability chosen
- [ ] The seventeen in-app purchases created and **attached to the version**
- [ ] Purchases tried with a sandbox account on a real device
- [ ] Submitted for review

Expect two to forty-eight hours. Answer any reviewer question quickly: a thread
left hanging goes back to the bottom of the queue.

---

## 11. What is left to decide

| Point | Why it is yours |
|---|---|
| The Store name | Two apps cannot share one name. Section 4 lays out the trade-off; it has to be settled before the record is created, because that is when the name is reserved. |
| The app's price | Free makes players, paid makes revenue. With seventeen packs on sale, free plus packs is the usual shape — but it is a decision, not a default. |
| The price of the packs | $2.99 is a placeholder in the test file. |
| Family Sharing on the packs | On in the test file. Fairer for a household with two children. |
| The review phone number | Apple requires it; it is never made public. |
| Automatic or manual release | Manual if you want to pick the day. |
| macOS now or later | The sandbox is configured but the link has not been tested on this app. Section 9. |
| The subtitle | Four candidates in section 4; it is the only text read before the description. |

---

## 12. What is still French in this project

Not blockers for the binary, but all of them show to a user or a reviewer:

| Thing | State |
|---|---|
| `docs/` | The French site, French filenames. Blocks the two required URLs. |
| `soumission/` | The French app's dossier — this file supersedes its submission sheet. The screenshots inside are of the French UI. |
| `README.md` | French. |
| `outils/icone.swift` | French comments and identifiers. Runs fine. |
| `outils/listen.swift`, `outils/captures.py` | French. `captures.py` also still names the French scheme and screens. |
