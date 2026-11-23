// Design tokens, generated from design-tokens.json by tools/design_tokens.mjs. Do not edit by hand:
// change design-tokens.json at the repository root and run `node tools/design_tokens.mjs`.
package com.example.appname.ui.theme

import androidx.compose.ui.graphics.Color

// --- BRAND tokens (UI chrome only, never content meaning) ---
val BrandPrimaryLight = Color(0xFF4A1520)
val BrandPrimaryDark = Color(0xFFF0B9BE)
val BrandOnPrimaryLight = Color(0xFFFBFAF7)
val BrandOnPrimaryDark = Color(0xFF4A1520)
val BrandBackgroundLight = Color(0xFFFBFAF7)
val BrandBackgroundDark = Color(0xFF171615)
val BrandSurfaceLight = Color(0xFFFFFFFF)
val BrandSurfaceDark = Color(0xFF201E1D)
val BrandSurfaceAltLight = Color(0xFFF1EEEA)
val BrandSurfaceAltDark = Color(0xFF2A2826)
val BrandTextLight = Color(0xFF231B1C)
val BrandTextDark = Color(0xFFEFE9E7)
val BrandTextMutedLight = Color(0xFF5E5455)
val BrandTextMutedDark = Color(0xFFB8AEAC)
val BrandBorderLight = Color(0xFFD9D2CF)
val BrandBorderDark = Color(0xFF3A3634)

// --- SEMANTIC tokens (content only, never chrome) ---
// Read them through AppSemantics (Theme.kt), never through colorScheme, so
// Material You dynamic color can never change what they mean.
data class SemanticColors(
    val success: Color,
    val warning: Color,
    val error: Color,
    val errorSurface: Color,
    val storeClay: Color,
    val storeOchre: Color,
    val storeSage: Color,
    val storeSlate: Color,
    val storeRose: Color,
    val storeStone: Color,
    val themeClay: Color,
    val themePersimmon: Color,
    val themeOchre: Color,
    val themeOlive: Color,
    val themeMoss: Color,
    val themeSage: Color,
    val themeTeal: Color,
    val themeSky: Color,
    val themeSlate: Color,
    val themeIris: Color,
    val themePlum: Color,
    val themeRose: Color,
    val themeStone: Color,
)

val LightSemanticColors = SemanticColors(
    success = Color(0xFF1E7A4F),
    warning = Color(0xFF8A5A00),
    error = Color(0xFFB42318),
    errorSurface = Color(0xFFFDECEA),
    storeClay = Color(0xFFB5523B),
    storeOchre = Color(0xFFA8761A),
    storeSage = Color(0xFF2F7A6B),
    storeSlate = Color(0xFF3D5A9E),
    storeRose = Color(0xFFA8437A),
    storeStone = Color(0xFF6F6964),
    themeClay = Color(0xFFA33E25),
    themePersimmon = Color(0xFF964D09),
    themeOchre = Color(0xFF815C0A),
    themeOlive = Color(0xFF686800),
    themeMoss = Color(0xFF2F751D),
    themeSage = Color(0xFF1B735B),
    themeTeal = Color(0xFF157171),
    themeSky = Color(0xFF006D91),
    themeSlate = Color(0xFF2F60B2),
    themeIris = Color(0xFF6451AC),
    themePlum = Color(0xFF8A428E),
    themeRose = Color(0xFF9D3A67),
    themeStone = Color(0xFF6F6964),
)

val DarkSemanticColors = SemanticColors(
    success = Color(0xFF5CC593),
    warning = Color(0xFFE8B04B),
    error = Color(0xFFFF8A80),
    errorSurface = Color(0xFF3A1D1B),
    storeClay = Color(0xFFE58A72),
    storeOchre = Color(0xFFE2B550),
    storeSage = Color(0xFF6CC2AE),
    storeSlate = Color(0xFF8EA8E6),
    storeRose = Color(0xFFE48BBB),
    storeStone = Color(0xFFB3ACA6),
    themeClay = Color(0xFFFCA48D),
    themePersimmon = Color(0xFFFEA668),
    themeOchre = Color(0xFFE9B452),
    themeOlive = Color(0xFFC3C55A),
    themeMoss = Color(0xFF90D281),
    themeSage = Color(0xFF54D8B1),
    themeTeal = Color(0xFF2AD7D7),
    themeSky = Color(0xFF60CCFC),
    themeSlate = Color(0xFF98BFFE),
    themeIris = Color(0xFFBCB3FA),
    themePlum = Color(0xFFE8A0EC),
    themeRose = Color(0xFFFF99C2),
    themeStone = Color(0xFFB3ACA6),
)

object Spacing {
    const val S1 = 4 // dp
    const val S2 = 8 // dp
    const val S3 = 12 // dp
    const val S4 = 16 // dp
    const val S6 = 24 // dp
    const val S8 = 32 // dp
}

object Radius {
    const val Control = 8 // dp
    const val Card = 12 // dp
}
