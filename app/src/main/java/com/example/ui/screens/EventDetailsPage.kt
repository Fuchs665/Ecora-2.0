package com.example.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
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
import com.example.data.SupabaseEvent
import com.example.data.SupabaseParticipationRequest
import com.example.data.SupabaseClient
import com.example.ui.theme.MatteDark
import com.example.ui.theme.PremiumGold
import com.example.ui.theme.SlateSurface
import com.example.ui.theme.TextPrimary
import com.example.ui.theme.TextSecondary

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventDetailsPage(
    event: SupabaseEvent,
    requests: List<SupabaseParticipationRequest>,
    currentUserId: String,
    onBack: () -> Unit,
    onJoinRequestSubmitted: () -> Unit
) {
    // Determine the guest's approval status for this event
    val userRequest = requests.find { it.userId == currentUserId && it.eventId == event.id }
    val requestStatus = userRequest?.status ?: "none" // "pending", "approved", "rejected", "none"
    val isApproved = requestStatus == "approved"

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Dettagli Evento", style = TextStyle(fontWeight = FontWeight.Bold, letterSpacing = 0.5.sp)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.Default.ArrowBack,
                            contentDescription = "Indietro",
                            tint = PremiumGold
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MatteDark,
                    titleContentColor = TextPrimary
                )
            )
        },
        containerColor = MatteDark
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
        ) {
            // --- TOP HERO EVENT BANNER ---
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(240.dp)
            ) {
                AsyncImage(
                    model = event.imageUrl,
                    contentDescription = event.title,
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Crop
                )

                // High shadow gradient mask overlay
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            Brush.verticalGradient(
                                colors = listOf(Color.Transparent, MatteDark.copy(alpha = 0.9f), MatteDark)
                            )
                        )
                )

                // Table completion floating percentage bubble
                Box(
                    modifier = Modifier
                        .padding(16.dp)
                        .align(Alignment.TopEnd)
                        .background(PremiumGold, RoundedCornerShape(12.dp))
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                ) {
                    Text(
                        text = "${(event.tableCompletionPercentage * 100).toInt()}% RISERVATO",
                        style = TextStyle(
                            fontWeight = FontWeight.Bold,
                            fontSize = 10.sp,
                            color = MatteDark,
                            letterSpacing = 1.sp
                        )
                    )
                }
            }

            // --- MAIN DESCRIPTION SECTION ---
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                Text(
                    text = event.title.uppercase(),
                    style = TextStyle(
                        fontFamily = FontFamily.SansSerif,
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 24.sp,
                        letterSpacing = 1.sp,
                        color = TextPrimary
                    )
                )

                Spacer(modifier = Modifier.height(8.dp))

                // Date label
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.CalendarToday,
                        contentDescription = "Date",
                        tint = PremiumGold,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = event.eventDate.replace("T", " @ "),
                        style = TextStyle(fontSize = 14.sp, color = PremiumGold, fontWeight = FontWeight.Bold)
                    )
                }

                Spacer(modifier = Modifier.height(8.dp))

                // Capacity info
                Row(
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.People,
                        contentDescription = "Capacity",
                        tint = TextSecondary,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "Capacità Tavolo: max ${event.maxParticipants} coppie (${event.currentApprovedCount} confermate)",
                        style = TextStyle(fontSize = 13.sp, color = TextSecondary)
                    )
                }

                Spacer(modifier = Modifier.height(16.dp))

                Text(
                    text = "IL CONCEPT",
                    style = TextStyle(
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        letterSpacing = 1.5.sp,
                        color = PremiumGold
                    )
                )

                Spacer(modifier = Modifier.height(4.dp))

                Text(
                    text = event.description,
                    style = TextStyle(fontSize = 14.sp, color = TextSecondary, lineHeight = 21.sp)
                )

                Spacer(modifier = Modifier.height(24.dp))

                // --- CRITICAL PRIVACY BY DESIGN LOCATION COMPONENT ---
                Text(
                    text = "ACCESSO INDIRIZZO RISERVATO",
                    style = TextStyle(
                        fontWeight = FontWeight.Bold,
                        fontSize = 12.sp,
                        letterSpacing = 1.5.sp,
                        color = PremiumGold
                    )
                )

                Spacer(modifier = Modifier.height(8.dp))

                if (isApproved) {
                    // UNLOCKED: FULLY DISCLOSED GPS AND ADDRESS
                    Card(
                        colors = CardDefaults.cardColors(containerColor = SlateSurface),
                        border = BorderStroke(1.dp, PremiumGold.copy(alpha = 0.5f)),
                        shape = RoundedCornerShape(12.dp),
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .background(Color.Green, CircleShape)
                                )
                                Spacer(modifier = Modifier.width(10.dp))
                                Text(
                                    text = "INVITO APPROVATO",
                                    style = TextStyle(
                                        color = Color.Green,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 12.sp,
                                        letterSpacing = 1.sp
                                    )
                                )
                            }

                            Spacer(modifier = Modifier.height(12.dp))

                            Text(
                                text = "Indirizzo Sbloccato:",
                                style = TextStyle(fontSize = 12.sp, color = TextSecondary)
                            )
                            Text(
                                text = event.locationName,
                                style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                            )

                            Spacer(modifier = Modifier.height(12.dp))

                            // Display precise coordinates since approved
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .background(MatteDark, RoundedCornerShape(8.dp))
                                    .padding(12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text("Coordinate di Precisione", fontSize = 10.sp, color = TextSecondary)
                                    Text("Lat: ${event.latitude} / Lng: ${event.longitude}", fontSize = 12.sp, color = PremiumGold, fontWeight = FontWeight.SemiBold)
                                }
                                Icon(
                                    imageVector = Icons.Default.Directions,
                                    contentDescription = "Navigate",
                                    tint = PremiumGold
                                )
                            }
                        }
                    }
                } else {
                    // BLURRED / LOCKED: LOCATION DETAILS SEISMIC SHIELD
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(180.dp)
                            .clip(RoundedCornerShape(12.dp))
                            .border(BorderStroke(1.dp, Color(0xFF333333)), RoundedCornerShape(12.dp))
                    ) {
                        // Blurred map placeholder block to satisfy the "Visual Dark Map" theme
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .blur(24.dp)
                                .background(Color(0xFF0F0F0F))
                        ) {
                            // Artistic design behind to represent blurred city streets
                            Column(modifier = Modifier.padding(20.dp)) {
                                repeat(5) {
                                    Spacer(
                                        modifier = Modifier
                                            .fillMaxWidth(if (it % 2 == 0) 0.8f else 0.5f)
                                            .height(8.dp)
                                            .background(Color.DarkGray.copy(alpha = 0.5f))
                                    )
                                    Spacer(modifier = Modifier.height(12.dp))
                                }
                            }
                        }

                        // Fog layer
                        Box(
                            modifier = Modifier
                                .fillMaxSize()
                                .background(
                                    Brush.verticalGradient(
                                        colors = listOf(
                                            Color(0x991A1A1A),
                                            Color(0xDD1A1A1A)
                                        )
                                    )
                                )
                        )

                        // Lock Overlay Text Displays "Florence South Area - Location revealed after approval"
                        Column(
                             modifier = Modifier
                                .fillMaxSize()
                                .padding(16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.Center
                        ) {
                            Icon(
                                imageVector = Icons.Default.Lock,
                                contentDescription = "Location Shielded",
                                tint = PremiumGold,
                                modifier = Modifier.size(32.dp)
                            )
                            Spacer(modifier = Modifier.height(10.dp))
                            Text(
                                text = "Zona Firenze Sud",
                                style = TextStyle(
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 16.sp,
                                    color = TextPrimary
                                ),
                                textAlign = TextAlign.Center
                            )
                            Spacer(modifier = Modifier.height(4.dp))
                            Text(
                                text = "L'indirizzo esatto e le coordinate GPS sono sbloccati esclusivamente dopo l'approvazione dell'organizzatore.",
                                style = TextStyle(
                                    fontSize = 11.sp,
                                    color = TextSecondary,
                                    lineHeight = 16.sp
                                ),
                                textAlign = TextAlign.Center,
                                modifier = Modifier.padding(horizontal = 16.dp)
                            )
                            
                            if (requestStatus == "pending") {
                                Spacer(modifier = Modifier.height(8.dp))
                                Text(
                                    text = "RICHIESTA IN ATTESA DI APPROVAZIONE",
                                    style = TextStyle(
                                        color = PremiumGold,
                                        fontWeight = FontWeight.Bold,
                                        fontSize = 11.sp,
                                        letterSpacing = 1.sp
                                    )
                                )
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(32.dp))

                // --- FOOTER CTA INTERACTION CONTROL BUTTON ---
                when (requestStatus) {
                    "none" -> {
                        Button(
                            onClick = {
                                SupabaseClient.submitParticipationRequest(event.id, currentUserId)
                                onJoinRequestSubmitted()
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = PremiumGold),
                            shape = RoundedCornerShape(24.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Key,
                                contentDescription = "Request Access",
                                tint = MatteDark
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "RICHIEDI INVITO PRIVATO",
                                style = TextStyle(
                                    fontFamily = FontFamily.SansSerif,
                                    fontWeight = FontWeight.ExtraBold,
                                    fontSize = 12.sp,
                                    letterSpacing = 1.sp,
                                    color = MatteDark
                                )
                            )
                        }
                    }
                    "pending" -> {
                        Button(
                            onClick = {},
                            enabled = false,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = SlateSurface,
                                disabledContainerColor = SlateSurface
                            ),
                            shape = RoundedCornerShape(24.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                        ) {
                            Text(
                                text = "IN ATTESA DI APPROVAZIONE",
                                style = TextStyle(
                                    fontFamily = FontFamily.SansSerif,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    color = PremiumGold
                                )
                            )
                        }
                    }
                    "approved" -> {
                        Button(
                            onClick = {},
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32)),
                            shape = RoundedCornerShape(24.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                        ) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = "Confirmed",
                                tint = Color.White
                            )
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "PARTECIPAZIONE CONFERMATA",
                                style = TextStyle(
                                    fontFamily = FontFamily.SansSerif,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    color = Color.White
                                )
                            )
                        }
                    }
                    "rejected" -> {
                        Button(
                            onClick = {},
                            enabled = false,
                            colors = ButtonDefaults.buttonColors(
                                containerColor = Color(0x33C62828),
                                disabledContainerColor = Color(0x33C62828)
                            ),
                            shape = RoundedCornerShape(24.dp),
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(50.dp)
                        ) {
                            Text(
                                text = "RICHIESTA DECLINATA",
                                style = TextStyle(
                                    fontFamily = FontFamily.SansSerif,
                                    fontWeight = FontWeight.Bold,
                                    fontSize = 12.sp,
                                    color = Color(0xFFEF5350)
                                )
                            )
                        }
                    }
                }
                Spacer(modifier = Modifier.height(24.dp))
            }
        }
    }
}
