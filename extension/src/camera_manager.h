#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/core/binder_common.hpp>

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

private:
    Impl* impl;
};
