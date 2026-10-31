import hashlib
import importlib.util
import json
import tempfile
import tarfile
import unittest
from pathlib import Path

SOURCE = Path(__file__).resolve().parents[1] / "download-install.py"
SPEC = importlib.util.spec_from_file_location("ov500_download_install", SOURCE)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class ArchiveManifestTests(unittest.TestCase):
    def test_nested_manifest_is_part_of_release_inventory(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            package = base / "voipalbania-billing-go"
            (package / "assets").mkdir(parents=True)
            payload = b'{"component":"test"}\n'
            (package / "assets/manifest.json").write_bytes(payload)
            (package / "install.py").write_text("# isolated fixture\n")
            files = {}
            for path in package.rglob("*"):
                if path.is_file():
                    files[str(path.relative_to(package))] = hashlib.sha256(path.read_bytes()).hexdigest()
            (package / "manifest.json").write_text(json.dumps({"files": files}))
            archive = base / "release.tar.gz"
            with tarfile.open(archive, "w:gz") as stream:
                stream.add(package, arcname="voipalbania-billing-go")
            extracted, count = MODULE.unpack(archive, base / "extracted")
            self.assertEqual(count, 2)
            self.assertEqual((extracted / "assets/manifest.json").read_bytes(), payload)

    def test_nested_manifest_tampering_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary)
            package = base / "voipalbania-billing-go"
            (package / "assets").mkdir(parents=True)
            (package / "assets/manifest.json").write_text("original")
            (package / "install.py").write_text("# fixture")
            files = {str(path.relative_to(package)): hashlib.sha256(path.read_bytes()).hexdigest()
                     for path in package.rglob("*") if path.is_file()}
            (package / "manifest.json").write_text(json.dumps({"files": files}))
            (package / "assets/manifest.json").write_text("altered")
            archive = base / "release.tar.gz"
            with tarfile.open(archive, "w:gz") as stream:
                stream.add(package, arcname="voipalbania-billing-go")
            with self.assertRaisesRegex(ValueError, "Release file inventory mismatch|Release file integrity mismatch"):
                MODULE.unpack(archive, base / "extracted")


if __name__ == "__main__":
    unittest.main()
