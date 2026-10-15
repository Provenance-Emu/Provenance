xdelta3 fixtures. The patches turn FixtureData.xdeltaSource() into FixtureData.xdeltaTarget()
(Tests/PVPatchEngineTests/FixtureData.swift); the tests regenerate both images.

Encoded with the xdelta3 CLI built from the vendored sources (Sources/CXdelta3, plus xdelta3-main.h
and friends from the same upstream commit) with -DXD3_MAIN=1 -DSECONDARY_DJW=1 -DSECONDARY_FGK=1:

  basic.xdelta        xdelta3 -e -s source.bin target.bin          (adler32 per window, no secondary)
  djw.xdelta          xdelta3 -e -S djw ...                        (static Huffman secondary)
  fgk.xdelta          xdelta3 -e -S fgk ...                        (adaptive Huffman secondary)
  nochecksum.xdelta   xdelta3 -e -n -S none ...                    (no adler32)
  multiwindow.xdelta  xdelta3 -e -W 65536 ...                      (six windows)
