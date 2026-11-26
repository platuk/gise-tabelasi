"""App Store sayfasını App Store Connect API ile doldurur (App Store iş akışında çalışır).

Yaptıkları (appstore/metadata.json ve appstore/review-notes.md'den):
  1. Uygulama bilgileri: ad (CupTower), alt başlık, gizlilik politikası URL'si (en-US ve tr), kategori
  2. Sürüm bilgileri: açıklama, anahtar kelimeler, tanıtım metni, destek ve pazarlama URL'si, telif
  3. Yaş sınırı anketi (beklenen sonuç: 9+)
  4. App Review notu
  5. Ekran görüntüleri (6.9" iPhone): set içindekiler silinip yenileri yüklenir
Yapamadıkları (API'de yok): "Uygulama Gizliliği" formu (Veri toplanmıyor) tarayıcıdan doldurulur.

Ortam: KEY_PATH, ASC_KEY_ID, ASC_ISSUER_ID; SCREENSHOTS (çerçeveli görsellerin klasörü, isteğe bağlı).
Her bölüm ayrı denenir; biri başarısız olursa ötekiler yine yapılır, en sonda hata kodu döner.
"""
import hashlib
import json
import os
import pathlib
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com"
ROOT = pathlib.Path(__file__).resolve().parent.parent
META = json.loads((ROOT / "appstore" / "metadata.json").read_text(encoding="utf-8"))
BUNDLE_ID = "com.ojfamilia.gisetabelasi"
DISPLAY_TYPE = "APP_IPHONE_67"  # 6.9"/6.7" iPhone seti (1290x2796 kabul edilir)
EDITABLE = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
            "INVALID_BINARY", "WAITING_FOR_REVIEW"}
FAILURES = []


class ApiError(Exception):
    pass


def token():
    key = pathlib.Path(os.environ["KEY_PATH"]).read_text()
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 1100, "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


BEARER = None


def call(method, path, body=None, params=None):
    url = path if path.startswith("http") else API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(url, data=data, method=method,
                                     headers={"Authorization": f"Bearer {BEARER}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace")
        try:
            errors = json.loads(detail).get("errors", [])
            detail = "; ".join(f"{e.get('title')}: {e.get('detail')}" for e in errors) or detail
        except ValueError:
            pass
        raise ApiError(f"{method} {path} -> {error.code}: {detail}") from None
    return json.loads(raw) if raw else {}


def section(title):
    def wrap(fn):
        def run(*args):
            print(f"\n== {title}")
            try:
                fn(*args)
                print(f"   tamam: {title}")
            except ApiError as error:
                FAILURES.append(f"{title}: {error}")
                print(f"   HATA: {error}")
        return run
    return wrap


def find_app():
    apps = call("GET", "/v1/apps", params={"filter[bundleId]": BUNDLE_ID})["data"]
    if not apps:
        raise SystemExit(f"{BUNDLE_ID} App Store Connect'te bulunamadı")
    app = apps[0]
    print(f"Uygulama: {app['attributes']['name']} ({app['id']}), ana dil {app['attributes'].get('primaryLocale')}")
    return app


def editable_app_info(app):
    infos = call("GET", f"/v1/apps/{app['id']}/appInfos")["data"]
    for info in infos:
        state = info["attributes"].get("state") or info["attributes"].get("appStoreState")
        if state not in ("READY_FOR_DISTRIBUTION", "READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"):
            return info
    return infos[0]


def editable_version(app):
    versions = call("GET", f"/v1/apps/{app['id']}/appStoreVersions",
                    params={"filter[platform]": "IOS", "limit": "10"})["data"]
    for version in versions:
        state = version["attributes"].get("appVersionState") or version["attributes"].get("appStoreState")
        if state in EDITABLE or state in ("PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"):
            print(f"Sürüm: {version['attributes']['versionString']} ({state})")
            return version
    print("Düzenlenebilir sürüm yok; 1.0 oluşturuluyor")
    return call("POST", "/v1/appStoreVersions", {"data": {
        "type": "appStoreVersions",
        "attributes": {"platform": "IOS", "versionString": "1.0"},
        "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})["data"]


def upsert_localization(kind, parent_rel, parent_type, parent_id, existing, locale, attributes):
    match = next((l for l in existing if l["attributes"]["locale"] == locale), None)
    if match:
        call("PATCH", f"/v1/{kind}/{match['id']}",
             {"data": {"type": kind, "id": match["id"], "attributes": attributes}})
        return match["id"]
    created = call("POST", f"/v1/{kind}", {"data": {
        "type": kind, "attributes": {"locale": locale, **attributes},
        "relationships": {parent_rel: {"data": {"type": parent_type, "id": parent_id}}}}})
    return created["data"]["id"]


@section("Uygulama bilgileri: ad, alt başlık, gizlilik URL'si")
def app_info_texts(info):
    existing = call("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]
    errors = []
    for locale, texts in META["locales"].items():
        try:
            upsert_localization("appInfoLocalizations", "appInfo", "appInfos", info["id"], existing, locale, {
                "name": texts["name"], "subtitle": texts["subtitle"], "privacyPolicyUrl": META["privacyPolicyUrl"]})
            print(f"   {locale}: {texts['name']} · {texts['subtitle']}")
        except ApiError as error:
            errors.append(f"{locale}: {error}")
            print(f"   {locale}: HATA {error}")
    if errors:
        raise ApiError(" | ".join(errors))


@section("Kategori: Oyunlar > Arcade, Aksiyon")
def category(info):
    primary = {"primaryCategory": {"data": {"type": "appCategories", "id": META["primaryCategory"]}}}
    subs = {name: {"data": {"type": "appCategories", "id": sub}}
            for name, sub in zip(["primarySubcategoryOne", "primarySubcategoryTwo"], META["subcategories"])}
    # Önce ana kategori, sonra alt kategoriler tek tek: biri reddedilirse ötekiler yine kalır.
    attempts = [primary] + [{**primary, name: value} for name, value in subs.items()]
    done = []
    last_error = None
    for rel in attempts:
        try:
            call("PATCH", f"/v1/appInfos/{info['id']}",
                 {"data": {"type": "appInfos", "id": info["id"], "relationships": rel}})
            done.append(next(reversed(rel)))
        except ApiError as error:
            last_error = error
            print(f"   {list(rel)[-1]}: {error}")
    print(f"   ayarlanan: {', '.join(done) or '-'}")
    if not done and last_error:
        raise last_error


@section("Sürüm bilgileri: açıklama, anahtar kelimeler, destek URL'si, telif")
def version_texts(version):
    call("PATCH", f"/v1/appStoreVersions/{version['id']}", {"data": {
        "type": "appStoreVersions", "id": version["id"], "attributes": {"copyright": META["copyright"]}}})
    existing = call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    for locale, texts in META["locales"].items():
        upsert_localization("appStoreVersionLocalizations", "appStoreVersion", "appStoreVersions", version["id"],
                            existing, locale, {
                                "description": texts["description"], "keywords": texts["keywords"],
                                "promotionalText": texts["promotionalText"], "supportUrl": META["supportUrl"],
                                "marketingUrl": META["marketingUrl"]})
        print(f"   {locale}: metinler yazıldı")


ENUM_KEYS = {
    "alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
    "medicalOrTreatmentInformation", "profanityOrCrudeHumor", "sexualContentGraphicAndNudity",
    "sexualContentOrNudity", "horrorOrFearThemes", "matureOrSuggestiveThemes", "violenceCartoonOrFantasy",
    "violenceRealisticProlongedGraphicOrSadistic", "violenceRealistic",
}
BOOL_KEYS = {
    "gambling", "unrestrictedWebAccess", "lootBox", "messagingAndChat", "parentalControls", "ageAssurance",
    "userGeneratedContent", "advertising", "healthOrWellnessTopics", "seventeenPlus",
}


@section("Yaş sınırı anketi")
def age_rating(info):
    declaration = call("GET", f"/v1/appInfos/{info['id']}/ageRatingDeclaration")["data"]
    current = declaration["attributes"]
    patch = {}
    for key in current:
        if key in ENUM_KEYS:
            patch[key] = META["ageRating"].get(key, "NONE")
        elif key in BOOL_KEYS:
            patch[key] = False
    # Apple yeni sorular ekledikçe (ör. socialMedia) API "şu alan zorunlu" der: cevabı "hayır/yok" olarak ekleyip
    # yeniden denenir. Önce evet/hayır (False) denenir; değer türü reddedilirse "NONE".
    import re
    for _ in range(30):
        try:
            call("PATCH", f"/v1/ageRatingDeclarations/{declaration['id']}", {"data": {
                "type": "ageRatingDeclarations", "id": declaration["id"], "attributes": patch}})
            break
        except ApiError as error:
            text = str(error)
            missing = re.search(r"attribute '(\w+)'", text)
            if missing and missing.group(1) not in patch:
                patch[missing.group(1)] = False
                print(f"   yeni soru: {missing.group(1)} = hayır")
                continue
            wrong = next((k for k in patch if f"'{k}'" in text or f"/{k}" in text), None)
            if wrong and patch[wrong] is False:
                patch[wrong] = "NONE"
                print(f"   {wrong}: hayır yerine 'yok'")
                continue
            raise
    unknown = sorted(set(current) - ENUM_KEYS - BOOL_KEYS)
    print(f"   {len(patch)} soru cevaplandı; dokunulmayanlar: {', '.join(unknown) or '-'}")
    print("   çizgi film şiddeti ve korku: seyrek/hafif; geri kalan: yok")


@section("App Review notu")
def review_notes(version):
    lines = (ROOT / "appstore" / "review-notes.md").read_text(encoding="utf-8").splitlines()
    notes = "\n".join(l for l in lines if not l.startswith("#")).strip()
    attributes = {"notes": notes, "demoAccountRequired": False}
    try:
        detail = call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
    except ApiError:
        detail = None
    if detail:
        try:
            call("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", {"data": {
                "type": "appStoreReviewDetails", "id": detail["id"], "attributes": attributes}})
        except ApiError as error:
            # Kayıt varken Apple iletişim bilgilerini (ad, e-posta, telefon) de ister; bunlar geliştiricinin kişisel
            # bilgileri olduğu için App Store Connect'te elle girilir. Not ilk oluşturmada kaydedilmiştir.
            if "contact" not in str(error):
                raise
            print("   not daha önce kaydedildi; güncellemek için önce App Review iletişim bilgileri elle girilmeli")
            return
    else:
        call("POST", "/v1/appStoreReviewDetails", {"data": {
            "type": "appStoreReviewDetails", "attributes": attributes,
            "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
    print(f"   {len(notes)} karakter")


def upload_screenshot(set_id, path):
    data = path.read_bytes()
    reservation = call("POST", "/v1/appScreenshots", {"data": {
        "type": "appScreenshots", "attributes": {"fileName": path.name, "fileSize": len(data)},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})["data"]
    for op in reservation["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        request = urllib.request.Request(op["url"], data=chunk, method=op["method"], headers=headers)
        with urllib.request.urlopen(request) as response:
            response.read()
    call("PATCH", f"/v1/appScreenshots/{reservation['id']}", {"data": {
        "type": "appScreenshots", "id": reservation["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})


@section("Ekran görüntüleri (6.9\" iPhone)")
def screenshots(version):
    folder = os.environ.get("SCREENSHOTS")
    if not folder or not pathlib.Path(folder).is_dir():
        print("   SCREENSHOTS klasörü yok, atlandı")
        return
    localizations = call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]
    for loc in localizations:
        locale = loc["attributes"]["locale"]
        files = sorted(pathlib.Path(folder, locale).glob("*.png"))
        if not files:
            continue
        sets = call("GET", f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets")["data"]
        target = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == DISPLAY_TYPE), None)
        if target is None:
            target = call("POST", "/v1/appScreenshotSets", {"data": {
                "type": "appScreenshotSets", "attributes": {"screenshotDisplayType": DISPLAY_TYPE},
                "relationships": {"appStoreVersionLocalization": {"data": {
                    "type": "appStoreVersionLocalizations", "id": loc["id"]}}}}})["data"]
        old = call("GET", f"/v1/appScreenshotSets/{target['id']}/appScreenshots")["data"]
        for shot in old:
            call("DELETE", f"/v1/appScreenshots/{shot['id']}")
        for path in files[:10]:
            upload_screenshot(target["id"], path)
        print(f"   {locale}: {len(old)} eski silindi, {len(files[:10])} yeni yüklendi")


def main():
    global BEARER
    BEARER = token()
    app = find_app()
    info = editable_app_info(app)
    version = editable_version(app)
    app_info_texts(info)
    category(info)
    version_texts(version)
    age_rating(info)
    review_notes(version)
    screenshots(version)
    print("\nElle yapılacak (API'de yok): App Store Connect > Uygulama Gizliliği > 'Veri toplanmıyor' > Yayımla")
    if FAILURES:
        print("\nBaşarısız bölümler:")
        for failure in FAILURES:
            print(" - " + failure)
        sys.exit(1)


if __name__ == "__main__":
    main()
