#ifndef NATIVE_BRIDGE_H
#define NATIVE_BRIDGE_H

// EDUCATIONAL:
// We include <godot_cpp/classes/node.hpp> to inherit from Godot's fundamental Node class.
// This allows our C++ class to be attached to the Scene Tree, process callbacks (like _process),
// and interact with other nodes, just like a GDScript 'extends Node'.
#include <godot_cpp/classes/node.hpp>
#include "camera_manager.h"

using namespace godot;

// EDUCATIONAL:
// This class serves as the C++ implementation of our Native Bridge.
// By implementing it in C++, we gain:
// 1. Performance: Loop-heavy operations (like image processing) will be significantly faster.
// 2. Systems Access: Easier integration with OS-level C/C++ APIs (iOS frameworks).
class NativeBridge : public Node {
	// EDUCATIONAL:
	// GDCLASS is a macro provided by godot-cpp. It handles the necessary boilerplate
	// for Godot's object system, such as method registration and type checking.
	// Arguments: ClassName, ParentClassName.
	GDCLASS(NativeBridge, Node);

private:
	CameraManager* camera;

protected:
	// EDUCATIONAL:
	// _bind_methods() is the central hub for exposing C++ methods to Godot (GDScript).
	// Any function you want to call from "Native.my_function()" must be registered here.
	static void _bind_methods();

public:
	NativeBridge();
	~NativeBridge();

	// Godot Lifecycle
	void _process(double delta) override;

	// Camera API
	void start_camera();
	void stop_camera();
	Ref<ImageTexture> get_camera_texture() const;

	// Placeholder methods for future iOS integration.
	void request_camera_permission();
	void initialize_camera();
	void capture_photo();
};

#endif // NATIVE_BRIDGE_H