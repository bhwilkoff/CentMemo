// Design tokens, generated from design-tokens.json by tools/design_tokens.mjs. Do not edit by hand:
// change design-tokens.json at the repository root and run `node tools/design_tokens.mjs`.
package com.example.appname.ui.theme

import androidx.compose.ui.graphics.Color

// --- BRAND tokens (UI chrome only, never content meaning) ---
val BrandPrimaryLight = Color(0xFF4A1520)
val BrandPrimaryDark = Color(0xFFF5D6D8)
val BrandOnPrimaryLight = Color(0xFFFBFAF7)
val BrandOnPrimaryDark = Color(0xFF4A1520)
val BrandBackgroundLight = Color(0xFF2FD4EC)
val BrandBackgroundDark = Color(0xFF131B1C)
val BrandSurfaceLight = Color(0xFFFBFAF7)
val BrandSurfaceDark = Color(0xFF1C2426)
val BrandSurfaceAltLight = Color(0xFFEFEDE8)
val BrandSurfaceAltDark = Color(0xFF273031)
val BrandTextLight = Color(0xFF4A1520)
val BrandTextDark = Color(0xFFF5D6D8)
val BrandTextMutedLight = Color(0xFF6E2B36)
val BrandTextMutedDark = Color(0xFFD8B0B4)
val BrandBorderLight = Color(0xFF8E5C63)
val BrandBorderDark = Color(0xFF4A5658)

// --- SEMANTIC tokens (content only, never chrome) ---
// Read them through AppSemantics (Theme.kt), never through colorScheme, so
// Material You dynamic color can never change what they mean.
data class SemanticColors(
    val success: Color,
    val warning: Color,
    val error: Color,
    val errorSurface: Color,
)

val LightSemanticColors = SemanticColors(
    success = Color(0xFF0D5230),
    warning = Color(0xFF5A3A00),
    error = Color(0xFF8E1414),
    errorSurface = Color(0xFFFDECEA),
)

val DarkSemanticColors = SemanticColors(
    success = Color(0xFF8FE3B4),
    warning = Color(0xFFF3C26B),
    error = Color(0xFFFFB4AB),
    errorSurface = Color(0xFF3A1D1B),
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
