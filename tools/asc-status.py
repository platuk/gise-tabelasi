"""App Store sürümlerinin ve inceleme gönderimlerinin durumunu yazdırır (salt okunur)."""
import importlib.util
import pathlib

spec = importlib.util.spec_from_file_location("asc", pathlib.Path(__file__).with_name("asc-appstore.py"))
asc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(asc)

asc.BEARER = asc.token()
app = asc.find_app()
for v in asc.call("GET", f"/v1/apps/{app['id']}/appStoreVersions", params={"limit": "5"})["data"]:
    a = v["attributes"]
    print(f"Sürüm {a['versionString']}: {a.get('appVersionState') or a.get('appStoreState')} (oluşturma {a.get('createdDate')})")
for s in asc.call("GET", "/v1/reviewSubmissions", params={"filter[app]": app["id"], "limit": "5"})["data"]:
    a = s["attributes"]
    print(f"Gönderim {s['id'][:8]}: {a.get('state')} (gönderilme {a.get('submittedDate')})")
