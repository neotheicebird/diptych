#include "../../camera_manager.h"
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/rect2.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <cstring>

using namespace godot;

struct CameraManager::Impl {
    Ref<ImageTexture> texture_top;
    Ref<ImageTexture> texture_bottom;
    Dictionary layout_snapshot;
    std::function<void()> image_save_started_callback;
    std::function<void(const PackedByteArray &)> image_save_finished_callback;
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

void CameraManager::set_image_save_started_callback(std::function<void()> callback) {
    impl->image_save_started_callback = callback;
}

void CameraManager::set_image_save_finished_callback(std::function<void(const PackedByteArray &)> callback) {
    impl->image_save_finished_callback = callback;
}

void CameraManager::set_layout_snapshot(const Dictionary &layout_snapshot) {
    impl->layout_snapshot = layout_snapshot;
}

static Vector2i _extract_output_size(const Dictionary &layout_snapshot) {
    Vector2i output_size(1080, 1920);
    if (!layout_snapshot.has("output_size")) {
        return output_size;
    }

    Variant size_variant = layout_snapshot["output_size"];
    if (size_variant.get_type() == Variant::VECTOR2I) {
        output_size = size_variant;
    } else if (size_variant.get_type() == Variant::VECTOR2) {
        Vector2 size = size_variant;
        output_size = Vector2i((int)MAX(1.0f, size.x), (int)MAX(1.0f, size.y));
    }
    return output_size;
}

void CameraManager::capture_layout_image(const Dictionary &layout_snapshot) {
    Dictionary snapshot = layout_snapshot;
    if (snapshot.is_empty()) {
        snapshot = impl->layout_snapshot;
    }

    if (impl->image_save_started_callback) {
        impl->image_save_started_callback();
    }

    Vector2i output_size = _extract_output_size(snapshot);
    Ref<Image> composed = Image::create(output_size.x, output_size.y, false, Image::FORMAT_RGBA8);
    composed->fill(Color(0.05, 0.05, 0.05, 1.0));

    if (snapshot.has("slots")) {
        Array slots = snapshot["slots"];
        for (int64_t i = 0; i < slots.size(); i++) {
            if (slots[i].get_type() != Variant::DICTIONARY) {
                continue;
            }
            Dictionary slot = slots[i];
            if (!slot.has("rect")) {
                continue;
            }

            Rect2 normalized_rect = slot["rect"];
            int x = (int)(normalized_rect.position.x * output_size.x);
            int y = (int)(normalized_rect.position.y * output_size.y);
            int w = (int)(normalized_rect.size.x * output_size.x);
            int h = (int)(normalized_rect.size.y * output_size.y);
            if (w <= 0 || h <= 0) {
                continue;
            }

            String stream_id = slot.get("stream_id", String("primary"));
            Color slot_color = (stream_id == "secondary") ? Color(0.20, 0.42, 0.93, 1.0) : Color(0.94, 0.31, 0.21, 1.0);
            if (stream_id == "overlay") {
                slot_color = Color(0.98, 0.80, 0.18, 0.75);
            }
            composed->fill_rect(Rect2i(x, y, w, h), slot_color);
        }
    }

    if (snapshot.has("separators")) {
        Array separators = snapshot["separators"];
        for (int64_t i = 0; i < separators.size(); i++) {
            if (separators[i].get_type() != Variant::DICTIONARY) {
                continue;
            }
            Dictionary separator = separators[i];
            if (!separator.has("rect")) {
                continue;
            }

            Rect2 normalized_rect = separator["rect"];
            Color separator_color = separator.get("color", Color(1, 1, 1, 0.22));
            int x = (int)(normalized_rect.position.x * output_size.x);
            int y = (int)(normalized_rect.position.y * output_size.y);
            int w = (int)(normalized_rect.size.x * output_size.x);
            int h = (int)(normalized_rect.size.y * output_size.y);
            if (w <= 0 || h <= 0) {
                continue;
            }
            composed->fill_rect(Rect2i(x, y, w, h), separator_color);
        }
    }

    Ref<Image> thumbnail = Image::create_from_data(
        composed->get_width(),
        composed->get_height(),
        false,
        Image::FORMAT_RGBA8,
        composed->get_data()
    );
    thumbnail->resize(256, 256, Image::INTERPOLATE_LANCZOS);
    PackedByteArray thumbnail_png = thumbnail->save_png_to_buffer();

    if (impl->image_save_finished_callback) {
        impl->image_save_finished_callback(thumbnail_png);
    }
}

void CameraManager::open_photo_library() {
    // Dummy: no-op.
}

void CameraManager::open_latest_saved_photo() {
    // Dummy: no-op.
}
