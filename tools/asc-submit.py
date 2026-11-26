"""Düzenlenebilir App Store sürümünü Apple'ın incelemesine gönderir (App Store Connect'teki "Add for Review" + "Submit").

Önce sürüme bir derleme bağlı mı ve inceleme bilgileri var mı diye bakar; eksik varsa göndermez.
Kullanım: KEY_PATH=... ASC_KEY_ID=... ASC_ISSUER_ID=... python asc-submit.py
"""
import importlib.util
import pathlib
import sys

spec = importlib.util.spec_from_file_location("asc", pathlib.Path(__file__).with_name("asc-appstore.py"))
asc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(asc)


def main():
    asc.BEARER = asc.token()
    app = asc.find_app()
    version = asc.editable_version(app)
    state = version["attributes"].get("appVersionState") or version["attributes"].get("appStoreState")
    if state not in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"):
        sys.exit(f"Sürüm gönderilebilir durumda değil: {state}")

    build = asc.call("GET", f"/v1/appStoreVersions/{version['id']}/build").get("data")
    if not build:
        sys.exit("Sürüme bağlı derleme yok")
    print(f"Derleme: {build['attributes']['version']} ({build['attributes'].get('processingState')})")
    detail = asc.call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
    if not detail:
        sys.exit("İnceleme bilgileri yok")
    attachments = asc.call("GET", f"/v1/appStoreReviewDetails/{detail['id']}/appStoreReviewAttachments")["data"]
    print("İnceleme ekleri: " + (", ".join(a["attributes"]["fileName"] for a in attachments) or "yok"))

    # Açık (henüz gönderilmemiş) bir gönderim varsa o kullanılır.
    submissions = asc.call("GET", "/v1/reviewSubmissions", params={
        "filter[app]": app["id"], "filter[platform]": "IOS", "filter[state]": "READY_FOR_REVIEW"})["data"]
    if submissions:
        submission = submissions[0]
        print(f"Açık gönderim kullanılıyor: {submission['id']}")
    else:
        submission = asc.call("POST", "/v1/reviewSubmissions", {"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": {"data": {"type": "apps", "id": app["id"]}}}}})["data"]
        print(f"Yeni gönderim: {submission['id']}")

    items = asc.call("GET", f"/v1/reviewSubmissions/{submission['id']}/items",
                     params={"include": "appStoreVersion"})["data"]
    has_version = any((i.get("relationships", {}).get("appStoreVersion", {}).get("data") or {}).get("id") == version["id"]
                      for i in items)
    if not has_version:
        asc.call("POST", "/v1/reviewSubmissionItems", {"data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission["id"]}},
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version["id"]}}}}})
        print("Sürüm gönderime eklendi")

    result = asc.call("PATCH", f"/v1/reviewSubmissions/{submission['id']}", {"data": {
        "type": "reviewSubmissions", "id": submission["id"], "attributes": {"submitted": True}}})["data"]
    print(f"Gönderim durumu: {result['attributes'].get('state')}")
    version = asc.call("GET", f"/v1/appStoreVersions/{version['id']}")["data"]
    print(f"Sürüm durumu: {version['attributes'].get('appVersionState') or version['attributes'].get('appStoreState')}")


if __name__ == "__main__":
    try:
        main()
    except asc.ApiError as error:
        sys.exit(f"HATA: {error}")
