"""İnceleme videosunu App Store Connect > App Review Information > Attachment alanına yükler.

Eski ekler silinir, yenisi yüklenir. Yalnızca Apple'ın inceleme ekibi görür.
Kullanım: KEY_PATH=... ASC_KEY_ID=... ASC_ISSUER_ID=... python asc-review-attachment.py <video.mp4>
"""
import hashlib
import importlib.util
import pathlib
import sys
import urllib.request

spec = importlib.util.spec_from_file_location("asc", pathlib.Path(__file__).with_name("asc-appstore.py"))
asc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(asc)


def main():
    video = pathlib.Path(sys.argv[1])
    data = video.read_bytes()
    asc.BEARER = asc.token()
    app = asc.find_app()
    version = asc.editable_version(app)
    detail = asc.call("GET", f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
    if not detail:
        sys.exit("İnceleme bilgisi (App Review Information) yok; önce appstore iş akışını çalıştır")
    old = asc.call("GET", f"/v1/appStoreReviewDetails/{detail['id']}/appStoreReviewAttachments")["data"]
    for attachment in old:
        asc.call("DELETE", f"/v1/appStoreReviewAttachments/{attachment['id']}")
        print(f"Eski ek silindi: {attachment['attributes'].get('fileName')}")
    reservation = asc.call("POST", "/v1/appStoreReviewAttachments", {"data": {
        "type": "appStoreReviewAttachments",
        "attributes": {"fileName": video.name, "fileSize": len(data)},
        "relationships": {"appStoreReviewDetail": {"data": {"type": "appStoreReviewDetails", "id": detail["id"]}}}}})["data"]
    for op in reservation["attributes"]["uploadOperations"]:
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        request = urllib.request.Request(op["url"], data=chunk, method=op["method"], headers=headers)
        with urllib.request.urlopen(request) as response:
            response.read()
    asc.call("PATCH", f"/v1/appStoreReviewAttachments/{reservation['id']}", {"data": {
        "type": "appStoreReviewAttachments", "id": reservation["id"],
        "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
    print(f"Yüklendi: {video.name} ({len(data) // 1024} KB)")


if __name__ == "__main__":
    main()
