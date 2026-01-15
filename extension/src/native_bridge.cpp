#include "native_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

NativeBridge::NativeBridge() {
	// EDUCATIONAL:
	// UtilityFunctions::print() is the C++ equivalent of GDScript's print().
	// It outputs text to the Godot Editor console/debugger.
	UtilityFunctions::print("NativeBridge (C++) initialized.");
}

NativeBridge::~NativeBridge() {
}

void NativeBridge::request_camera_permission() {
	UtilityFunctions::print("NativeBridge (C++): Requesting camera permission...");
	// TODO: Implement native iOS permission request using Objective-C++ (AVFoundation)
}

void NativeBridge::initialize_camera() {
	UtilityFunctions::print("NativeBridge (C++): Initializing camera...");
	// TODO: Implement native camera initialization
}

void NativeBridge::capture_photo() {
	UtilityFunctions::print("NativeBridge (C++): Capturing photo...");
	// TODO: Trigger native camera capture
}

// EDUCATIONAL:
// This static method is called by Godot when the class is registered.
// We use ClassDB::bind_method to map the string definition of the function (D_METHOD)
// to the actual C++ function pointer.
void NativeBridge::_bind_methods() {
	ClassDB::bind_method(D_METHOD("request_camera_permission"), &NativeBridge::request_camera_permission);
	ClassDB::bind_method(D_METHOD("initialize_camera"), &NativeBridge::initialize_camera);
	ClassDB::bind_method(D_METHOD("capture_photo"), &NativeBridge::capture_photo);
}