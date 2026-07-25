#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GLES2/gl2.h>

#include <ctype.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void fail(const char *message) {
  fprintf(stderr, "frdm-imx95 EGL smoke: %s\n", message);
  exit(EXIT_FAILURE);
}

static bool contains_case_insensitive(const char *haystack, const char *needle) {
  size_t needle_length = strlen(needle);
  if (needle_length == 0) {
    return true;
  }

  for (; *haystack != '\0'; ++haystack) {
    size_t index = 0;
    while (index < needle_length && haystack[index] != '\0' &&
           tolower((unsigned char)haystack[index]) ==
               tolower((unsigned char)needle[index])) {
      ++index;
    }
    if (index == needle_length) {
      return true;
    }
  }
  return false;
}

static bool is_software_renderer(const char *renderer) {
  static const char *software_names[] = {
      "llvmpipe",
      "softpipe",
      "swrast",
      "software rasterizer",
      "lavapipe",
  };

  for (size_t index = 0;
       index < sizeof(software_names) / sizeof(software_names[0]); ++index) {
    if (contains_case_insensitive(renderer, software_names[index])) {
      return true;
    }
  }
  return false;
}

static void json_string(const char *value) {
  putchar('"');
  for (const unsigned char *cursor = (const unsigned char *)value;
       *cursor != '\0'; ++cursor) {
    switch (*cursor) {
    case '"':
      fputs("\\\"", stdout);
      break;
    case '\\':
      fputs("\\\\", stdout);
      break;
    case '\b':
      fputs("\\b", stdout);
      break;
    case '\f':
      fputs("\\f", stdout);
      break;
    case '\n':
      fputs("\\n", stdout);
      break;
    case '\r':
      fputs("\\r", stdout);
      break;
    case '\t':
      fputs("\\t", stdout);
      break;
    default:
      if (*cursor < 0x20) {
        printf("\\u%04x", *cursor);
      } else {
        putchar(*cursor);
      }
    }
  }
  putchar('"');
}

static GLuint compile_shader(GLenum type, const char *source) {
  GLuint shader = glCreateShader(type);
  glShaderSource(shader, 1, &source, NULL);
  glCompileShader(shader);

  GLint compiled = GL_FALSE;
  glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
  if (compiled != GL_TRUE) {
    char log[1024] = {0};
    glGetShaderInfoLog(shader, sizeof(log), NULL, log);
    fprintf(stderr, "shader compilation failed: %s\n", log);
    exit(EXIT_FAILURE);
  }
  return shader;
}

int main(void) {
  PFNEGLGETPLATFORMDISPLAYEXTPROC get_platform_display =
      (PFNEGLGETPLATFORMDISPLAYEXTPROC)eglGetProcAddress(
          "eglGetPlatformDisplayEXT");
  EGLDisplay display =
      get_platform_display == NULL
          ? eglGetDisplay(EGL_DEFAULT_DISPLAY)
          : get_platform_display(EGL_PLATFORM_SURFACELESS_MESA,
                                 EGL_DEFAULT_DISPLAY, NULL);
  if (display == EGL_NO_DISPLAY) {
    fail("could not acquire a surfaceless EGL display");
  }

  EGLint egl_major = 0;
  EGLint egl_minor = 0;
  if (eglInitialize(display, &egl_major, &egl_minor) != EGL_TRUE) {
    fail("eglInitialize failed");
  }
  if (eglBindAPI(EGL_OPENGL_ES_API) != EGL_TRUE) {
    fail("eglBindAPI failed");
  }

  static const EGLint config_attributes[] = {
      EGL_SURFACE_TYPE,
      EGL_PBUFFER_BIT,
      EGL_RENDERABLE_TYPE,
      EGL_OPENGL_ES2_BIT,
      EGL_RED_SIZE,
      8,
      EGL_GREEN_SIZE,
      8,
      EGL_BLUE_SIZE,
      8,
      EGL_ALPHA_SIZE,
      8,
      EGL_NONE,
  };
  EGLConfig config = NULL;
  EGLint config_count = 0;
  if (eglChooseConfig(display, config_attributes, &config, 1, &config_count) !=
          EGL_TRUE ||
      config_count != 1) {
    fail("no suitable EGL pbuffer configuration");
  }

  static const EGLint surface_attributes[] = {
      EGL_WIDTH, 4, EGL_HEIGHT, 4, EGL_NONE,
  };
  EGLSurface surface =
      eglCreatePbufferSurface(display, config, surface_attributes);
  if (surface == EGL_NO_SURFACE) {
    fail("eglCreatePbufferSurface failed");
  }

  static const EGLint context_attributes[] = {
      EGL_CONTEXT_CLIENT_VERSION,
      2,
      EGL_NONE,
  };
  EGLContext context =
      eglCreateContext(display, config, EGL_NO_CONTEXT, context_attributes);
  if (context == EGL_NO_CONTEXT ||
      eglMakeCurrent(display, surface, surface, context) != EGL_TRUE) {
    fail("could not create or activate an OpenGL ES context");
  }

  const char *renderer = (const char *)glGetString(GL_RENDERER);
  const char *vendor = (const char *)glGetString(GL_VENDOR);
  const char *version = (const char *)glGetString(GL_VERSION);
  if (renderer == NULL || vendor == NULL || version == NULL) {
    fail("OpenGL ES identity strings are unavailable");
  }
  if (is_software_renderer(renderer)) {
    fprintf(stderr, "rejected software renderer: %s\n", renderer);
    return EXIT_FAILURE;
  }

  static const char *vertex_source =
      "attribute vec2 position;"
      "void main() { gl_Position = vec4(position, 0.0, 1.0); }";
  static const char *fragment_source =
      "precision mediump float;"
      "void main() { gl_FragColor = vec4(0.25, 0.50, 0.75, 1.0); }";
  GLuint vertex_shader = compile_shader(GL_VERTEX_SHADER, vertex_source);
  GLuint fragment_shader = compile_shader(GL_FRAGMENT_SHADER, fragment_source);
  GLuint program = glCreateProgram();
  glAttachShader(program, vertex_shader);
  glAttachShader(program, fragment_shader);
  glBindAttribLocation(program, 0, "position");
  glLinkProgram(program);

  GLint linked = GL_FALSE;
  glGetProgramiv(program, GL_LINK_STATUS, &linked);
  if (linked != GL_TRUE) {
    fail("shader program link failed");
  }

  static const GLfloat triangle[] = {
      -1.0f,
      -1.0f,
      3.0f,
      -1.0f,
      -1.0f,
      3.0f,
  };
  glViewport(0, 0, 4, 4);
  glUseProgram(program);
  glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 0, triangle);
  glEnableVertexAttribArray(0);
  glDrawArrays(GL_TRIANGLES, 0, 3);
  glFinish();

  unsigned char pixel[4] = {0};
  glReadPixels(2, 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, pixel);
  if (glGetError() != GL_NO_ERROR) {
    fail("render or readback returned a GL error");
  }

  static const unsigned char expected[] = {64, 128, 191, 255};
  for (size_t channel = 0; channel < 4; ++channel) {
    int difference = (int)pixel[channel] - (int)expected[channel];
    if (difference < -2 || difference > 2) {
      fprintf(stderr,
              "unexpected readback channel %zu: got %u, expected %u (+/- 2)\n",
              channel, pixel[channel], expected[channel]);
      return EXIT_FAILURE;
    }
  }

  fputs("{\"accepted\":true,\"egl\":{\"major\":", stdout);
  printf("%d,\"minor\":%d},\"renderer\":", egl_major, egl_minor);
  json_string(renderer);
  fputs(",\"vendor\":", stdout);
  json_string(vendor);
  fputs(",\"version\":", stdout);
  json_string(version);
  printf(",\"readback\":[%u,%u,%u,%u]}\n", pixel[0], pixel[1], pixel[2],
         pixel[3]);

  eglMakeCurrent(display, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  eglDestroyContext(display, context);
  eglDestroySurface(display, surface);
  eglTerminate(display);
  return EXIT_SUCCESS;
}
