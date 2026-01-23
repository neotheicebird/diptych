#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>
#include <functional>

using namespace godot;

class CameraManager {
public:
    struct Impl;
    CameraManager();
    ~CameraManager();

    void start();
    void stop();
    void update();
    Ref<ImageTexture> get_texture_top() const;
    Ref<ImageTexture> get_texture_bottom() const;
    bool is_multicam_supported() const;
    
    // New methods for camera selection
    Dictionary get_available_devices() const;
    void set_device(int view_index, String device_id);

    // Interactive controls
    void set_zoom_factor(int view_index, float zoom_factor);
    void set_focus_point(int view_index, float x, float y);
    void trigger_haptic_impact();
    
    void set_permission_callback(std::function<void()> callback);

private:
    Impl* impl;
};
