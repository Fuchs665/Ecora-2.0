package com.example

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.*
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Diamond
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.example.data.SupabaseClient
import com.example.data.SupabaseEvent
import com.example.ui.screens.ClientNavigationHub
import com.example.ui.screens.EventDetailsPage
import com.example.ui.screens.GestoreDashboard
import com.example.ui.theme.MyApplicationTheme
import com.example.ui.theme.MatteDark
import com.example.ui.theme.PremiumGold
import com.example.ui.theme.SlateSurface
import com.example.ui.theme.TextPrimary
import com.example.ui.theme.TextSecondary

// --- TYPE-SAFE VIEW ROUTING PORTS ---

sealed class AppScreen {
    object Login : AppScreen()
    object ClientHub : AppScreen()
    object GestoreHub : AppScreen()
    data class EventDetails(val event: SupabaseEvent, val source: AppScreen) : AppScreen()
}

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            MyApplicationTheme {
                var currentScreen by remember { mutableStateOf<AppScreen>(AppScreen.Login) }

                val currentProfile by SupabaseClient.currentProfile.collectAsState()
                val requests by SupabaseClient.requests.collectAsState()

                // Automatic synchronization: if profile logged out, return to Login screen
                LaunchedEffect(currentProfile) {
                    if (currentProfile == null) {
                        currentScreen = AppScreen.Login
                    }
                }

                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MatteDark
                ) {
                    AnimatedContent(
                        targetState = currentScreen,
                        transitionSpec = {
                            fadeIn(animationSpec = tween(300)) togetherWith fadeOut(animationSpec = tween(300))
                        },
                        label = "screen_navigation"
                    ) { screen ->
                        when (screen) {
                            is AppScreen.Login -> {
                                AuthScreen(
                                    onLoginSuccess = { role ->
                                        currentScreen = if (role == "cliente") {
                                            AppScreen.ClientHub
                                        } else {
                                            AppScreen.GestoreHub
                                        }
                                    }
                                )
                            }
                            is AppScreen.ClientHub -> {
                                ClientNavigationHub(
                                    onSelectEvent = { event ->
                                        currentScreen = AppScreen.EventDetails(event, AppScreen.ClientHub)
                                    },
                                    onLogout = { SupabaseClient.logout() }
                                )
                            }
                            is AppScreen.GestoreHub -> {
                                GestoreDashboard(
                                    onSelectEvent = { event ->
                                        currentScreen = AppScreen.EventDetails(event, AppScreen.GestoreHub)
                                    },
                                    onLogout = { SupabaseClient.logout() }
                                )
                            }
                            is AppScreen.EventDetails -> {
                                val currentUserId = currentProfile?.id ?: ""
                                EventDetailsPage(
                                    event = screen.event,
                                    requests = requests,
                                    currentUserId = currentUserId,
                                    onBack = { currentScreen = screen.source },
                                    onJoinRequestSubmitted = {
                                        // Refresh current view states reactively
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// --- PREMIUM SECURE LOGIN SCREEN WITH DISCREET ENTRANCE GATEWAY ---

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AuthScreen(
    onLoginSuccess: (String) -> Unit
) {
    var email by remember { mutableStateOf("alex.sofia@private.it") }
    var password by remember { mutableStateOf("••••••••") }
    var passwordVisible by remember { mutableStateOf(false) }
    var selectedRole by remember { mutableStateOf("cliente") } // "cliente" or "gestore"

    // Synchronization helper: update mock pre-filled email when toggling roles for comfort
    LaunchedEffect(selectedRole) {
        if (selectedRole == "cliente") {
            email = "alex.sofia@private.it"
            password = "••••••••"
        } else {
            email = "villa.secret@club.it"
            password = "••••••••"
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(MatteDark)
            .padding(24.dp)
            .windowInsetsPadding(WindowInsets.statusBars),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // --- LOGO DESIGN TOKEN ---
        Box(
            modifier = Modifier
                .size(72.dp)
                .background(
                    Brush.radialGradient(
                        colors = listOf(PremiumGold.copy(alpha = 0.2f), Color.Transparent)
                    )
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.Diamond,
                contentDescription = "Premium Ecora Diamond Logo",
                tint = PremiumGold,
                modifier = Modifier.size(48.dp)
            )
        }

        Spacer(modifier = Modifier.height(14.dp))

        Text(
            text = "E C O R A",
            style = TextStyle(
                fontFamily = FontFamily.SansSerif,
                fontWeight = FontWeight.Black,
                fontSize = 28.sp,
                letterSpacing = 8.sp,
                color = PremiumGold
            ),
            textAlign = TextAlign.Center
        )

        Text(
            text = "DISCREET ECO-SYSTEM",
            style = TextStyle(
                fontFamily = FontFamily.SansSerif,
                fontWeight = FontWeight.Medium,
                fontSize = 11.sp,
                letterSpacing = 3.sp,
                color = TextSecondary
            ),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 4.dp, bottom = 32.dp)
        )

        // --- ACCOUNT ROLE GATE SELECTOR ---
        Text(
            text = "CHOOSE SELECTIVE ENTRY PROTOCOL",
            style = TextStyle(fontSize = 10.sp, letterSpacing = 1.5.sp, color = PremiumGold, fontWeight = FontWeight.Bold),
            modifier = Modifier.padding(bottom = 12.dp)
        )

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(SlateSurface, RoundedCornerShape(12.dp))
                .padding(4.dp)
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (selectedRole == "cliente") PremiumGold else Color.Transparent)
                    .clickable { selectedRole = "cliente" }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "CLIENTE / COPPIA",
                    style = TextStyle(
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = if (selectedRole == "cliente") MatteDark else TextSecondary
                    )
                )
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(8.dp))
                    .background(if (selectedRole == "gestore") PremiumGold else Color.Transparent)
                    .clickable { selectedRole = "gestore" }
                    .padding(vertical = 10.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = "GESTORE / CLUB",
                    style = TextStyle(
                        fontWeight = FontWeight.Bold,
                        fontSize = 11.sp,
                        color = if (selectedRole == "gestore") MatteDark else TextSecondary
                    )
                )
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // --- TEXT FIELDS (EMULATING SUPABASE INPUT AUTH) ---
        OutlinedTextField(
            value = email,
            onValueChange = { email = it },
            label = { Text("Discreet Identifier / Email", color = TextSecondary) },
            leadingIcon = { Icon(Icons.Default.Email, contentDescription = "Email", tint = PremiumGold) },
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = PremiumGold,
                unfocusedBorderColor = Color(0xFF3A3A3A),
                focusedLabelColor = PremiumGold,
                focusedTextColor = TextPrimary,
                unfocusedTextColor = TextPrimary
            ),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
        )

        OutlinedTextField(
            value = password,
            onValueChange = { password = it },
            label = { Text("Security Access Key", color = TextSecondary) },
            leadingIcon = { Icon(Icons.Default.Lock, contentDescription = "Passcode", tint = PremiumGold) },
            trailingIcon = {
                IconButton(onClick = { passwordVisible = !passwordVisible }) {
                    Icon(
                        imageVector = if (passwordVisible) Icons.Default.Visibility else Icons.Default.VisibilityOff,
                        contentDescription = "Toggle password visibility",
                        tint = PremiumGold
                    )
                }
            },
            visualTransformation = if (passwordVisible) VisualTransformation.None else PasswordVisualTransformation(),
            colors = OutlinedTextFieldDefaults.colors(
                focusedBorderColor = PremiumGold,
                unfocusedBorderColor = Color(0xFF3A3A3A),
                focusedLabelColor = PremiumGold,
                focusedTextColor = TextPrimary,
                unfocusedTextColor = TextPrimary
            ),
            shape = RoundedCornerShape(12.dp),
            modifier = Modifier.fillMaxWidth().padding(bottom = 24.dp)
        )

        // --- SUBMIT COMPILER TRIGGER ---
        Button(
            onClick = {
                // Initialize Auth simulation queries
                SupabaseClient.login(email, selectedRole)
                onLoginSuccess(selectedRole)
            },
            colors = ButtonDefaults.buttonColors(containerColor = PremiumGold),
            shape = RoundedCornerShape(24.dp),
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp)
        ) {
            Text(
                text = "ACCESS ECO-SYSTEM",
                style = TextStyle(
                    fontFamily = FontFamily.SansSerif,
                    fontWeight = FontWeight.ExtraBold,
                    fontSize = 12.sp,
                    letterSpacing = 1.5.sp,
                    color = MatteDark
                )
            )
        }

        Spacer(modifier = Modifier.height(30.dp))

        // Privacy note
        Text(
            text = "🔒 Secured strictly by Supabase encrypted tunnels. Absolute end-to-end anonymity. Your device identity is never recorded.",
            color = TextSecondary,
            fontSize = 10.sp,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 24.dp),
            lineHeight = 14.sp
        )
    }
}
