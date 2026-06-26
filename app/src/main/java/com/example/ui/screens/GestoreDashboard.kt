package com.example.ui.screens

import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import com.example.data.SupabaseEvent
import com.example.data.SupabaseParticipationRequest
import com.example.data.SupabaseProfile
import com.example.data.SupabaseClient
import com.example.ui.theme.MatteDark
import com.example.ui.theme.PremiumGold
import com.example.ui.theme.SlateSurface
import com.example.ui.theme.TextPrimary
import com.example.ui.theme.TextSecondary

@OptIn(ExperimentalAnimationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun GestoreDashboard(
    onSelectEvent: (SupabaseEvent) -> Unit,
    onLogout: () -> Unit
) {
    var selectedTab by remember { mutableStateOf(0) } // 0 = Owner Feed, 1 = Guest Inspector, 2 = Creator (FAB alternative), 3 = Messages, 4 = Club Profile
    var showCreateForm by remember { mutableStateOf(false) }

    val currentProfile by SupabaseClient.currentProfile.collectAsState()
    val events by SupabaseClient.events.collectAsState()
    val requests by SupabaseClient.requests.collectAsState()

    val profile = currentProfile ?: return

    Scaffold(
        bottomBar = {
            NavigationBar(
                containerColor = SlateSurface,
                tonalElevation = 8.dp,
                modifier = Modifier.navigationBarsPadding()
            ) {
                // Tab 1: Lands on Owner Dashboard
                NavigationBarItem(
                    selected = selectedTab == 0 && !showCreateForm,
                    onClick = {
                        selectedTab = 0
                        showCreateForm = false
                    },
                    icon = { Icon(Icons.Filled.Dashboard, contentDescription = "Console") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = PremiumGold,
                        unselectedIconColor = TextSecondary,
                        indicatorColor = Color.Transparent
                    ),
                    alwaysShowLabel = false
                )

                // Tab 2: Requests Inspector
                val pendingCount = requests.count { it.status == "pending" }
                NavigationBarItem(
                    selected = selectedTab == 1 && !showCreateForm,
                    onClick = {
                        selectedTab = 1
                        showCreateForm = false
                    },
                    icon = {
                        BadgedBox(
                            badge = {
                                if (pendingCount > 0) {
                                    Badge(containerColor = Color.Red, contentColor = Color.White) {
                                        Text("$pendingCount")
                                    }
                                }
                            }
                        ) {
                            Icon(Icons.Filled.VerifiedUser, contentDescription = "Richieste")
                        }
                    },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = PremiumGold,
                        unselectedIconColor = TextSecondary,
                        indicatorColor = Color.Transparent
                    ),
                    alwaysShowLabel = false
                )

                // Tab 3: Decorative Placeholder for Floating PLUS Button
                NavigationBarItem(
                    selected = false,
                    onClick = { showCreateForm = true },
                    icon = {
                        Box(
                            modifier = Modifier
                                .size(24.dp)
                                .background(Color.Transparent)
                        )
                    },
                    enabled = true,
                    alwaysShowLabel = false
                )

                // Tab 4: Messages
                NavigationBarItem(
                    selected = selectedTab == 3 && !showCreateForm,
                    onClick = {
                        selectedTab = 3
                        showCreateForm = false
                    },
                    icon = { Icon(Icons.Filled.Forum, contentDescription = "Messaggi") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = PremiumGold,
                        unselectedIconColor = TextSecondary,
                        indicatorColor = Color.Transparent
                    ),
                    alwaysShowLabel = false
                )

                // Tab 5: Profile
                NavigationBarItem(
                    selected = selectedTab == 4 && !showCreateForm,
                    onClick = {
                        selectedTab = 4
                        showCreateForm = false
                    },
                    icon = { Icon(Icons.Filled.Security, contentDescription = "Profilo Club") },
                    colors = NavigationBarItemDefaults.colors(
                        selectedIconColor = PremiumGold,
                        unselectedIconColor = TextSecondary,
                        indicatorColor = Color.Transparent
                    ),
                    alwaysShowLabel = false
                )
            }
        },
        floatingActionButton = {
            // Central Gold FloatingActionButton (+): Opens the 'Create Event' form (simulating image_picker upload to event_images)
            ExtendedFloatingActionButton(
                onClick = { showCreateForm = true },
                containerColor = PremiumGold,
                contentColor = MatteDark,
                shape = CircleShape,
                modifier = Modifier
                    .offset(y = 54.dp) // Aligns FAB visually with bottom nav bar center
                    .size(56.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.Add,
                    contentDescription = "Crea Evento",
                    tint = MatteDark,
                    modifier = Modifier.size(28.dp)
                )
            }
        },
        floatingActionButtonPosition = FabPosition.Center,
        containerColor = MatteDark
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            AnimatedContent(
                targetState = showCreateForm,
                transitionSpec = {
                    slideInVertically(initialOffsetY = { it }) + fadeIn() with slideOutVertically(targetOffsetY = { it }) + fadeOut()
                },
                label = "gestore_content"
            ) { creating ->
                if (creating) {
                    CreateEventForm(
                        organizerId = profile.id,
                        onDismiss = { showCreateForm = false }
                    )
                } else {
                    when (selectedTab) {
                        0 -> ClubDashboardScreen(
                            events = events,
                            requests = requests,
                            onSelectEvent = onSelectEvent,
                            onSelectRequestInspector = { selectedTab = 1 }
                        )
                        1 -> RequestInspectorScreen(
                            events = events,
                            requests = requests
                        )
                        3 -> ClubMessagesScreen()
                        4 -> UserProfilePage(
                            profile = profile,
                            onLogout = onLogout
                        )
                    }
                }
            }
        }
    }
}

// --- SUB-SCREEN 1: OWNER FEED SCREEN ---

@Composable
fun ClubDashboardScreen(
    events: List<SupabaseEvent>,
    requests: List<SupabaseParticipationRequest>,
    onSelectEvent: (SupabaseEvent) -> Unit,
    onSelectRequestInspector: () -> Unit
) {
    val pendingCount = requests.count { it.status == "pending" }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        item {
            // Club Info Welcome banner
            Column {
                Text(
                    text = "CONSOLE CLUB",
                    style = TextStyle(
                        fontFamily = FontFamily.SansSerif,
                        fontWeight = FontWeight.ExtraBold,
                        fontSize = 18.sp,
                        letterSpacing = 2.sp,
                        color = PremiumGold
                    )
                )
                Text(
                    text = "Pannello Organizzatore • Eventi Attivi",
                    style = TextStyle(fontSize = 12.sp, color = TextSecondary)
                )
            }
        }

        if (pendingCount > 0) {
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = Color(0x2AA83232)),
                    border = BorderStroke(1.dp, Color.Red.copy(alpha = 0.5f)),
                    shape = RoundedCornerShape(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSelectRequestInspector() }
                ) {
                    Row(
                        modifier = Modifier.padding(16.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.Default.NewReleases,
                            contentDescription = "Alert",
                            tint = Color.Red,
                            modifier = Modifier.size(28.dp)
                        )
                        Spacer(modifier = Modifier.width(16.dp))
                        Column(modifier = Modifier.weight(1f)) {
                            Text("RICHIESTE IN ATTESA DI APPROVAZIONE", fontWeight = FontWeight.Bold, color = TextPrimary, fontSize = 14.sp)
                            Text("$pendingCount coppie sono in attesa della verifica affidabilità.", color = TextSecondary, fontSize = 12.sp)
                        }
                        Icon(
                            imageVector = Icons.Default.ChevronRight,
                            contentDescription = "Clear",
                            tint = Color.Red
                        )
                    }
                }
            }
        }

        item {
            Text(
                text = "I TUOI EVENTI ATTIVI",
                style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 12.sp, color = PremiumGold, letterSpacing = 1.sp)
            )
        }

        items(events) { event ->
            val eventRequestsCount = requests.count { it.eventId == event.id && it.status == "pending" }

            Card(
                colors = CardDefaults.cardColors(containerColor = SlateSurface),
                shape = RoundedCornerShape(12.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onSelectEvent(event) }
            ) {
                Row(
                    modifier = Modifier.padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    AsyncImage(
                        model = event.imageUrl,
                        contentDescription = "Event cover",
                        modifier = Modifier
                            .size(72.dp)
                            .clip(RoundedCornerShape(8.dp)),
                        contentScale = ContentScale.Crop
                    )

                    Spacer(modifier = Modifier.width(16.dp))

                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = event.title,
                            fontWeight = FontWeight.Bold,
                            fontSize = 15.sp,
                            color = TextPrimary
                        )
                        Text(
                            text = "${event.currentApprovedCount} / ${event.maxParticipants} coppie confermate",
                            fontSize = 12.sp,
                            color = PremiumGold
                        )
                        if (eventRequestsCount > 0) {
                            Text(
                                text = "$eventRequestsCount richieste in attesa",
                                fontSize = 12.sp,
                                color = Color.Red,
                                fontWeight = FontWeight.Bold
                            )
                        }
                    }

                    Icon(
                        imageVector = Icons.Default.ChevronRight,
                        contentDescription = "Details",
                        tint = PremiumGold
                    )
                }
            }
        }
    }
}

// --- SUB-SCREEN 2: GUEST REQUEST INSPECTOR ---

@Composable
fun RequestInspectorScreen(
    events: List<SupabaseEvent>,
    requests: List<SupabaseParticipationRequest>
) {
    val pendingRequests = requests.filter { it.status == "pending" }
    var selectedRequestToReview by remember { mutableStateOf<SupabaseParticipationRequest?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp)
    ) {
        Text(
            text = "RICHIESTE RICEVUTE",
            style = TextStyle(
                fontFamily = FontFamily.SansSerif,
                fontWeight = FontWeight.ExtraBold,
                fontSize = 18.sp,
                letterSpacing = 1.5.sp,
                color = PremiumGold
            )
        )
        Text(
            text = "Pannello di Controllo e Verifica Affidabilità",
            style = TextStyle(fontSize = 12.sp, color = TextSecondary),
            modifier = Modifier.padding(bottom = 16.dp)
        )

        if (pendingRequests.isEmpty()) {
            Box(
                modifier = Modifier.weight(1f).fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = Icons.Default.CheckCircleOutline,
                        contentDescription = "Cleared",
                        tint = PremiumGold,
                        modifier = Modifier.size(54.dp)
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = "Tutte le richieste sono state elaborate. Allineamento perfetto ad alta affidabilità.",
                        style = TextStyle(fontSize = 13.sp, color = TextSecondary),
                        textAlign = TextAlign.Center
                    )
                }
            }
        } else {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(10.dp),
                modifier = Modifier.weight(1f)
            ) {
                items(pendingRequests) { req ->
                    val applicant = SupabaseClient.getProfileById(req.userId) ?: return@items
                    val eventObj = events.find { it.id == req.eventId } ?: return@items

                    Card(
                        colors = CardDefaults.cardColors(containerColor = SlateSurface),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selectedRequestToReview = req }
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    text = applicant.fullName,
                                    fontWeight = FontWeight.Bold,
                                    color = TextPrimary,
                                    fontSize = 14.sp
                                )
                                Text(
                                    text = "Richiesta per: ${eventObj.title}",
                                    fontSize = 12.sp,
                                    color = PremiumGold
                                )
                                Text(
                                    text = "Genere: ${applicant.gender}  •  Età: ${applicant.age} anni",
                                    fontSize = 11.sp,
                                    color = TextSecondary
                                )
                            }
                            Button(
                                onClick = { selectedRequestToReview = req },
                                colors = ButtonDefaults.buttonColors(containerColor = PremiumGold),
                                modifier = Modifier.height(32.dp),
                                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 0.dp)
                            ) {
                                Text("VERIFICA", color = MatteDark, fontWeight = FontWeight.Bold, fontSize = 11.sp)
                            }
                        }
                    }
                }
            }
        }

        // --- THE TRUST & SAFETY PROFILE CARD EXPANDED MODAL OVERLAY ---
        selectedRequestToReview?.let { activeRequest ->
            val applicant = SupabaseClient.getProfileById(activeRequest.userId) ?: return@Column
            val invitedEvent = events.find { it.id == activeRequest.eventId } ?: return@Column

            AlertDialog(
                onDismissRequest = { selectedRequestToReview = null },
                containerColor = SlateSurface,
                title = {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(imageVector = Icons.Default.Shield, contentDescription = "Trust & Safety Shield", tint = PremiumGold)
                        Spacer(modifier = Modifier.width(10.dp))
                        Text(
                            text = "VERIFICA AFFIDABILITÀ",
                            style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 14.sp, letterSpacing = 1.sp, color = TextPrimary)
                        )
                    }
                },
                text = {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        // Candidate Name Card
                        Text(
                            text = applicant.fullName,
                            style = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.ExtraBold, color = TextPrimary)
                        )
                        Text(
                            text = "Candidatura per: ${invitedEvent.title}",
                            fontSize = 12.sp,
                            color = PremiumGold,
                            modifier = Modifier.padding(bottom = 16.dp)
                        )

                        // CANDIDATE PROFILE STATS BLOCK
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .background(MatteDark, RoundedCornerShape(10.dp))
                                .padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("GENERE", fontSize = 9.sp, color = TextSecondary)
                                Text(applicant.gender, fontWeight = FontWeight.Bold, color = TextPrimary, fontSize = 13.sp)
                            }
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("ETÀ", fontSize = 9.sp, color = TextSecondary)
                                Text("${applicant.age} anni", fontWeight = FontWeight.Bold, color = TextPrimary, fontSize = 13.sp)
                            }
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text("MANCATE PARTECIPAZIONI", fontSize = 9.sp, color = TextSecondary)
                                Text("${applicant.noShows}", fontWeight = FontWeight.Bold, color = if (applicant.noShows > 0) Color.Red else Color.Green, fontSize = 14.sp)
                            }
                        }

                        Spacer(modifier = Modifier.height(16.dp))

                        // High trust status explanation
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(BorderStroke(1.dp, PremiumGold.copy(alpha = 0.3f)), RoundedCornerShape(8.dp))
                                .padding(10.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Icon(imageVector = Icons.Default.FavoriteBorder, contentDescription = "Trust Indicator", tint = PremiumGold, modifier = Modifier.size(16.dp))
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                text = if (applicant.noShows == 0) "Nessuna mancata partecipazione storica. Partecipante AD ALTA AFFIDABILITÀ." else "Attenzione: Profilo con mancate partecipazioni storiche.",
                                fontSize = 11.sp,
                                color = if (applicant.noShows == 0) Color.LightGray else Color.Red
                            )
                        }
                    }
                },
                confirmButton = {
                    Button(
                        onClick = {
                            // Host to Approve instantly
                            SupabaseClient.reviewParticipationRequest(activeRequest.id, "approved")
                            selectedRequestToReview = null
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2E7D32))
                    ) {
                        Text("APPROVA OSPITE", color = Color.White, fontWeight = FontWeight.Bold)
                    }
                },
                dismissButton = {
                    Button(
                        onClick = {
                            // Host to Reject instantly
                            SupabaseClient.reviewParticipationRequest(activeRequest.id, "rejected")
                            selectedRequestToReview = null
                        },
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF8A80))
                    ) {
                        Text("RIFIUTA RICHIESTA", color = MatteDark, fontWeight = FontWeight.Bold)
                    }
                }
            )
        }
    }
}

// --- SUB-SCREEN 3: EVENT GATHERING CREATION FORM ---

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateEventForm(
    organizerId: String,
    onDismiss: () -> Unit
) {
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var maxParticipants by remember { mutableStateOf(8) }
    var locationName by remember { mutableStateOf("") }

    // Mock image paths simulating public Unsplash imagery or supabase storage asset key upload
    val mockImageOptions = listOf(
        "https://images.unsplash.com/photo-1541252260730-0412e8e2108e?auto=format&fit=crop&q=80&w=600",
        "https://images.unsplash.com/photo-1517457373958-b7bdd4587205?auto=format&fit=crop&q=80&w=600",
        "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?auto=format&fit=crop&q=80&w=600",
        "https://images.unsplash.com/photo-1519671482749-fd09be7ccebf?auto=format&fit=crop&q=80&w=600"
    )
    var selectedMockImageUrl by remember { mutableStateOf(mockImageOptions[0]) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MatteDark)
            .padding(16.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "CREA EVENTO RISERVATO",
                style = TextStyle(
                    fontFamily = FontFamily.SansSerif,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 16.sp,
                    letterSpacing = 1.sp,
                    color = PremiumGold
                )
            )
            IconButton(onClick = onDismiss) {
                Icon(imageVector = Icons.Default.Close, contentDescription = "Close", tint = PremiumGold)
            }
        }

        Spacer(modifier = Modifier.height(16.dp))

        // Title Input
        OutlinedTextField(
            value = title,
            onValueChange = { title = it },
            label = { Text("Titolo dell'Evento (es. Ballo in Maschera Amber)") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = PremiumGold,
                unfocusedBorderColor = Color(0xFF424242),
                focusedLabelColor = PremiumGold
            ),
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
        )

        // Description Input
        OutlinedTextField(
            value = description,
            onValueChange = { description = it },
            label = { Text("Concept Riservato / Protocollo di Ingresso") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = PremiumGold,
                unfocusedBorderColor = Color(0xFF424242),
                focusedLabelColor = PremiumGold
            ),
            maxLines = 4,
            modifier = Modifier.fillMaxWidth().height(100.dp).padding(bottom = 12.dp)
        )

        // Location General Area
        OutlinedTextField(
            value = locationName,
            onValueChange = { locationName = it },
            label = { Text("Indirizzo Privato (Sbloccato solo dopo l'approvazione)") },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = PremiumGold,
                unfocusedBorderColor = Color(0xFF424242),
                focusedLabelColor = PremiumGold
            ),
            modifier = Modifier.fillMaxWidth().padding(bottom = 12.dp)
        )

        // Capacity slider
        Text("Limite Massimo di Coppie: $maxParticipants", color = TextSecondary, fontSize = 13.sp, modifier = Modifier.padding(top = 8.dp))
        Slider(
            value = maxParticipants.toFloat(),
            onValueChange = { maxParticipants = it.toInt() },
            valueRange = 4f..20f,
            colors = SliderDefaults.colors(thumbColor = PremiumGold, activeTrackColor = PremiumGold)
        )

        Spacer(modifier = Modifier.height(16.dp))

        // MOCK SUPABASE STORAGE BUCKET IMAGE PICKER SELECTION UI
        Text(
            text = "COPERTINA EVENTO (Simulazione caricamento storage Supabase)",
            style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 11.sp, color = PremiumGold, letterSpacing = 1.sp)
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            mockImageOptions.forEach { url ->
                val isSelected = selectedMockImageUrl == url
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .border(
                            BorderStroke(if (isSelected) 3.dp else 1.dp, if (isSelected) PremiumGold else Color.DarkGray),
                            RoundedCornerShape(8.dp)
                        )
                        .clickable { selectedMockImageUrl = url }
                ) {
                    AsyncImage(
                        model = url,
                        contentDescription = "Cover option",
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Crop
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        Button(
            onClick = {
                if (title.isNotBlank() && locationName.isNotBlank()) {
                    // Seed random coordinates in Florence to ensure proper radius calculation compiles
                    val randomOffsetLat = (Math.random() - 0.5) * 0.03
                    val randomOffsetLng = (Math.random() - 0.5) * 0.03
                    val mockLat = 43.7695 + randomOffsetLat
                    val mockLng = 11.2558 + randomOffsetLng

                    // Uploads to Storage simulation and writes records in Events table
                    SupabaseClient.insertEventAndUploadImage(
                        title = title,
                        description = description,
                        organizerId = organizerId,
                        latitude = mockLat,
                        longitude = mockLng,
                        mockImagePath = selectedMockImageUrl,
                        maxParticipants = maxParticipants,
                        locationName = locationName
                    )

                    onDismiss()
                }
            },
            colors = ButtonDefaults.buttonColors(containerColor = PremiumGold),
            shape = RoundedCornerShape(24.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
        ) {
            Text("PUBBLICA EVENTO NEL CLUB", color = MatteDark, fontWeight = FontWeight.Bold)
        }
    }
}

// --- SUB-SCREEN 4: MESSAGES FOR CLUB ---

@Composable
fun ClubMessagesScreen() {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MatteDark)
            .padding(16.dp),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                imageVector = Icons.Default.Forum,
                contentDescription = "Chats empty",
                tint = TextSecondary,
                modifier = Modifier.size(54.dp)
            )
            Spacer(modifier = Modifier.height(16.dp))
            Text(
                text = "Stanze del Club Riservate",
                style = TextStyle(fontWeight = FontWeight.Bold, fontSize = 16.sp, color = TextPrimary)
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "I canali privati si apriranno per i partecipanti confermati una volta verificate le richieste.",
                style = TextStyle(fontSize = 12.sp, color = TextSecondary, lineHeight = 18.sp),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 24.dp)
            )
        }
    }
}
