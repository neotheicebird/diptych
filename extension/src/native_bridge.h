#ifndef NATIVE_BRIDGE_H
#define NATIVE_BRIDGE_H

// EDUCATIONAL:
// We include <godot_cpp/classes/node.hpp> to inherit from Godot's fundamental Node class.
// This allows our C++ class to be attached to the Scene Tree, process callbacks (like _process),
// and interact with other nodes, just like a GDScript 'extends Node'.
#include <godot_cpp/classes/node.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
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
	Ref<ImageTexture> get_texture_top() const;
	Ref<ImageTexture> get_texture_bottom() const;
	bool is_multicam_supported() const;
	
	Dictionary get_available_devices() const;
	void set_device(int view_index, String device_id);
    
    // Interactive Controls
    void set_zoom_factor(int view_index, float zoom_factor);
    void set_focus_point(int view_index, float x, float y);
    void trigger_haptic_impact();

	// Placeholder methods for future iOS integration.
	void request_camera_permission();
	void initialize_camera();
	void capture_photo();

	// EDUCATIONAL:
	// These methods are the public API for the new split-image capture flow.
	// Godot calls these, and the native layer performs the heavy lifting.
	void capture_split_image();
	void set_composite_layout(float viewer_width, float viewer_height, float separator_thickness, Color separator_color);
	void open_photo_library();
};

#endif // NATIVE_BRIDGE_H
