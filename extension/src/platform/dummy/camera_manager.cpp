#include "../../camera_manager.h"
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/color.hpp>

using namespace godot;

struct CameraManager::Impl {
    Ref<ImageTexture> texture;
};

CameraManager::CameraManager() {
    impl = new Impl();
    impl->texture.instantiate();
    // Return a red test image
    Ref<Image> img = Image::create(128, 128, false, Image::FORMAT_RGBA8);
    img->fill(Color(1, 0, 0, 1));
    impl->texture->set_image(img);
}

CameraManager::~CameraManager() {
    delete impl;
}

void CameraManager::start() {}
void CameraManager::stop() {}
void CameraManager::update() {}

Ref<ImageTexture> CameraManager::get_texture() const {
    return impl->texture;
}
