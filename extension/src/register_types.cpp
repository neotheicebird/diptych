#include "register_types.h"

#include "native_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/defs.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

// EDUCATIONAL:
// This function is called when the extension module is initialized.
// We check the 'p_level' to ensuring we register our classes at the correct stage
// of the engine's startup process (MODULE_INITIALIZATION_LEVEL_SCENE is standard for gameplay classes).
void initialize_diptych_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	// EDUCATIONAL:
	// We must explicitly register every custom C++ class so Godot knows it exists.
	ClassDB::register_class<NativeBridge>();
}

void uninitialize_diptych_module(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_SCENE) {
		return;
	}
	// Cleanup logic (if any) would go here.
}

extern "C" {
// EDUCATIONAL:
// This is the main entry point for the shared library (GDExtension).
// Godot calls this C-style function to load the library.
// It sets up the 'InitObject' with our initializer and terminator functions.
GDExtensionBool GDE_EXPORT diptych_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address, const GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

	init_obj.register_initializer(initialize_diptych_module);
	init_obj.register_terminator(uninitialize_diptych_module);

	return init_obj.init();
}
}