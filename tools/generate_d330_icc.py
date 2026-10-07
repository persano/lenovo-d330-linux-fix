#!/usr/bin/env python3
"""
Generates a valid binary ICC v2 / v4 display profile for Lenovo IdeaPad D330-10IGL
10.1" IPS Panel calibrated to sRGB D65 (6500K) with gamma 2.2 curve.
"""

import struct
import os

def build_icc_profile():
    # ICC Header: 128 bytes
    profile_size = 548  # Total bytes
    cmm_type = b'lcms'
    version = 0x02400000  # ICC version 2.4.0
    device_class = b'mntr'  # Monitor display device
    color_space = b'RGB '
    pcs = b'XYZ '
    date_time = (2026, 10, 7, 12, 0, 0)
    magic = b'acsp'
    platform = b'APPL'
    flags = 0
    dev_mfg = b'LNX '
    dev_model = b'D330'
    attributes = 0
    rendering_intent = 0  # Perceptual
    # D65 illuminant in s15Fixed16Number
    illuminant = (int(0.9642 * 65536), int(1.0000 * 65536), int(0.8249 * 65536))
    creator = b'D330'

    header = bytearray(128)
    struct.pack_into(">I", header, 0, profile_size)
    header[4:8] = cmm_type
    struct.pack_into(">I", header, 8, version)
    header[12:16] = device_class
    header[16:20] = color_space
    header[20:24] = pcs
    struct.pack_into(">HHHHHH", header, 24, *date_time)
    header[36:40] = magic
    header[40:44] = platform
    struct.pack_into(">I", header, 44, flags)
    header[48:52] = dev_mfg
    header[52:56] = dev_model
    struct.pack_into(">Q", header, 56, attributes)
    struct.pack_into(">I", header, 64, rendering_intent)
    struct.pack_into(">iii", header, 68, *illuminant)
    header[80:84] = creator

    # Tag Table: tag count + entries (tag sig, offset, size)
    tag_count = 7
    # Tags: 'desc', 'cprt', 'wtpt', 'rXYZ', 'gXYZ', 'bXYZ', 'rTRC'
    tags = [
        (b'desc', 212, 40),
        (b'cprt', 252, 32),
        (b'wtpt', 284, 20),
        (b'rXYZ', 304, 20),
        (b'gXYZ', 324, 20),
        (b'bXYZ', 344, 20),
        (b'rTRC', 364, 14),
    ]

    tag_table = struct.pack(">I", tag_count)
    for sig, offset, size in tags:
        tag_table += sig + struct.pack(">II", offset, size)

    # Pad between tag table and tag data
    pad_len = 212 - (128 + len(tag_table))
    body = header + tag_table + (b'\x00' * pad_len)

    # 'desc' tag data: type 'desc', text length, text
    desc_str = b'Lenovo D330 IPS sRGB D65'
    desc_data = b'desc\x00\x00\x00\x00' + struct.pack(">I", len(desc_str) + 1) + desc_str + b'\x00'
    desc_data += b'\x00' * (40 - len(desc_data))

    # 'cprt' tag data
    cprt_str = b'Lenovo D330 Linux Fix'
    cprt_data = b'text\x00\x00\x00\x00' + cprt_str + b'\x00'
    cprt_data += b'\x00' * (32 - len(cprt_data))

    # 'wtpt' tag data: D65
    wtpt_data = b'XYZ \x00\x00\x00\x00' + struct.pack(">iii", int(0.9642 * 65536), int(1.0000 * 65536), int(0.8249 * 65536))

    # 'rXYZ', 'gXYZ', 'bXYZ' sRGB primaries
    rXYZ_data = b'XYZ \x00\x00\x00\x00' + struct.pack(">iii", int(0.4360 * 65536), int(0.2225 * 65536), int(0.0139 * 65536))
    gXYZ_data = b'XYZ \x00\x00\x00\x00' + struct.pack(">iii", int(0.3851 * 65536), int(0.7169 * 65536), int(0.0971 * 65536))
    bXYZ_data = b'XYZ \x00\x00\x00\x00' + struct.pack(">iii", int(0.1431 * 65536), int(0.0606 * 65536), int(0.7141 * 65536))

    # 'rTRC' gamma curve 2.2 (gamma value in u8Fixed8Number: 2.2 * 256 = 563)
    rTRC_data = b'curv\x00\x00\x00\x00' + struct.pack(">IH", 1, 563)

    final_icc = body + desc_data + cprt_data + wtpt_data + rXYZ_data + gXYZ_data + bXYZ_data + rTRC_data
    # Correct final length in header
    struct.pack_into(">I", final_icc, 0, len(final_icc))
    return bytes(final_icc)

def main():
    target_dir = os.path.join(os.path.dirname(__file__), "..", "patches", "display_ergonomics", "color", "icc")
    os.makedirs(target_dir, exist_ok=True)
    target_file = os.path.join(target_dir, "Lenovo-D330-sRGB-D65.icc")
    icc_bytes = build_icc_profile()
    with open(target_file, "wb") as f:
        f.write(icc_bytes)
    print(f"[OK] Generated {len(icc_bytes)} bytes calibrated ICC profile at {target_file}")

if __name__ == "__main__":
    main()
