allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Plugin che compilano con un Android troppo vecchio per le librerie che
// usano (app_links 3.x, dipendenza di supabase_flutter 1.x, dichiara
// compileSdk 31; androidx ne chiede almeno 34): si compilano con 36. Cambia
// solo l'SDK di compilazione del plugin, non minSdk né targetSdk dell'app.
// Blocco CI.1: senza, la build release fallisce in checkReleaseAarMetadata.
subprojects {
    val raiseCompileSdk: Project.() -> Unit = {
        extensions.findByType(com.android.build.api.dsl.LibraryExtension::class.java)
            ?.let { android ->
                val current = android.compileSdk
                if (current == null || current < 34) android.compileSdk = 36
            }
    }
    if (state.executed) raiseCompileSdk() else afterEvaluate { raiseCompileSdk() }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
