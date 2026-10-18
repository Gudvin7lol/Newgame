# ZAMER 3D Engine • Native prototype

Собственный нативный движок для Android. **Нет Godot, Unity, WebView, Three.js.**

- Kotlin Activity: приложение и сенсорный интерфейс.
- C++17: сцена, редактируемые полигональные сетки, камера, сериализация.
- OpenGL ES 3.0: собственные шейдеры и GPU-рендеринг.
- Android NDK/CMake: библиотека libzamerengine.so.
- GitHub Actions + Gradle: APK.

## Что работает в первом ядре

Нативный 3D preview, орбитальная камера и pinch zoom; геометрические объекты;
выбор, преобразование, выдавливание грани и subdivision;
простые PBR metallic/roughness материалы с GGX, сохранение и восстановление собственного проекта.

Это **не готовая замена Blender**. Пока нет сложного скульптинга, UV unwrap, текстурных карт и фотореалистичного офлайн-рендера. Цель этого этапа: независимая техническая основа, проверяемая сборкой APK.

Файлы проекта хранятся в приватной памяти приложения. Импорт/экспорт GLB и Android SAF предстоит добавить.

## APK
Actions → Build ZAMER Native 3D Engine → Artifacts → ZAMER-Native-Engine-APK.
В ZIP лежит тестовый ARM64 APK.
