import importlib.util
import hashlib
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).resolve().parents[1] / "download-install.py"
SPEC = importlib.util.spec_from_file_location("ov500_download_install", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class GitHubReleaseUrlTests(unittest.TestCase):
    def metadata(self, repository="owner/repo", tag="v1.2.3", asset="billing.tar.gz"):
        return {
            "sha256": "a" * 64,
            "github_release": {
                "repository": repository,
                "tag": tag,
                "asset": asset,
                "signature_asset": asset + ".sig",
            },
        }

    def test_builds_fixed_github_release_asset_url(self):
        self.assertEqual(
            MODULE.release_url(self.metadata("example-org/example-installer", "v1.2.3", "billing.tar.gz")),
            "https://github.com/example-org/example-installer/releases/download/v1.2.3/billing.tar.gz",
        )

    def test_builds_detached_signature_asset_url(self):
        metadata = self.metadata("example-org/example-installer", "v1.2.3", "billing.tar.gz")
        self.assertEqual(
            MODULE.release_url(metadata, metadata["github_release"]["signature_asset"]),
            "https://github.com/example-org/example-installer/releases/download/v1.2.3/billing.tar.gz.sig",
        )

    def test_rejects_unconfigured_repository(self):
        with self.assertRaisesRegex(ValueError, "OWNER/REPOSITORY"):
            MODULE.release_url(self.metadata("", "", "billing.tar.gz"))

    def test_rejects_path_traversal_and_branch_like_tag(self):
        for metadata in (
            self.metadata("owner/../repo", "v1", "billing.tar.gz"),
            self.metadata("owner/repo", "../main", "billing.tar.gz"),
            self.metadata("owner/repo", "v1", "../billing.tar.gz"),
        ):
            with self.subTest(metadata=metadata), self.assertRaises(ValueError):
                MODULE.release_url(metadata)

    def test_rejects_arbitrary_url_and_missing_pinned_hash(self):
        with self.assertRaises(ValueError):
            MODULE.release_url({"sha256": "a" * 64, "url": "https://example.test/archive"})
        metadata = self.metadata()
        metadata["sha256"] = "unpinned"
        with self.assertRaisesRegex(ValueError, "SHA256"):
            MODULE.release_url(metadata)


class DetachedSignatureTests(unittest.TestCase):
    def test_accepts_valid_ed25519_signature_and_rejects_tampering(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            archive = root / "release.tar.gz"
            private = root / "test-private.pem"
            public = root / "test-public.pem"
            signature = root / "release.sig"
            archive.write_bytes(b"isolated test release payload")
            subprocess.run(["openssl", "genpkey", "-algorithm", "ED25519", "-out", str(private)], check=True, capture_output=True)
            subprocess.run(["openssl", "pkey", "-in", str(private), "-pubout", "-out", str(public)], check=True, capture_output=True)
            digest_file = root / "release.sha256.bin"
            digest_file.write_bytes(hashlib.sha256(archive.read_bytes()).digest())
            subprocess.run(["openssl", "pkeyutl", "-sign", "-inkey", str(private), "-rawin", "-in", str(digest_file), "-out", str(signature)], check=True, capture_output=True)
            MODULE.verify_signature(archive, signature, public.read_bytes())
            archive.write_bytes(b"tampered release payload")
            with self.assertRaisesRegex(ValueError, "signature verification failed"):
                MODULE.verify_signature(archive, signature, public.read_bytes())


if __name__ == "__main__":
    unittest.main()
