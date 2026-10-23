package dev.secondsun.superx.tools.packer.ui

import org.junit.jupiter.api.Assertions.*
import org.junit.jupiter.api.Test

class PlatformDpiTest {

    @Test
    fun testParseXrdbOutput() {
        val xrdbStandard = """
            Xcursor.size:	24
            Xft.antialias:	1
            Xft.dpi:	96
            Xft.hinting:	1
        """.trimIndent()
        assertEquals(1.0, PlatformDpi.parseXrdbOutput(xrdbStandard))

        val xrdbHiDpi = """
            Xcursor.size:	48
            Xft.antialias:	1
            Xft.dpi:	192
            Xft.hinting:	1
        """.trimIndent()
        assertEquals(2.0, PlatformDpi.parseXrdbOutput(xrdbHiDpi))

        val xrdbFractional = """
            Xft.dpi: 144
        """.trimIndent()
        assertEquals(1.5, PlatformDpi.parseXrdbOutput(xrdbFractional))

        val xrdbNone = "Xcursor.size: 24"
        assertNull(PlatformDpi.parseXrdbOutput(xrdbNone))
    }

    @Test
    fun testParseMonitorsXml() {
        val xml = """
            <monitors version="2">
              <configuration>
                <logicalmonitor>
                  <x>0</x>
                  <y>0</y>
                  <scale>1.6666666269302368</scale>
                </logicalmonitor>
              </configuration>
            </monitors>
        """.trimIndent()
        val parsed = PlatformDpi.parseMonitorsXml(xml)
        assertNotNull(parsed)
        assertEquals(1.6666666269302368, parsed!!, 0.0001)

        val xml2x = "<monitors><logicalmonitor><scale>2</scale></logicalmonitor></monitors>"
        assertEquals(2.0, PlatformDpi.parseMonitorsXml(xml2x)!!, 0.0001)

        val xmlEmpty = "<monitors></monitors>"
        assertNull(PlatformDpi.parseMonitorsXml(xmlEmpty))
    }

    @Test
    fun testParseGsettingsValues() {
        // Integer scale 2
        assertEquals(2.0, PlatformDpi.parseGsettingsValues("uint32 2", "1.0"))
        assertEquals(2.0, PlatformDpi.parseGsettingsValues("2", null))

        // Fractional text scaling factor
        assertEquals(1.25, PlatformDpi.parseGsettingsValues("uint32 0", "1.25")!!, 0.001)

        // Combined 2x * 1.25 = 2.5
        assertEquals(2.5, PlatformDpi.parseGsettingsValues("uint32 2", "1.25")!!, 0.001)

        // Standard 1x -> returns null (no scale-up needed)
        assertNull(PlatformDpi.parseGsettingsValues("uint32 1", "1.0"))
    }

    @Test
    fun testParseKdeGlobals() {
        val kdeContent = """
            [General]
            ColorScheme=BreezeDark
            
            [KScreen]
            ScaleFactor=1.75
            ScreenScaleFactors=DP-1=1.75;
        """.trimIndent()
        assertEquals(1.75, PlatformDpi.parseKdeGlobals(kdeContent))
        assertNull(PlatformDpi.parseKdeGlobals("[General]\nColorScheme=BreezeDark"))
    }

    @Test
    fun testDetectPlatformScaleNonNull() {
        val scale = PlatformDpi.detectPlatformScale()
        assertTrue(scale >= 1.0, "Scale should be at least 1.0")
        assertNotNull(PlatformDpi.detectedSource)
    }
}

