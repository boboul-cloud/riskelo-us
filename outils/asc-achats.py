#!/usr/bin/env python3
"""
asc-achats.py — Riskelo US, outil hors application

Crée les dix-sept achats intégrés dans App Store Connect par l'API officielle,
plutôt qu'à la main dans dix-sept formulaires.

Ce qu'il fait, pour chaque pack déclaré dans Resources/Questions/*.txt :

  1. crée l'article (non consommable, partage familial activé) ;
  2. ajoute sa localisation anglais États-Unis — nom affiché et description ;
  3. téléverse sa capture de vérification.

Ce qu'il ne fait pas, volontairement : le prix. Il n'est pas décidé, et le
poser par l'API demande de choisir un « price point » par territoire — une
mécanique à part, qui mérite d'être vue avant d'être subie. Dix-sept prix se
posent vite dans l'interface une fois le reste en place.

Il ne fait rien sans --apply. Par défaut il liste ce qu'il ferait, en
comparant à ce qui existe déjà : relancé après un échec au douzième article,
il reprend au douzième.

    python3 outils/asc-achats.py                 # à blanc
    python3 outils/asc-achats.py --apply         # pour de vrai

Il lui faut outils/asc-config.json, qui n'est pas versionné :

    {
      "issuer_id": "...",            Utilisateurs et accès ▸ Intégrations
      "key_id":    "...",            l'identifiant de la clé
      "key_file":  "AuthKey_XXX.p8", le fichier téléchargé, gardé hors dépôt
      "app_id":    "..."             l'identifiant Apple de l'app, sur sa fiche
    }

La clé privée ouvre le compte développeur : elle ne se met pas dans le dépôt,
et .gitignore l'en empêche.
"""

import base64, glob, hashlib, json, os, re, subprocess, sys, time, urllib.error, urllib.request

RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.appstoreconnect.apple.com"


# --- Le jeton -------------------------------------------------------------
#
# ES256 sans bibliothèque : openssl signe, et l'on convertit sa signature DER
# en la paire R||S de 64 octets que veut JWT. C'est la seule partie du script
# qui ne soit pas de la plomberie HTTP.

def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def der_en_rs(der: bytes) -> bytes:
    if der[0] != 0x30:
        raise ValueError("signature DER attendue")
    i = 2 if der[1] < 0x80 else 3 + (der[1] & 0x7F) - 1
    out = b""
    for _ in range(2):
        if der[i] != 0x02:
            raise ValueError("entier DER attendu")
        n = der[i + 1]
        v = der[i + 2 : i + 2 + n].lstrip(b"\x00")
        out += v.rjust(32, b"\x00")
        i += 2 + n
    return out


def jeton(cfg) -> str:
    tete = {"alg": "ES256", "kid": cfg["key_id"], "typ": "JWT"}
    corps = {"iss": cfg["issuer_id"], "iat": int(time.time()),
             "exp": int(time.time()) + 15 * 60, "aud": "appstoreconnect-v1"}
    signe = b64(json.dumps(tete).encode()) + "." + b64(json.dumps(corps).encode())
    p = subprocess.run(["openssl", "dgst", "-sha256", "-sign", cfg["_key_path"]],
                       input=signe.encode(), capture_output=True)
    if p.returncode:
        raise SystemExit("openssl : " + p.stderr.decode())
    return signe + "." + b64(der_en_rs(p.stdout))


# --- L'API ----------------------------------------------------------------

def appel(cfg, methode, chemin, corps=None, brut=None, type_contenu=None):
    url = chemin if chemin.startswith("http") else API + chemin
    donnees = brut if brut is not None else (json.dumps(corps).encode() if corps else None)
    r = urllib.request.Request(url, data=donnees, method=methode)
    r.add_header("Authorization", "Bearer " + jeton(cfg))
    if brut is None and corps:
        r.add_header("Content-Type", "application/json")
    if type_contenu:
        r.add_header("Content-Type", type_contenu)
    try:
        with urllib.request.urlopen(r) as rep:
            t = rep.read()
            return json.loads(t) if t and rep.headers.get_content_type() == "application/json" else None
    except urllib.error.HTTPError as e:
        detail = e.read().decode()
        try:
            for err in json.loads(detail).get("errors", []):
                detail = "%s — %s" % (err.get("title", ""), err.get("detail", ""))
        except Exception:
            pass
        raise SystemExit("%s %s\n  %s %s\n  %s" % (e.code, e.reason, methode, chemin, detail))


# --- Ce qu'il y a à créer -------------------------------------------------

def packs():
    """Les packs, lus dans les fichiers de questions — la seule source."""
    out = []
    for chemin in sorted(glob.glob(os.path.join(RACINE, "Resources/Questions/*.txt"))):
        tete, n = {}, 0
        for ligne in open(chemin, encoding="utf-8"):
            ligne = ligne.strip()
            if ligne.startswith("!"):
                k, _, v = ligne[1:].partition("|")
                tete[k.strip()] = v.strip()
            elif ligne and not ligne.startswith("#"):
                n += 1
        if tete.get("product"):
            out.append({"rang": int(tete["rank"]), "id": tete["product"],
                        "affiche": tete["name"], "questions": n})
    out.sort(key=lambda p: p["rang"])
    return out


def fiche():
    """Nom de référence, description courte et capture : ils sont dans la
    fiche de soumission, qui est le document où on les a comptés."""
    s = open(os.path.join(RACINE, "submission/SUBMISSION-SHEET.md"), encoding="utf-8").read()
    lignes = re.findall(r"^\| ([A-Za-z0-9 ]+Pack) \| `(com\.oulhen[^`]+)` \| ([^|]+?) \| `([^`]+)` \|$", s, re.M)
    captures = dict(re.findall(r"^\| ([^|]+?) \| `(iap-review-[^`]+)` \|$", s, re.M))
    par_id = {}
    for ref, pid, affiche, desc in lignes:
        affiche = affiche.strip()
        par_id[pid] = {"reference": ref, "description": desc,
                       "capture": captures.get(affiche)}
    return par_id


def existants(cfg):
    out, url = {}, "/v1/apps/%s/inAppPurchasesV2?limit=200" % cfg["app_id"]
    while url:
        rep = appel(cfg, "GET", url)
        for d in rep["data"]:
            out[d["attributes"]["productId"]] = d["id"]
        url = rep.get("links", {}).get("next")
    return out


# --- Les trois gestes -----------------------------------------------------

def cree(cfg, pack, ref):
    rep = appel(cfg, "POST", "/v2/inAppPurchases", {"data": {
        "type": "inAppPurchases",
        "attributes": {"name": ref["reference"], "productId": pack["id"],
                       "inAppPurchaseType": "NON_CONSUMABLE", "familySharable": True,
                       "reviewNote": "The pack appears on the Packs screen, "
                                     "reachable from the home screen. See the "
                                     "review screenshot."},
        "relationships": {"app": {"data": {"type": "apps", "id": cfg["app_id"]}}}}})
    return rep["data"]["id"]


def localise(cfg, iap_id, pack, ref):
    appel(cfg, "POST", "/v1/inAppPurchaseLocalizations", {"data": {
        "type": "inAppPurchaseLocalizations",
        "attributes": {"name": pack["affiche"], "locale": "en-US",
                       "description": ref["description"]},
        "relationships": {"inAppPurchaseV2": {
            "data": {"type": "inAppPurchases", "id": iap_id}}}}})


def capture(cfg, iap_id, chemin):
    octets = open(chemin, "rb").read()
    rep = appel(cfg, "POST", "/v1/inAppPurchaseAppStoreReviewScreenshots", {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots",
        "attributes": {"fileName": os.path.basename(chemin), "fileSize": len(octets)},
        "relationships": {"inAppPurchaseV2": {
            "data": {"type": "inAppPurchases", "id": iap_id}}}}})
    sid = rep["data"]["id"]
    for op in rep["data"]["attributes"]["uploadOperations"]:
        part = octets[op["offset"]: op["offset"] + op["length"]]
        r = urllib.request.Request(op["url"], data=part, method=op["method"])
        for h in op["requestHeaders"]:
            r.add_header(h["name"], h["value"])
        urllib.request.urlopen(r).read()
    appel(cfg, "PATCH", "/v1/inAppPurchaseAppStoreReviewScreenshots/" + sid, {"data": {
        "type": "inAppPurchaseAppStoreReviewScreenshots", "id": sid,
        "attributes": {"uploaded": True,
                       "sourceFileChecksum": hashlib.md5(octets).hexdigest()}}})


# --- Le déroulé -----------------------------------------------------------

def main():
    applique = "--apply" in sys.argv
    conf = os.path.join(RACINE, "outils/asc-config.json")
    if not os.path.exists(conf):
        raise SystemExit("Il manque outils/asc-config.json — voir l'en-tête de ce fichier.")
    cfg = json.load(open(conf))
    cfg["_key_path"] = cfg["key_file"] if os.path.isabs(cfg["key_file"]) \
        else os.path.join(RACINE, "outils", cfg["key_file"])
    if not os.path.exists(cfg["_key_path"]):
        raise SystemExit("Clé introuvable : " + cfg["_key_path"])

    liste, refs = packs(), fiche()
    manquants = [p["id"] for p in liste if p["id"] not in refs]
    if manquants:
        raise SystemExit("Absents de la fiche de soumission : " + ", ".join(manquants))
    for p in liste:
        c = refs[p["id"]]["capture"]
        if not c or not os.path.exists(os.path.join(RACINE, "submission/screenshots", c)):
            raise SystemExit("Capture manquante pour " + p["id"])

    deja = existants(cfg) if applique or "--check" in sys.argv else {}
    print("%d packs déclarés · %d déjà dans App Store Connect\n" % (len(liste), len(deja)))

    for i, p in enumerate(liste, 1):
        ref = refs[p["id"]]
        etat = "déjà là" if p["id"] in deja else ("créé" if applique else "à créer")
        print("%2d/%d  %-22s %-38s %s" % (i, len(liste), p["affiche"], p["id"], etat))
        if not applique or p["id"] in deja:
            continue
        iap = cree(cfg, p, ref)
        localise(cfg, iap, p, ref)
        capture(cfg, iap, os.path.join(RACINE, "submission/screenshots", ref["capture"]))
        print("       → %s, localisé, capture déposée" % iap)

    if not applique:
        print("\nÀ blanc. Rien n'a été envoyé. Relancer avec --apply pour écrire.")
        print("Le prix reste à poser dans l'interface : il n'est pas décidé.")


if __name__ == "__main__":
    main()
