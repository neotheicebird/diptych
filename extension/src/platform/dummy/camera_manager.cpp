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

Dictionary CameraManager::get_available_devices() const {
    Dictionary d;
    d["mock_wide"] = "Mock Wide Camera";
    d["mock_ultra"] = "Mock Ultra Wide Camera";
    d["mock_front"] = "Mock Front Camera";
    return d;
}

void CameraManager::set_device(int view_index, String device_id) {
    // Just mock behavior: fill texture with a color based on device_id
    Color c = Color(1, 1, 1, 1);
    if (device_id == "mock_wide") c = Color(1, 0, 0, 1); // Red
    else if (device_id == "mock_ultra") c = Color(0, 1, 0, 1); // Green
    else if (device_id == "mock_front") c = Color(0, 0, 1, 1); // Blue
    
    Ref<Image> img = Image::create(128, 128, false, Image::FORMAT_RGBA8);
    img->fill(c);
    
    if (view_index == 0) impl->texture_top->set_image(img);
    else impl->texture_bottom->set_image(img);
}

void CameraManager::set_zoom_factor(int view_index, float zoom_factor) {
    // Dummy: do nothing
}

void CameraManager::set_focus_point(int view_index, float x, float y) {
    // Dummy: do nothing
}

void CameraManager::trigger_haptic_impact() {
    // Dummy: do nothing
}

void CameraManager::set_permission_callback(std::function<void()> callback) {
    // Dummy: do nothing
}
