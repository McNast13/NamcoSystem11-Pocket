import os, sys, tempfile, unittest, zipfile, zlib
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "tools"))
import rom_packer as rp


class Place(unittest.TestCase):
    def test_interleave_16(self):
        img, cur = bytearray(), [0] * 8
        rp.place(img, b"\x01\x02", 2, 0x01, cur)   # byte 0 of each word
        rp.place(img, b"\xAA\xBB", 2, 0x10, cur)   # byte 1 of the same words
        self.assertEqual(bytes(img), b"\x01\xAA\x02\xBB")

    def test_map10_is_byte1(self):
        img = bytearray()
        rp.place(img, b"\xAA\xBB", 2, 0x10)
        self.assertEqual(bytes(img), b"\x00\xAA\x00\xBB")

    def test_bad_length(self):
        with self.assertRaises(rp.PackError):
            rp.place(bytearray(), b"abc", 4, 0x0011)


class PackMra(unittest.TestCase):
    def test_roundtrip_and_crc(self):
        with tempfile.TemporaryDirectory() as d:
            lo, hi = b"\x11\x22", b"\xAA\xBB"
            with zipfile.ZipFile(os.path.join(d, "g.zip"), "w") as z:
                z.writestr("lo", lo); z.writestr("hi", hi)
            mra = os.path.join(d, "g.mra")
            open(mra, "w").write(f'''<m><rom index="0" zip="g.zip"><interleave output="16">
              <part name="lo" crc="{zlib.crc32(lo):08x}" map="01"/>
              <part name="hi" crc="{zlib.crc32(hi):08x}" map="10"/></interleave></rom>
              <rom index="1"><part>14 01</part></rom></m>''')
            out = rp.pack(mra, d)
            self.assertEqual(out[0], b"\x11\xAA\x22\xBB")
            self.assertEqual(out[1], b"\x14\x01")
            text = open(mra).read().replace(f"{zlib.crc32(lo):08x}", "deadbeef")
            open(mra, "w").write(text)
            with self.assertRaises(rp.PackError):
                rp.pack(mra, d)


if __name__ == "__main__":
    unittest.main()
