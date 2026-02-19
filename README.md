# Auto Build Libraries

A project for automatically building multiple libraries with cross-compilation support.

## Supported Libraries

### Compression Libraries
- **[libz (zlib)](https://github.com/madler/zlib)**: Data compression library.
- **[bzip2](https://gitlab.com/bzip2/bzip2)**: Block-sorting compression algorithm library.
- **[brotli](https://github.com/google/brotli)**: General-purpose lossless compression algorithm library.

### Font Libraries
- **[freetype](https://gitlab.freedesktop.org/freetype/freetype)**: Font library.

### Image Libraries
- **[libwebp](https://chromium.googlesource.com/webm/libwebp)**: WebP image encoding/decoding library.
- **[openexr](https://github.com/AcademySoftwareFoundation/openexr)**: openexr image encoding/decoding library.

### Audio Libraries
- **[libogg](https://github.com/xiph/ogg)**: Ogg container format library.
- **[opus](https://github.com/xiph/opus)**: Opus audio codec library.
- **[libvorbis](https://github.com/xiph/vorbis)**: Vorbis audio codec library (depends on libogg).
- **[opusfile](https://github.com/xiph/opusfile)**: High-level Opus file API library (depends on libogg and opus).
- **[miniaudio](https://github.com/mackron/miniaudio)**: Single-file audio playback and capture library (references all audio libraries).

## Math
- **[clipper2](https://github.com/AngusJohnson/Clipper2)**: Polygon Clipping, Offsetting & Triangulation library.
- **[Imath](https://github.com/AcademySoftwareFoundation/Imath)**: Math library of 2D and 3D vector, matrix, and math operations for computer graphics (dependency of openexr).

### Misc
- **[lua](https://github.com/lua/lua)**: Script Programming language.
- **[glslang](https://github.com/KhronosGroup/glslang)**: Shader Compilation library.

## Getting Started

#### Building libz (zlib)

**Cross-compilation (default)**:
```bash
chmod +x build_libz.sh
./build_libz.sh
```

**Native build only**:
```bash
./build_libz.sh --native
# or
./build_libz.sh -n
```

Built libraries are installed in the `install/libz/<target>/` directory.

etc...


## Build Options

All build scripts support the following options:
- **Default**: Cross-compilation for multiple architectures
- `--native` or `-n`: Build only for native architecture
- `--android` or `-a`: Build for Android (static libraries only)
- `--windows` or `-w`: Build for Windows native

Cross-compilation is performed for the following target architectures, building both **shared libraries** and **static libraries** for each target:
- `aarch64-linux-gnu`
- `riscv64-linux-gnu`
- `x86_64-linux-gnu`