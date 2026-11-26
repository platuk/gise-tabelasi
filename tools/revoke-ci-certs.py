"""Eski imza sertifikalarını App Store Connect API ile iptal eder (yalnızca TestFlight iş akışında çalışır).

Neden: GitHub'ın macOS makineleri her seferinde sıfırdan açılır. Xcode otomatik imzalamada her yüklemede
yeni bir "Apple Distribution" ve "Apple Development" sertifikası üretir; özel anahtarları makineyle birlikte
silindiği için eski sertifikalar bir daha kullanılamaz ve hesap sertifika sınırına dolar.
Bu betik imzalamadan hemen önce bu işe yaramaz sertifikaları iptal eder; ardından Xcode tek bir yenisini üretir.

Not: Bu takımın elle (bir Mac'te) oluşturulmuş dağıtım sertifikaları da iptal edilir. Takımda Mac ile imzalama
yapılmaya başlanırsa bu adım kaldırılmalı ve sertifika GitHub secret olarak saklanmalıdır.

Gerekli ortam değişkenleri: KEY_PATH (.p8 dosyası), ASC_KEY_ID, ASC_ISSUER_ID.
İptal etmek, App Store'daki ya da TestFlight'taki mevcut build'leri etkilemez.
"""
import json
import os
import time
import urllib.parse
import urllib.request

import jwt

API = "https://api.appstoreconnect.apple.com/v1"
TYPES = ["DISTRIBUTION", "IOS_DISTRIBUTION", "DEVELOPMENT", "IOS_DEVELOPMENT"]


def token() -> str:
    with open(os.environ["KEY_PATH"]) as handle:
        key = handle.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"},
    )


def call(method: str, url: str, bearer: str) -> dict:
    request = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {bearer}"})
    with urllib.request.urlopen(request) as response:
        body = response.read()
    return json.loads(body) if body else {}


def main() -> None:
    bearer = token()
    query = urllib.parse.urlencode({"filter[certificateType]": ",".join(TYPES), "limit": "200"})
    certificates = call("GET", f"{API}/certificates?{query}", bearer).get("data", [])
    print(f"Bulunan imza sertifikası: {len(certificates)}")
    for certificate in certificates:
        attributes = certificate.get("attributes", {})
        call("DELETE", f"{API}/certificates/{certificate['id']}", bearer)
        print(f"İptal edildi: {attributes.get('certificateType')} · {attributes.get('name')} · bitiş {attributes.get('expirationDate')}")
    print("Tamam: Xcode imzalarken tek bir yeni sertifika üretecek.")


if __name__ == "__main__":
    main()
