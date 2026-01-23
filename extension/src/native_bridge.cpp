#include "native_bridge.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

NativeBridge::NativeBridge() {
	camera = new CameraManager();
    camera->set_permission_callback([this]() {
        call_deferred("emit_signal", "permission_granted");
    });
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

Ref<ImageTexture> NativeBridge::get_texture_top() const {
	if (camera) {
		return camera->get_texture_top();
	}
	return Ref<ImageTexture>();
}

Ref<ImageTexture> NativeBridge::get_texture_bottom() const {
	if (camera) {
		return camera->get_texture_bottom();
	}
	return Ref<ImageTexture>();
}

bool NativeBridge::is_multicam_supported() const {
	if (camera) {
		return camera->is_multicam_supported();
	}
	return false;
}

Dictionary NativeBridge::get_available_devices() const {
	if (camera) {
		return camera->get_available_devices();
	}
	return Dictionary();
}

void NativeBridge::set_device(int view_index, String device_id) {
	if (camera) {
		camera->set_device(view_index, device_id);
	}
}

void NativeBridge::set_zoom_factor(int view_index, float zoom_factor) {
    if (camera) {
        camera->set_zoom_factor(view_index, zoom_factor);
    }
}

void NativeBridge::set_focus_point(int view_index, float x, float y) {
    if (camera) {
        camera->set_focus_point(view_index, x, y);
    }
}

void NativeBridge::trigger_haptic_impact() {
    if (camera) {
        camera->trigger_haptic_impact();
    }
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
	ClassDB::bind_method(D_METHOD("get_texture_top"), &NativeBridge::get_texture_top);
	ClassDB::bind_method(D_METHOD("get_texture_bottom"), &NativeBridge::get_texture_bottom);
	ClassDB::bind_method(D_METHOD("is_multicam_supported"), &NativeBridge::is_multicam_supported);
	
	ClassDB::bind_method(D_METHOD("get_available_devices"), &NativeBridge::get_available_devices);
	ClassDB::bind_method(D_METHOD("set_device", "view_index", "device_id"), &NativeBridge::set_device);
    
    ClassDB::bind_method(D_METHOD("set_zoom_factor", "view_index", "zoom_factor"), &NativeBridge::set_zoom_factor);
    ClassDB::bind_method(D_METHOD("set_focus_point", "view_index", "x", "y"), &NativeBridge::set_focus_point);
    ClassDB::bind_method(D_METHOD("trigger_haptic_impact"), &NativeBridge::trigger_haptic_impact);

	ClassDB::bind_method(D_METHOD("request_camera_permission"), &NativeBridge::request_camera_permission);
	ClassDB::bind_method(D_METHOD("initialize_camera"), &NativeBridge::initialize_camera);
	ClassDB::bind_method(D_METHOD("capture_photo"), &NativeBridge::capture_photo);
    
    ADD_SIGNAL(MethodInfo("permission_granted"));
}