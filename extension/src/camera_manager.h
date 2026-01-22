#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/core/binder_common.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

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

private:
    Impl* impl;
};
