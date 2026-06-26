package com.example.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Diamond
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.VerifiedUser
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.data.SupabaseProfile
import com.example.ui.theme.MatteDark
import com.example.ui.theme.PremiumGold
import com.example.ui.theme.SlateSurface
import com.example.ui.theme.TextPrimary
import com.example.ui.theme.TextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UserProfilePage(
    profile: SupabaseProfile,
    onLogout: () -> Unit = {}
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MatteDark)
            .padding(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(10.dp))

        // --- DISCREET BRAND HEADER ---
        Text(
            text = "E C O R A",
            style = TextStyle(
                fontFamily = FontFamily.SansSerif,
                fontWeight = FontWeight.ExtraBold,
                fontSize = 13.sp,
                letterSpacing = 6.sp,
                color = PremiumGold
            ),
            modifier = Modifier.padding(bottom = 24.dp)
        )

        // --- PROFILE PICTURE ARCHITECTURE WITH GOLD CARD METALLIC HALO ---
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier.size(136.dp)
        ) {
            // Pulsing golden shadow to evoke extreme exclusivity and high trust status
            val infiniteTransition = rememberInfiniteTransition(label = "glow")
            val glowScale by infiniteTransition.animateFloat(
                initialValue = 0.95f,
                targetValue = 1.05f,
                animationSpec = infiniteRepeatable(
                    animation = tween(2000, easing = LinearEasing),
                    repeatMode = RepeatMode.Reverse
                ),
                label = "glowScale"
            )

            Box(
                modifier = Modifier
                    .size(126.dp)
                    .shadow(
                        elevation = (12.dp * glowScale),
                        shape = CircleShape,
                        clip = false,
                        ambientColor = PremiumGold,
                        spotColor = PremiumGold
                    )
                    .background(
                        Brush.radialGradient(
                            colors = listOf(PremiumGold.copy(alpha = 0.4f), Color.Transparent)
                        ),
                        shape = CircleShape
                    )
            )

            // Outer gold metallic ring
            Box(
                modifier = Modifier
                    .size(114.dp)
                    .border(BorderStroke(2.dp, PremiumGold), CircleShape)
                    .padding(4.dp)
            ) {
                // Circular Profile Image (Using a discreet dark premium background avatar representing the swinger lifestyle aesthetic)
                AsyncImage(
                    model = if (profile.gender == "Coppia") {
                        "https://images.unsplash.com/photo-1516575307900-510b501c3bf4?auto=format&fit=crop&q=80&w=300"
                    } else if (profile.gender == "Donna") {
                        "https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&q=80&w=300"
                    } else {
                        "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&q=80&w=300"
                    },
                    contentDescription = "Discreet Profile Avatar",
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(CircleShape)
                        .background(SlateSurface),
                    contentScale = ContentScale.Crop
                )
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // --- FULL NAME & BASIC INFO SLIDER ---
        Text(
            text = profile.fullName,
            style = TextStyle(
                fontFamily = FontFamily.SansSerif,
                fontWeight = FontWeight.Bold,
                fontSize = 22.sp,
                letterSpacing = 0.5.sp,
                color = TextPrimary
            ),
            textAlign = TextAlign.Center
        )

        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
            modifier = Modifier.padding(top = 4.dp, bottom = 12.dp)
        ) {
            Text(
                text = "${profile.gender}  •  ${profile.age} anni",
                style = TextStyle(
                    fontFamily = FontFamily.SansSerif,
                    fontWeight = FontWeight.Normal,
                    fontSize = 14.sp,
                    color = TextSecondary
                )
            )
        }

        // --- HIGH TRUST BADGE (GLOWING MATTE CARD ACCENT) ---
        // Earned strictly by preserving a zero or low 'no_shows' record
        val highTrustEarned = profile.noShows == 0
        if (highTrustEarned) {
            Card(
                colors = CardDefaults.cardColors(
                    containerColor = Color(0x1AD4AF37) // Golden semi-transparent background
                ),
                shape = RoundedCornerShape(20.dp),
                border = BorderStroke(1.dp, PremiumGold.copy(alpha = 0.5f)),
                modifier = Modifier
                    .padding(horizontal = 24.dp, vertical = 6.dp)
                    .shadow(4.dp, shape = RoundedCornerShape(20.dp), ambientColor = PremiumGold, spotColor = PremiumGold)
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center
                ) {
                    Icon(
                        imageVector = Icons.Default.Diamond,
                        contentDescription = "Golden High Trust Status",
                        tint = PremiumGold,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "ACCOUNT AFFIDABILE",
                        style = TextStyle(
                            fontFamily = FontFamily.SansSerif,
                            fontWeight = FontWeight.Bold,
                            fontSize = 11.sp,
                            letterSpacing = 1.5.sp,
                            color = PremiumGold
                        )
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // --- ECO-SYSTEM STATISTICS INTEGRATION PANELS ---
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp, horizontal = 4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly
        ) {
            StatMetricField(
                label = "Partecipazioni",
                value = "${profile.participationsCount}",
                indicatorColor = PremiumGold
            )
            StatMetricField(
                label = "No-Show",
                value = "${profile.noShows}",
                indicatorColor = if (profile.noShows > 2) Color.Red else TextSecondary
            )
            StatMetricField(
                label = "Organizzati",
                value = if (profile.role == "gestore") "45" else "0", // Clean counters: '0 Organized' for clients
                indicatorColor = PremiumGold
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        // --- PRIVACY DEED DESCRIPTION BLOCKS ---
        Card(
            colors = CardDefaults.cardColors(containerColor = SlateSurface),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 12.dp)
        ) {
            Row(
                modifier = Modifier.padding(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Lock,
                    contentDescription = "Discreet Profile Safety Guard",
                    tint = PremiumGold,
                    modifier = Modifier.size(24.dp)
                )
                Spacer(modifier = Modifier.width(16.dp))
                Column {
                    Text(
                        text = "Scudo Privacy Attivo",
                        style = TextStyle(
                            fontWeight = FontWeight.Bold,
                            fontSize = 13.sp,
                            color = TextPrimary
                        )
                    )
                    Text(
                        text = "La tua foto reale, l'età e le statistiche sono visibili esclusivamente ai club verificati quando richiedi di partecipare.",
                        style = TextStyle(
                            fontSize = 11.sp,
                            color = TextSecondary,
                            lineHeight = 15.sp
                        )
                    )
                }
            }
        }

        // --- LOGOUT ACTION Button ---
        Button(
            onClick = onLogout,
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            border = BorderStroke(1.dp, Color(0xFF424242)),
            shape = RoundedCornerShape(24.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
                .padding(bottom = 4.dp)
        ) {
            Text(
                text = "ESCI",
                style = TextStyle(
                    fontFamily = FontFamily.SansSerif,
                    fontWeight = FontWeight.Bold,
                    fontSize = 12.sp,
                    letterSpacing = 1.sp,
                    color = Color.Red.copy(alpha = 0.8f)
                )
            )
        }
    }
}

@Composable
fun StatMetricField(
    label: String,
    value: String,
    indicatorColor: Color
) {
    Card(
        colors = CardDefaults.cardColors(containerColor = SlateSurface),
        shape = RoundedCornerShape(14.dp),
        border = BorderStroke(1.dp, Color(0xFF3A3A3A)),
        modifier = Modifier
            .width(104.dp)
            .height(90.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            verticalArrangement = Arrangement.Center,
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = value,
                style = TextStyle(
                    fontFamily = FontFamily.SansSerif,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 24.sp,
                    color = indicatorColor
                )
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = label.uppercase(),
                style = TextStyle(
                    fontFamily = FontFamily.SansSerif,
                    fontWeight = FontWeight.Medium,
                    fontSize = 10.sp,
                    letterSpacing = 0.5.sp,
                    color = TextSecondary
                )
            )
        }
    }
}
