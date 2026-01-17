#include "native_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

NativeBridge::NativeBridge() {
	camera = new CameraManager();
	set_process(true);
	// EDUCATIONAL:
	// UtilityFunctions::print() is the C++ equivalent of GDScript's print().
	// It outputs text to the Godot Editor console/debugger.
	UtilityFunctions::print("NativeBridge (C++) initialized.");
}

NativeBridge::~NativeBridge() {
	if (camera) {
		delete camera;
	}
}

void NativeBridge::_process(double delta) {
	if (camera) {
		camera->update();
	}
}

void NativeBridge::start_camera() {
	if (camera) {
		camera->start();
	}
}

void NativeBridge::stop_camera() {
	if (camera) {
		camera->stop();
	}
}

Ref<ImageTexture> NativeBridge::get_camera_texture() const {
	if (camera) {
		return camera->get_texture();
	}
	return Ref<ImageTexture>();
}

void NativeBridge::request_camera_permission() {
	UtilityFunctions::print("NativeBridge (C++): Requesting camera permission...");
	// TODO: Implement native iOS permission request using Objective-C++ (AVFoundation)
	// We can route this to start_camera() or keep separate.
	start_camera();
}

void NativeBridge::initialize_camera() {
	UtilityFunctions::print("NativeBridge (C++): Initializing camera...");
	// TODO: Implement native camera initialization
	start_camera();
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
	ClassDB::bind_method(D_METHOD("start_camera"), &NativeBridge::start_camera);
	ClassDB::bind_method(D_METHOD("stop_camera"), &NativeBridge::stop_camera);
	ClassDB::bind_method(D_METHOD("get_camera_texture"), &NativeBridge::get_camera_texture);

	ClassDB::bind_method(D_METHOD("request_camera_permission"), &NativeBridge::request_camera_permission);
	ClassDB::bind_method(D_METHOD("initialize_camera"), &NativeBridge::initialize_camera);
	ClassDB::bind_method(D_METHOD("capture_photo"), &NativeBridge::capture_photo);
}