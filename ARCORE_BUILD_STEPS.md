# Integrazione ARCore nativo — build da eseguire sul tuo Mac

Il plugin `godot_arcore` non ha una release precompilata: va compilato da sorgente.
Questo va fatto sul tuo Mac (serve un vero toolchain Android NDK/SDK e un fisico
collegamento al telefono per il test finale — cose che l'ambiente cloud di Claude
non ha a disposizione).

Le modifiche lato progetto Godot le ho già fatte io:
- `Scripts/Azione/player.gd`: ora prova prima l'interfaccia `"ARCore"`, poi
  `"OpenXR"` come fallback, poi la modalità PC. Se ARCore si inizializza,
  abilita anche plane detection (orizzontale/verticale) e instant placement.
- `export_presets.cfg`: `xr_features/xr_mode` riportato a `0` (Regular — il
  plugin ARCore non passa dal sistema OpenXR di Godot) e `gradle_build/min_sdk`
  impostato a `24` (minimo richiesto da ARCore).

## Prerequisiti

- Android Studio (comodo per SDK Manager/NDK, non strettamente necessario da riga di comando)
- Android NDK (versione compatibile con Godot 4.7)
- SCons: `pip3 install scons`
- Git

### Versione NDK richiesta: 23.2.8568313 (fissa, non configurabile)

Importante: la versione di `godot-cpp` usata da questo plugin ha la versione NDK
**fissata nel codice** a `23.2.8568313` (non è un parametro che si può cambiare da
riga di comando — se provi a passare `ndk_version=...` a scons viene ignorato con
un warning "Unknown SCons variables"). Serve installare esattamente questa, anche
se hai già altre versioni NDK installate per altri progetti (possono convivere).

- Controlla se ce l'hai già:
  ```bash
  ls "$ANDROID_HOME/ndk"
  ```
  Se tra le cartelle stampate vedi `23.2.8568313`, ce l'hai già, salta il punto sotto.
- Se non c'è, installala da Android Studio: **Settings → Languages & Frameworks →
  Android SDK → scheda "SDK Tools"** → in basso a destra spunta **"Show Package
  Details"** (senza questa spunta, Android Studio mostra "NDK (Side by side)" come
  voce unica e installa solo l'ultima versione) → nell'elenco che si apre sotto
  "NDK (Side by side)" cerca **23.2.8568313**, spuntala, e clicca **Apply**.

## 1. Clona il plugin

```bash
git clone https://github.com/GodotVR/godot_arcore.git
cd godot_arcore
git submodule update --init
```

## 2. Compila i binding C++ (godot-cpp) per arm64

Il tuo Mate 20 Pro (Kirin 980) è arm64, e nel tuo `export_presets.cfg` è l'unica
architettura abilitata (`architectures/arm64-v8a=true`).

**Prima di lanciare scons**, imposta la variabile d'ambiente `ANDROID_HOME` (SCons
la cerca per trovare l'NDK — se non è impostata ottieni `KeyError: 'ANDROID_HOME'`):

```bash
export ANDROID_HOME="$HOME/Library/Android/sdk"   # percorso di default su macOS se hai installato via Android Studio
ls "$ANDROID_HOME/ndk"   # deve comparire la cartella 23.2.8568313 (vedi sezione Prerequisiti sopra)
```

Poi compila, specificando esplicitamente `arch=arm64` (altrimenti SCons potrebbe usare
l'architettura di default della tua macchina, non quella del telefono). **Non serve**
passare `ndk_version`: in questa versione del plugin è fissa e viene ignorata se la
specifichi.

**Importante — `custom_api_file`:** il codice C++ del plugin (in particolare
`background_renderer.cpp`, che usa `CameraFeed::set_name/set_external/get_texture_tex_id`)
è scritto contro una versione dell'API di Godot diversa da quella di default inclusa
nel submodule `godot-cpp`. Il repository fornisce apposta un file API alternativo in
`thirdparty/godot_cpp_extension_api/extension_api.json` (confermato guardando la
pipeline CI ufficiale del progetto) — va passato esplicitamente, altrimenti la
compilazione del plugin fallisce più avanti con errori tipo "no member named 'set_name'
in 'godot::CameraFeed'":

```bash
cd godot-cpp
scons platform=android arch=arm64 target=template_debug custom_api_file=../thirdparty/godot_cpp_extension_api/extension_api.json -j4
scons platform=android arch=arm64 target=template_release custom_api_file=../thirdparty/godot_cpp_extension_api/extension_api.json -j4
cd ..
```

(Aumenta `-jN` in base ai core della tua CPU per velocizzare.)

## 3. Compila il plugin Android (AAR)

Il tuo `java` di default potrebbe essere una versione troppo recente per Gradle 8.9
(usato da questo progetto) — se `./gradlew assemble` fallisce con un errore criptico
che stampa solo un numero di versione (es. `25.0.3`), installa un JDK compatibile e
puntaci Gradle solo per questa build:

```bash
brew install openjdk@17
export JAVA_HOME="$(brew --prefix openjdk@17)"
```

```bash
dos2unix ./gradlew   # su macOS, se manca: sed -i '' 's/\r$//' gradlew && chmod +x gradlew
./gradlew clean
./gradlew assemble
```

Al termine, il plugin compilato compare in:

```
plugin/demo/addons/ARCorePlugin/
```

## 3bis. Bug noto: crash SIGSEGV in ARCoreInterface::_initialize()

Al primo test reale, il gioco crasha subito dopo che l'interfaccia ARCore viene
trovata (`Interface found (ARCore): ...` nel log). Il tombstone nativo mostra:

```
#00 _JNIEnv::FindClass — dentro ARCoreWrapper::get_global_context()
#01 ARCoreWrapper::get_global_context()
#02 godot::ARCoreInterface::_initialize()
```

Causa: `plugin/src/main/cpp/arcore_wrapper.cpp` salva un `JNIEnv*` una sola volta,
sul thread principale dell'Activity, e lo riusa da qualsiasi thread — ma
`ARCoreInterface::_initialize()` viene chiamato dal `GLThread` (il game loop di
Godot su Android gira lì). Un `JNIEnv*` è valido solo sul thread che l'ha ottenuto:
riusarlo da un altro thread causa un crash con null pointer. È un bug nel codice
del plugin, non nella configurazione del progetto.

**Fix:** sostituisci il contenuto di questi due file con quanto segue (rende
l'accesso a `JNIEnv` thread-safe, attaccando il thread corrente alla JVM se serve),
poi ricompila solo il plugin (non serve rifare la build di godot-cpp, solo
`./gradlew clean && ./gradlew assemble`):

`plugin/src/main/cpp/arcore_wrapper.h`:
```cpp
//
// Created by luca on 20.08.24.
//

#ifndef ARCOREPLUGIN_ARCORE_WRAPPER_H
#define ARCOREPLUGIN_ARCORE_WRAPPER_H

#include "utils.h"

class ARCoreWrapper {
public:
	static void initialize_environment(JNIEnv *env, jobject activity);
	static void uninitialize_environment(JNIEnv *env);

private:
	static JNIEnv *env;
	static JavaVM *jvm;
	static jobject arcore_plugin_instance;
	static jobject godot_instance;
	static jobject activity;
	static jclass godot_class;
	static jclass activity_class;

public:
	ARCoreWrapper();
	~ARCoreWrapper();

	// Thread-safe: attacca il thread corrente alla JVM se non è già collegato.
	static JNIEnv *get_env();
	static jobject get_godot_class();
	static jobject get_activity();
	static jobject get_global_context();
};

#endif //ARCOREPLUGIN_ARCORE_WRAPPER_H
```

`plugin/src/main/cpp/arcore_wrapper.cpp`:
```cpp
//
// Created by luca on 20.08.24.
//

#include "arcore_wrapper.h"
#include "utils.h"

JNIEnv *ARCoreWrapper::env = nullptr;
JavaVM *ARCoreWrapper::jvm = nullptr;
// Is this used?
jobject ARCoreWrapper::arcore_plugin_instance = nullptr;
jobject ARCoreWrapper::godot_instance = nullptr;
jobject ARCoreWrapper::activity = nullptr;
jclass ARCoreWrapper::godot_class = nullptr;
jclass ARCoreWrapper::activity_class = nullptr;

ARCoreWrapper::ARCoreWrapper() {}

ARCoreWrapper::~ARCoreWrapper() {}

void ARCoreWrapper::initialize_environment(JNIEnv *p_env, jobject p_activity) {
	env = p_env;
	p_env->GetJavaVM(&jvm);

	activity = p_env->NewGlobalRef(p_activity);

	// Get info about our Godot class to get pointers
	godot_class = p_env->FindClass("org/godotengine/godot/Godot");

	if (godot_class) {
		godot_class = (jclass)p_env->NewGlobalRef(godot_class);
	} else {
		ALOGE("ARCorePlugin: Can't find org/godotengine/godot/Godot");
		return;
	}

	activity_class = p_env->FindClass("android/app/Activity");

	if (activity_class) {
		activity_class = (jclass)p_env->NewGlobalRef(activity_class);
	} else {
		ALOGE("ARCorePlugin: Can't find android/app/Activity");
		return;
	}
}

void ARCoreWrapper::uninitialize_environment(JNIEnv *env) {
	if (arcore_plugin_instance) {
		ALOGV("ARCorePlugin: ARCore instance found.");
		env->DeleteGlobalRef(arcore_plugin_instance);

		arcore_plugin_instance = nullptr;

		env->DeleteGlobalRef(godot_instance);
		env->DeleteGlobalRef(godot_class);
		env->DeleteGlobalRef(activity);
		env->DeleteGlobalRef(activity_class);
	}
}

JNIEnv *ARCoreWrapper::get_env() {
	if (jvm == nullptr) {
		// Non dovrebbe succedere (initialize_environment non ancora chiamata),
		// ma torniamo il vecchio puntatore piuttosto che crashare qui.
		return env;
	}

	JNIEnv *thread_env = nullptr;
	jint result = jvm->GetEnv((void **)&thread_env, JNI_VERSION_1_6);

	if (result == JNI_EDETACHED) {
		if (jvm->AttachCurrentThread(&thread_env, nullptr) != JNI_OK) {
			ALOGE("ARCorePlugin: Failed to attach current thread to the JVM");
			return env;
		}
	} else if (result != JNI_OK) {
		ALOGE("ARCorePlugin: JavaVM::GetEnv failed with error %d", result);
		return env;
	}

	return thread_env;
}

jobject ARCoreWrapper::get_godot_class() {
	return godot_class;
}

jobject ARCoreWrapper::get_activity() {
	return activity;
}

jobject ARCoreWrapper::get_global_context() {
	JNIEnv *thread_env = get_env();

	jclass activityThread = thread_env->FindClass("android/app/ActivityThread");
	jmethodID currentActivityThread = thread_env->GetStaticMethodID(activityThread, "currentActivityThread", "()Landroid/app/ActivityThread;");
	jobject activityThreadObj = thread_env->CallStaticObjectMethod(activityThread, currentActivityThread);

	jmethodID getApplication = thread_env->GetMethodID(activityThread, "getApplication", "()Landroid/app/Application;");
	jobject context = thread_env->CallObjectMethod(activityThreadObj, getApplication);
	return context;
}
```

Dopo aver salvato entrambi i file:
```bash
./gradlew clean
./gradlew assemble
```
poi ripeti il passo 4 (ricopia l'addon aggiornato nel progetto) e ritesta.

## 4. Installa l'addon nel progetto Exhibit!

Copia l'intera cartella `ARCorePlugin` dentro `addons/` del progetto, **senza
toccare** `godotopenxrvendors` che è già lì:

```bash
cp -R plugin/demo/addons/ARCorePlugin "/Users/libbertodr/exhibit!/addons/"
```

## 5. Abilita il plugin in Godot

- Apri il progetto in Godot
- Project → Project Settings → Plugins → abilita **ARCorePlugin**
  (questo aggiunge automaticamente l'autoload `ARCoreInterfaceInstance`)

## 6. Esporta e installa sul telefono

- Project → Export... → preset Android → Export Project (le impostazioni xr_mode/min_sdk sono già corrette)
- Installa l'APK sul Mate 20 Pro (sovrascrivendo la versione precedente)
- Avvia il gioco, e se possibile ricollega il telefono via USB per catturare il log:
  ```bash
  adb logcat -c   # pulisce il log prima di lanciare il gioco
  adb logcat > godot_log_arcore.txt
  ```
- Mandami il nuovo log (o incollamelo) così verifico se `XRServer.find_interface("ARCore")` trova l'interfaccia e se `initialize()` riesce.

## Note

- Se dopo il primo test la fotocamera non appare ma il resto funziona, controlla che
  il permesso Fotocamera sia stato concesso all'app su Android (Impostazioni → App → Exhibit! → Permessi).
- Il tuo Mate 20 Pro è nella lista ufficiale dei device supportati ARCore (con Depth API), quindi l'hardware non dovrebbe essere un ostacolo.
