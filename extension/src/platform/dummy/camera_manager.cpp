#include "../../camera_manager.h"
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/color.hpp>

using namespace godot;

struct CameraManager::Impl {
    Ref<ImageTexture> texture_top;
    Ref<ImageTexture> texture_bottom;
};

CameraManager::CameraManager() {
    impl = new Impl();
    
    // Top: Red
    impl->texture_top.instantiate();
    Ref<Image> imgTop = Image::create(128, 128, false, Image::FORMAT_RGBA8);
    imgTop->fill(Color(1, 0, 0, 1)); // Red
    impl->texture_top->set_image(imgTop);
    
    // Bottom: Blue
    impl->texture_bottom.instantiate();
    Ref<Image> imgBot = Image::create(128, 128, false, Image::FORMAT_RGBA8);
    imgBot->fill(Color(0, 0, 1, 1)); // Blue
    impl->texture_bottom->set_image(imgBot);
}

CameraManager::~CameraManager() {
    delete impl;
}

void CameraManager::start() {}
void CameraManager::stop() {}
void CameraManager::update() {}

Ref<ImageTexture> CameraManager::get_texture_top() const {
    return impl->texture_top;
}

Ref<ImageTexture> CameraManager::get_texture_bottom() const {
    return impl->texture_bottom;
}

bool CameraManager::is_multicam_supported() const {
    return false; // Dummy implementation
}
