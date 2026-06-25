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
subprojects {
    project.evaluationDependsOn(":app")
}

// Fuerza compileSdk >= 36 en TODOS los modulos (sqflite_android/geocoding y sus
// dependencias androidx/exifinterface exigen 36). Se hace por reflexion para no
// depender del tipo de AGP en el classpath raiz.
fun org.gradle.api.Project.forzarCompileSdk() {
    val androidExt = extensions.findByName("android") ?: return
    try {
        androidExt.javaClass
            .getMethod("compileSdkVersion", Int::class.javaPrimitiveType!!)
            .invoke(androidExt, 36)
    } catch (_: Exception) {
        // El modulo no expone compileSdkVersion(int); se ignora.
    }
}

subprojects {
    // Si el modulo ya fue evaluado (por evaluationDependsOn), se configura
    // ahora; si no, se difiere a afterEvaluate.
    if (state.executed) {
        forzarCompileSdk()
    } else {
        afterEvaluate { forzarCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
