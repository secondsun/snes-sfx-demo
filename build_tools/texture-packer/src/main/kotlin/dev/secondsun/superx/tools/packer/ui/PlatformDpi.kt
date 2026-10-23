package dev.secondsun.superx.tools.packer.ui

import java.io.File
import java.util.regex.Pattern

object PlatformDpi {

    var detectedPlatformScale: Double = 1.0
        private set

    var detectedSource: String = "Default (1.0x)"
        private set

    /**
     * Initializes platform DPI scaling before AWT / Compose Desktop initializes.
     * Must be called at the very beginning of main().
     */
    fun init() {
        detectedPlatformScale = detectPlatformScale()

        // If user already specified sun.java2d.uiScale via CLI/JVM args, respect it
        val existingProp = System.getProperty("sun.java2d.uiScale")
        if (existingProp != null && existingProp.isNotBlank()) {
            val parsed = existingProp.toDoubleOrNull()
            if (parsed != null && parsed > 0.0) {
                detectedPlatformScale = parsed
                detectedSource = "JVM property sun.java2d.uiScale=$existingProp"
                return
            }
        }

        // Apply integer base scale to sun.java2d.uiScale for X11 / AWT on Linux
        if (detectedPlatformScale >= 1.5) {
            val intScale = Math.round(detectedPlatformScale).toInt()
            if (intScale > 1) {
                System.setProperty("sun.java2d.uiScale", intScale.toString())
            }
        }
    }

    /**
     * Detects DPI scaling factor from environment, X11, desktop configuration, or hardware.
     */
    fun detectPlatformScale(): Double {
        // 1. Check JVM system property
        System.getProperty("sun.java2d.uiScale")?.toDoubleOrNull()?.let {
            if (it > 0.0) {
                detectedSource = "sun.java2d.uiScale ($it)"
                return it
            }
        }

        // 2. Check GDK_SCALE (GTK/GNOME)
        System.getenv("GDK_SCALE")?.toDoubleOrNull()?.let {
            if (it > 0.0) {
                detectedSource = "GDK_SCALE env ($it)"
                return it
            }
        }

        // 3. Check QT_SCALE_FACTOR (Qt/KDE)
        System.getenv("QT_SCALE_FACTOR")?.toDoubleOrNull()?.let {
            if (it > 0.0) {
                detectedSource = "QT_SCALE_FACTOR env ($it)"
                return it
            }
        }

        // 4. Check X11 xrdb -q for Xft.dpi
        detectFromXrdb()?.let {
            detectedSource = "xrdb Xft.dpi ($it)"
            return it
        }

        // 5. Check GNOME / Wayland monitors.xml
        detectFromMonitorsXml()?.let {
            detectedSource = "GNOME monitors.xml ($it)"
            return it
        }

        // 6. Check gsettings (GNOME/Cinnamon/MATE)
        detectFromGsettings()?.let {
            detectedSource = "gsettings ($it)"
            return it
        }

        // 7. Check KDE kdeglobals
        detectFromKdeGlobals()?.let {
            detectedSource = "KDE kdeglobals ($it)"
            return it
        }

        // 8. Fallback: AWT desktop properties (if Toolkit is already loaded)
        try {
            val tk = java.awt.Toolkit.getDefaultToolkit()
            val xftDpi = tk.getDesktopProperty("gnome.Xft/DPI")
            if (xftDpi is Number) {
                val dpi = xftDpi.toDouble() / 1024.0
                if (dpi > 0) {
                    val scale = dpi / 96.0
                    if (scale > 1.01) {
                        detectedSource = "AWT gnome.Xft/DPI ($dpi)"
                        return scale
                    }
                }
            }
            val res = tk.screenResolution
            if (res > 96) {
                val scale = res.toDouble() / 96.0
                detectedSource = "AWT screen resolution ($res)"
                return scale
            }
        } catch (_: Throwable) {}

        detectedSource = "Default (1.0x)"
        return 1.0
    }

    fun parseXrdbOutput(text: String): Double? {
        val pattern = Pattern.compile("(?i)^xft\\.dpi:\\s*([0-9.]+)", Pattern.MULTILINE)
        val matcher = pattern.matcher(text)
        if (matcher.find()) {
            val dpi = matcher.group(1).toDoubleOrNull()
            if (dpi != null && dpi > 0) {
                return dpi / 96.0
            }
        }
        return null
    }

    fun parseMonitorsXml(content: String): Double? {
        val pattern = Pattern.compile("<scale>([0-9.]+)</scale>")
        val matcher = pattern.matcher(content)
        if (matcher.find()) {
            val scale = matcher.group(1).toDoubleOrNull()
            if (scale != null && scale > 0.0) {
                return scale
            }
        }
        return null
    }

    fun parseGsettingsValues(scalingFactorStr: String?, textScalingFactorStr: String?): Double? {
        var scale = 1.0
        var found = false

        if (scalingFactorStr != null) {
            val factor = scalingFactorStr.replace("uint32", "").trim().toDoubleOrNull()
            if (factor != null && factor > 0) {
                scale = factor
                found = true
            }
        }

        if (textScalingFactorStr != null) {
            val textFactor = textScalingFactorStr.toDoubleOrNull()
            if (textFactor != null && textFactor > 0) {
                scale *= textFactor
                found = true
            }
        }

        return if (found && scale > 1.01) scale else null
    }

    fun parseKdeGlobals(content: String): Double? {
        val pattern = Pattern.compile("(?i)^ScaleFactor=([0-9.]+)", Pattern.MULTILINE)
        val matcher = pattern.matcher(content)
        if (matcher.find()) {
            val s = matcher.group(1).toDoubleOrNull()
            if (s != null && s > 0.0) return s
        }
        return null
    }

    private fun detectFromXrdb(): Double? {
        return try {
            val process = ProcessBuilder("xrdb", "-q").start()
            val text = process.inputStream.bufferedReader().readText()
            parseXrdbOutput(text)
        } catch (_: Exception) {
            null
        }
    }

    private fun detectFromMonitorsXml(): Double? {
        return try {
            val file = File(System.getProperty("user.home"), ".config/monitors.xml")
            if (file.exists()) {
                parseMonitorsXml(file.readText())
            } else null
        } catch (_: Exception) {
            null
        }
    }

    private fun detectFromGsettings(): Double? {
        return try {
            val factorStr = try {
                val p = ProcessBuilder("gsettings", "get", "org.gnome.desktop.interface", "scaling-factor").start()
                p.inputStream.bufferedReader().readText().trim()
            } catch (_: Exception) { null }

            val textFactorStr = try {
                val p = ProcessBuilder("gsettings", "get", "org.gnome.desktop.interface", "text-scaling-factor").start()
                p.inputStream.bufferedReader().readText().trim()
            } catch (_: Exception) { null }

            parseGsettingsValues(factorStr, textFactorStr)
        } catch (_: Exception) {
            null
        }
    }

    private fun detectFromKdeGlobals(): Double? {
        return try {
            val file = File(System.getProperty("user.home"), ".config/kdeglobals")
            if (file.exists()) {
                parseKdeGlobals(file.readText())
            } else null
        } catch (_: Exception) {
            null
        }
    }
}

