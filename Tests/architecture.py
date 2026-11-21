"""Reject mixed/legacy architecture packages before they can be delivered."""
import importlib.util
import re
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('touchflow_verify', ROOT/'Tools/verify_package.py')
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


def header(cpu=0x0100000c, subtype=0x80000002):
    return struct.pack('<8I', 0xfeedfacf, cpu, subtype, 6, 0, 0, 0, 0)


class ArchitectureTests(unittest.TestCase):
    def test_modern_thin_arm64e_accepted(self):
        self.assertEqual(verifier.require_arm64e_header(header()), 0x80000002)

    def test_arm64_and_legacy_subtypes_rejected(self):
        for subtype in (0, 1, 2, 0x80000000):
            with self.subTest(subtype=hex(subtype)), self.assertRaises(AssertionError):
                verifier.require_arm64e_header(header(subtype=subtype))

    def test_wrong_cpu_rejected(self):
        with self.assertRaises(AssertionError):
            verifier.require_arm64e_header(header(cpu=0x01000007))

    def test_fat_and_other_macho_headers_rejected(self):
        for magic in verifier.MACHO_MAGICS - {bytes.fromhex('cffaedfe')}:
            with self.subTest(magic=magic.hex()), self.assertRaises(AssertionError):
                verifier.require_arm64e_header(magic + header()[4:])

    def test_truncated_header_rejected(self):
        for size in (0, 3, 12, 31):
            with self.subTest(size=size), self.assertRaises(AssertionError):
                verifier.require_arm64e_header(header()[:size])

    def test_single_shared_build_setting_and_description(self):
        shared = (ROOT/'HaogeTouchFlowBuild.mk').read_text()
        self.assertEqual(re.findall(r'^ARCHS\s*=\s*(.*?)\s*$', shared, re.M), ['arm64e'])
        for name, include in (
            ('Makefile', 'include HaogeTouchFlowBuild.mk'),
            ('HaogeTouchFlowPrefs/Makefile', 'include ../HaogeTouchFlowBuild.mk'),
        ):
            contents = (ROOT/name).read_text()
            self.assertIn(include, contents)
            self.assertNotRegex(contents, r'(?m)^\s*ARCHS\s*[:?+]?=')
        description = next(line for line in (ROOT/'control').read_text().splitlines()
                           if line.startswith('Description:'))
        self.assertIn('64e单架构', description)


if __name__ == '__main__':
    unittest.main()
