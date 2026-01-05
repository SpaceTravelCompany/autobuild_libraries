# Auto Build Libraries

A project for automatically building multiple libraries with cross-compilation support.

## Supported Libraries

### Compression Libraries
- **libz (zlib)**: Data compression library.
- **bzip2**: Block-sorting compression algorithm library.
- **brotli**: General-purpose lossless compression algorithm library.

### Font Libraries
- **freetype**: Font library.

### Image Libraries
- **libwebp**: WebP image format library.

### Audio Libraries
- **libogg**: Ogg container format library.
- **opus**: Opus audio codec library.
- **libvorbis**: Vorbis audio codec library (depends on libogg).
- **opusfile**: High-level Opus file API library (depends on libogg and opus).
- **miniaudio**: Single-file audio playback and capture library (references all audio libraries).

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

**Note**: 
- Build libz, bzip2, and brotli before building freetype.
- Build libogg before building libvorbis.
- Build libogg and opus before building opusfile.
- Build all audio libraries (ogg, opus, vorbis, opusfile) before using miniaudio.

## Build Options

All build scripts support the following options:
- **Default**: Cross-compilation for multiple architectures
- `--native` or `-n`: Build only for native architecture
- `--android` or `-a`: Build for Android (static libraries only)
- `--windows`: Build for Windows native

Cross-compilation is performed for the following target architectures, building both **shared libraries** and **static libraries** for each target:
- `aarch64-linux-gnu`
- `riscv64-linux-gnu`
- `x86_64-linux-gnu`