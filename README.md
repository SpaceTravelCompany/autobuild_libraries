# Auto Build Libraries

A project for automatically building multiple libraries with cross-compilation support.

## Supported Libraries

### Compression Libraries
- **libz (zlib)**: Data compression library. [Source](https://github.com/madler/zlib)
- **bzip2**: Block-sorting compression algorithm library. [Source](https://gitlab.com/bzip2/bzip2)
- **brotli**: General-purpose lossless compression algorithm library. [Source](https://github.com/google/brotli)

### Font Libraries
- **freetype**: Font library. [Source](https://gitlab.freedesktop.org/freetype/freetype)

### Image Libraries
- **libwebp**: WebP image encoding/decoding library. [Source](https://chromium.googlesource.com/webm/libwebp)
- **openexr**: openexr image encoding/decoding library. [Source](https://github.com/AcademySoftwareFoundation/openexr)

### Audio Libraries
- **libogg**: Ogg container format library. [Source](https://github.com/xiph/ogg)
- **opus**: Opus audio codec library. [Source](https://github.com/xiph/opus)
- **libvorbis**: Vorbis audio codec library (depends on libogg). [Source](https://github.com/xiph/vorbis)
- **opusfile**: High-level Opus file API library (depends on libogg and opus). [Source](https://github.com/xiph/opusfile)
- **miniaudio**: Single-file audio playback and capture library (references all audio libraries). [Source](https://github.com/mackron/miniaudio)

## Math
- **clipper2**: Polygon Clipping, Offsetting & Triangulation library. [Source](https://github.com/AngusJohnson/Clipper2)
- **Imath**: Math library of 2D and 3D vector, matrix, and math operations for computer graphics (dependency of openexr). [Source](https://github.com/AcademySoftwareFoundation/Imath)

### Misc
- **lua**: Script Programming language. [Source](https://github.com/lua/lua)
- **glslang**: Shader Compilation library. [Source](https://github.com/KhronosGroup/glslang)

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