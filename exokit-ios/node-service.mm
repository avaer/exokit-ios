// (c) 2014 Boris van Schooten
//BEGIN_INCLUDE(all)
#include <string.h>
#include <cstring>
#include <unistd.h>
#include <stdlib.h>
#include <sstream>
#include <thread>
#include <functional>

#include <errno.h>

#include <libplatform/libplatform.h>
#include <v8.h>
#include <platform/macos/include/ContextQuartz2D.h>
#include <bindings/include/bindings.h>

using namespace v8;

/* // http://engineering.prezi.com/blog/2013/08/27/embedding-v8/
class MallocArrayBufferAllocator : public v8::ArrayBuffer::Allocator {
  public:
	virtual void* Allocate(size_t length) {
		return calloc(length, 1);
	}
	virtual void* AllocateUninitialized(size_t length) {
		return malloc(length);
	}
  virtual void* Reserve(size_t length) {
		return malloc(length);
  }
	// XXX we assume length is not needed
	virtual void Free(void*data, size_t length) {
		free(data);
	}
  virtual void Free(void*data, size_t length, v8::ArrayBuffer::Allocator::AllocationMode allocationMode) {
		free(data);
	}
  virtual void SetProtection(void *data, size_t length, v8::ArrayBuffer::Allocator::Protection protection) {
    // nothing
  }
}; */

//static void enableTypedArrays() {
//  v8::internal::FLAG_harmony_array_buffer = true;
//  v8::internal::FLAG_harmony_typed_arrays = true;
//  V8::SetArrayBufferAllocator(new MallocArrayBufferAllocator());
//}


// -----------------------------------------------
// data defs
// -----------------------------------------------
// -----------------------------------------------
// globals
// -----------------------------------------------

node::NodeService *service;
// JNIEnv *jnienv = NULL;
// jclass utilsClass;
std::function<void ()> serviceUiThreadFn;

void queueServiceUiThread(std::function<void ()> &&fn) {
  serviceUiThreadFn = fn;

  service->Scope([]() {
    serviceUiThreadFn();
  });

  std::function<void ()> nopFunctoon;
  serviceUiThreadFn = nopFunctoon;
}

// long readAsset(const char *filename, char **output);

// utils

/* // String data = loadStringAsset(String filename)
void __utils_loadStringAsset(const v8::FunctionCallbackInfo<v8::Value>& args) {
	String::Utf8Value _str_assetname(args[0]->ToString(args.GetIsolate()));
	const char *assetname = *_str_assetname;
	char *data;
	readAsset(assetname,&data);
	LOGI("Loaded string asset '%s'",assetname);
	args.GetReturnValue().Set(v8::String::NewFromUtf8(args.GetIsolate(),
		data));
}

// void execScript(String source)
void __utils_execScript(const v8::FunctionCallbackInfo<v8::Value>& args) {
	String::Utf8Value _str_source(args[0]->ToString(args.GetIsolate()));
	char *source = *_str_source;
	char *ret = js->run_javascript(source);
	LOGI("Executed JS");
} */


// localStorage

/* void __localStorage_getItem(const v8::FunctionCallbackInfo<v8::Value>& args) {
	String::Utf8Value _str_key(args[0]->ToString(args.GetIsolate()));
	const char *key = *_str_key;

	jmethodID mid = jnienv->GetStaticMethodID(utilsClass, "storeGetString",
		"(Ljava/lang/String;)Ljava/lang/String;");
	jstring jnikey = jnienv->NewStringUTF(key);
	jstring jniret = (jstring)
		jnienv->CallStaticObjectMethod(utilsClass,mid, jnikey);
	jnienv->DeleteLocalRef(jnikey);
	if (jniret==NULL) return; // undefined
	const char *ret = jnienv->GetStringUTFChars(jniret, 0);
	args.GetReturnValue().Set(v8::String::NewFromUtf8(args.GetIsolate(), ret));
	jnienv->ReleaseStringUTFChars(jniret, ret);
	// not sure if it's necessary
	jnienv->DeleteLocalRef(jniret);
}

void __localStorage_setItem(const v8::FunctionCallbackInfo<v8::Value>& args) {
	String::Utf8Value _str_key(args[0]->ToString(args.GetIsolate()));
	const char *key = *_str_key;
	String::Utf8Value _str_val(args[1]->ToString(args.GetIsolate()));
	const char *val = *_str_val;

	jmethodID mid = jnienv->GetStaticMethodID(utilsClass, "storeSetString",
		"(Ljava/lang/String;Ljava/lang/String;)V");
	jstring jnikey = jnienv->NewStringUTF(key);
	jstring jnival = jnienv->NewStringUTF(val);
	jnienv->CallStaticVoidMethod(utilsClass,mid, jnikey,jnival);
	jnienv->DeleteLocalRef(jnikey);
	jnienv->DeleteLocalRef(jnival);
}

void __localStorage_removeItem(const v8::FunctionCallbackInfo<v8::Value>& args){
	String::Utf8Value _str_key(args[0]->ToString(args.GetIsolate()));
	const char *key = *_str_key;

	jmethodID mid = jnienv->GetStaticMethodID(utilsClass, "storeRemove",
		"(Ljava/lang/String;)V");
	jstring jnikey = jnienv->NewStringUTF(key);
	jnienv->CallStaticVoidMethod(utilsClass,mid, jnikey);
	jnienv->DeleteLocalRef(jnikey);
} */

// gl

// internal functions used by glbinding


/*
// #define UNIFORMINT   0
// #define UNIFORMFLOAT 1
// #define UNIFORMMATRIXFLOAT 2
// vecsize: 1,2,3,4 (for matrices: 2,3,4)
// type: 0 = integer  1 = float  2 = float matrix
// transpose: only relevant for matrices
// uniform:
// args[0]: location
// args[1]: data array (floats or ints)
// uniformmatrix:
// args[0]: location
// args[1]: transpose
// args[2]: data array (floats)
void __uniformv(const v8::FunctionCallbackInfo<v8::Value>& args,int vecsize,
int type) {
	HandleScope handle_scope(service->GetIsolate());
	GLint location = (unsigned int)args[0]->IntegerValue();
	GLboolean transpose=false;
	int dataidx = 1;
	if (type==UNIFORMMATRIXFLOAT) {
		transpose = args[1]->BooleanValue();
		dataidx = 2;
	}
	GLsizei count;
	int32_t *data;
	//https://github.com/inh3/node-threads/blob/master/src/node-threads/web-worker.cc
	if (args[dataidx]->IsArrayBufferView() || args[dataidx]->IsArrayBuffer()) {
		// typed array
		v8::Handle<v8::ArrayBufferView> bufview_data = Handle<ArrayBufferView>::Cast(args[dataidx]);
		v8::Handle<v8::ArrayBuffer> buf_data = bufview_data->Buffer();
		v8::ArrayBuffer::Contents con_data=buf_data->GetContents();
		count = con_data.ByteLength() / 4; // should always be multiple of 4
		data = (int32_t *)con_data.Data();
	} else if (args[dataidx]->IsArray()) {
		// regular array
		v8::Handle<v8::Array> array_data = Handle<Array>::Cast(args[dataidx]);
		count = array_data->Length();
		data = (int32_t *)malloc(count * 4); // float and int32 both 4 bytes
		if (type==UNIFORMINT) {
			int32_t *data_p = data;
			for (int i=0; i<count; i++) {
				v8::Handle<v8::Value> value = array_data->Get(i);
				*data_p = value->Int32Value();
				data_p++;
			}
		} else { // UNIFORMFLOAT, UNIFORMMATRIXFLOAT
			GLfloat *data_p = (GLfloat *)data;
			for (int i=0; i<count; i++) {
				v8::Handle<v8::Value> value = array_data->Get(i);
				*data_p = (GLfloat)value->NumberValue();
				//LOGI("### GOT VAL: %f",*data_p);
				data_p++;
			}
		}
	}
	//LOGI("#### Entered Uniformv %d,%d /%d,%d",vecsize, type, location, count);
	//GLfloat *dataf = (GLfloat *)data;
	//LOGI("### data val: %f %f %f %f",dataf[0],dataf[1],dataf[2],dataf[3]);
	switch (type + 3*vecsize) {
		case UNIFORMINT+1*3:
			glUniform1iv(location, count, data);
		break;
		case UNIFORMINT+2*3:
			glUniform2iv(location, count/2, data);
		break;
		case UNIFORMINT+3*3:
			glUniform3iv(location, count/3, data);
		break;
		case UNIFORMINT+4*3:
			glUniform4iv(location, count/4, data);
		break;
		case UNIFORMFLOAT+1*3:
			glUniform1fv(location, count, (const GLfloat *)data);
		break;
		case UNIFORMFLOAT+2*3:
			glUniform2fv(location, count/2, (const GLfloat *)data);
		break;
		case UNIFORMFLOAT+3*3:
			glUniform3fv(location, count/3, (const GLfloat *)data);
		break;
		case UNIFORMFLOAT+4*3:
			glUniform4fv(location, count/4, (const GLfloat *)data);
			//LOGI("### data val: %f %f %f %f",dataf[0],dataf[1],dataf[2],dataf[3]);
		break;
		case UNIFORMMATRIXFLOAT+2*3:
			glUniformMatrix2fv(location, count/(2*2), transpose,
				(const GLfloat *)data);
		break;
		case UNIFORMMATRIXFLOAT+3*3:
			glUniformMatrix3fv(location, count/(3*3), transpose,
				(const GLfloat *)data);
		break;
		case UNIFORMMATRIXFLOAT+4*3:
			glUniformMatrix4fv(location, count/(4*4), transpose,
				(const GLfloat *)data);
		break;
		default:
			LOGI("uniformv error: illegal type combination %d,%d",type,vecsize);
	}
}

// read generated bindings

#include "gluegen/glbindings.h"

// manually coded functions

void __createBuffer(const v8::FunctionCallbackInfo<v8::Value>& args) {
	GLuint buffers[1];
	glGenBuffers(1,buffers);
	args.GetReturnValue().Set(v8::Integer::New(args.GetIsolate(), buffers[0]));
}

void __createRenderbuffer(const v8::FunctionCallbackInfo<v8::Value>& args) {
	GLuint buffers[1];
	glGenFramebuffers(1,buffers);
	args.GetReturnValue().Set(v8::Integer::New(args.GetIsolate(), buffers[0]));
}

void __createFramebuffer(const v8::FunctionCallbackInfo<v8::Value>& args) {
	GLuint buffers[1];
	glGenFramebuffers(1,buffers);
	args.GetReturnValue().Set(v8::Integer::New(args.GetIsolate(), buffers[0]));
}

void __createTexture(const v8::FunctionCallbackInfo<v8::Value>& args) {
	GLuint textures[1];
	glGenTextures(1,textures);
	args.GetReturnValue().Set(v8::Integer::New(args.GetIsolate(), textures[0]));
}



void __getProgramParameter(const v8::FunctionCallbackInfo<v8::Value>& args) {
	int param[1];
	GLuint program = (GLuint)args[0]->IntegerValue();
	GLenum pname = (GLenum)args[1]->IntegerValue();
	glGetShaderiv(program,pname,param);
	args.GetReturnValue().Set(v8::Integer::New(args.GetIsolate(), param[0]));
}

void __getShaderParameter(const v8::FunctionCallbackInfo<v8::Value>& args) {
	int param[1];
	GLuint shader = (GLuint)args[0]->IntegerValue();
	GLenum pname = (GLenum)args[1]->IntegerValue();
	glGetShaderiv(shader,pname,param);
	args.GetReturnValue().Set(v8::Integer::New(args.GetIsolate(), param[0]));
}

void __getProgramInfoLog(const v8::FunctionCallbackInfo<v8::Value>& args) {
	GLuint program = (GLuint)args[0]->IntegerValue();
	int length[1];
	GLchar infolog[256];
	// we can use glGetProgramiv to get the precise length of the string
	// beforehand
	glGetShaderInfoLog(program,256,length,infolog);
	args.GetReturnValue().Set(v8::String::NewFromUtf8(args.GetIsolate(),
		infolog));
}

void __getShaderInfoLog(const v8::FunctionCallbackInfo<v8::Value>& args) {
	GLuint shader = (GLuint)args[0]->IntegerValue();
	int length[1];
	GLchar infolog[256];
	// we can use glGetShaderiv to get the precise length of the string
	// beforehand
	glGetShaderInfoLog(shader,256,length,infolog);
	args.GetReturnValue().Set(v8::String::NewFromUtf8(args.GetIsolate(),
		infolog));
}

// Trilingual binding JS -> C++ -> Java.  
//jni docs:
//http://www3.ntu.edu.sg/home/ehchua/programming/java/JavaNativeInterface.html

// We use Java's texImage2D because it parses pngs and jpgs properly.
// No NDK equivalent exists.
// We use GLUtils, which provides (amongst others):
//   texImage2D(target,level,image,border);
// We use defaults for format, internalformat, type.
void __texImage2D(const v8::FunctionCallbackInfo<v8::Value>& args) {
	// call method:
	// (get signature with javap -s [classfile])
	// static void Test()
	//jmethodID mid = jnienv->GetStaticMethodID(utilsClass, "Test", "()V");
	//jnienv->CallStaticVoidMethod(utilsClass,mid);

	// call method:
	// static void texImage2D(int target,int level,byte [] data,int border)
	jmethodID mid = jnienv->GetStaticMethodID(utilsClass, "texImage2D",
		"(II[BI)[I");
	// get js parameters
	int target = (int)args[0]->Int32Value();
	int level = (int)args[1]->Int32Value();
	if (args.Length()>=8) {
		// long version: texImage2D(GLenum target, GLint level, GLenum internalformat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, ArrayBufferView? pixels)
		GLenum internalformat = (int)args[2]->Int32Value();
		GLsizei width = (int)args[3]->Int32Value();
		GLsizei height = (int)args[4]->Int32Value();
		GLint border = (int)args[5]->Int32Value();
		GLenum format = (int)args[6]->Int32Value();
		GLenum type = (int)args[7]->Int32Value();
		// data may be null in the long version, in which case an empty image
		// is created
		GLvoid *pixels;
		if (args.Length()>8 && !(args[8]->IsNull())) {
			// TODO get pixels from ArrayBufferView
		} else {
			// clear buffer. WebGL apparently expects the render texture to be
			// empty, while Opengl will have garbage in the buffer when not
			// explicity cleared
			pixels = (void *)calloc(4,width*height);
		}
		glTexImage2D(target,level,internalformat,width,height,border,format,
			type,pixels);
	}
	// short version:texImage2D(target,level,format,internalformat,type,image);
	// Not sure if border parameter is supported
	// and where it should go.
	String::Utf8Value _str_assetname(args[5]->ToString(args.GetIsolate()));
	const char *assetname = *_str_assetname;
	// read asset.  XXX move this to Java
	char *imagedata;
	int imagedatalen = readAsset(assetname,&imagedata);
	// convert parameters to java
    jbyteArray jBuff = jnienv->NewByteArray(imagedatalen);
    jnienv->SetByteArrayRegion(jBuff, 0, imagedatalen, (jbyte*) imagedata);
	// docs for byte array functions:
	//jbyteArray    NewByteArray(JNIEnv *env, jsize length);
	//void      ReleaseByteArrayElements(JNIEnv *env, jbyteArray array, jbyte *elems, jint mode);
	//void GetByteArrayRegion(JNIEnv *env, jbyteArray array, jsize start, jsize len, jbyte *buf);
	//void SetByteArrayRegion(JNIEnv *env, jbyteArray array, jsize start, jsize len, jbyte *buf);
	jintArray retval_j = (jintArray) jnienv->CallStaticObjectMethod(
		utilsClass,mid, (jint)target, (jint)level, jBuff, (jint)0);
	//http://www.rgagnon.com/javadetails/java-0287.html
	jint *retval = jnienv->GetIntArrayElements(retval_j, 0);
	int retwidth = retval[0];
	int retheight = retval[1];
	jnienv->ReleaseIntArrayElements(retval_j, retval, 0);//XXX use JNI_ABORT
	jnienv->DeleteLocalRef(retval_j);
	jnienv->DeleteLocalRef(jBuff);
	// XXX return value no longer used!
	// return width, height
	// from: https://v8.googlecode.com/svn/trunk/test/cctest/test-api.cc
	v8::Handle<v8::Array> jsretval =
		v8::Array::New(args.GetIsolate(), 2);
	jsretval->Set(0, v8::Integer::New(args.GetIsolate(), retwidth));
	jsretval->Set(1, v8::Integer::New(args.GetIsolate(), retheight));
	args.GetReturnValue().Set(jsretval);
}


void __getImageDimensions(const v8::FunctionCallbackInfo<v8::Value>& args) {
	String::Utf8Value _str_assetname(args[0]->ToString(args.GetIsolate()));
	const char *assetname = *_str_assetname;
	jstring jniassetname = jnienv->NewStringUTF(assetname);
	jmethodID mid = jnienv->GetStaticMethodID(utilsClass, "getImageDimensions",
		"(Ljava/lang/String;)[I");
	jintArray retval_j = (jintArray) jnienv->CallStaticObjectMethod(
		utilsClass, mid, jniassetname);
	//http://www.rgagnon.com/javadetails/java-0287.html
	jint *retval = jnienv->GetIntArrayElements(retval_j, 0);
	int retwidth = retval[0];
	int retheight = retval[1];
	jnienv->ReleaseIntArrayElements(retval_j, retval, 0);//XXX use JNI_ABORT
	jnienv->DeleteLocalRef(retval_j);
	jnienv->DeleteLocalRef(jniassetname);
	// return width, height
	// from: https://v8.googlecode.com/svn/trunk/test/cctest/test-api.cc
	v8::Handle<v8::Array> jsretval =
		v8::Array::New(args.GetIsolate(), 2);
	jsretval->Set(0, v8::Integer::New(args.GetIsolate(), retwidth));
	jsretval->Set(1, v8::Integer::New(args.GetIsolate(), retheight));
	args.GetReturnValue().Set(jsretval);
} */

// NOTE: must already be in context
void callFunction(const char *funcname, const int argc, Local<Value> argv[]) {
  // init
  Isolate *isolate = service->GetIsolate();
  Local<Context> localContext = service->GetContext();
  Local<Object> global = localContext->Global();

  // get function
  Local<String> jsfunc_name = String::NewFromUtf8(isolate,funcname);
  Local<Value> jsfunc_val = global->Get(jsfunc_name);
  if (!jsfunc_val->IsFunction()) return;
  Local<Function> jsfunc = Local<Function>::Cast(jsfunc_val);

  // call function, 'this' points to global object
  Nan::TryCatch try_catch;
  Local<Value> result = jsfunc->Call(global, argc, argv);

  if (result.IsEmpty()) {
    // String::Utf8Value error(try_catch.Exception());
    // String::Utf8Value stacktrace(try_catch.StackTrace());
    //LOGI("Error calling %s: %s:\n%s",funcname,*error,*stacktrace);
  } else {
    //LOGI("%s called",funcname);
  }
}


// -----------------------------------------------
// JS handling
// -----------------------------------------------





/* // output must be freed using free()
long readAsset(const char *filename, char **output) {
	LOGI("readAsset %s",filename);
	jmethodID mid = jnienv->GetStaticMethodID(utilsClass, "readAsset",
		"(Ljava/lang/String;)[B");
	jstring jAssetName = jnienv->NewStringUTF(filename);
	jbyteArray retval_j = (jbyteArray)
		jnienv->CallStaticObjectMethod(utilsClass, mid, jAssetName);
	jbyte* retval = jnienv->GetByteArrayElements(retval_j, 0);
	long retval_len = jnienv->GetArrayLength(retval_j);
	// allocate one zero guard byte to ensure strings are terminated
    char* buffer = (char*) calloc (sizeof(char)*(retval_len+1),1);
	memcpy(buffer,retval,retval_len);
	jnienv->ReleaseByteArrayElements(retval_j, retval, JNI_ABORT);
	jnienv->DeleteLocalRef(jAssetName);
	jnienv->DeleteLocalRef(retval_j);
	*output = buffer;
	return retval_len;
	
}

// jni interface


jint JNI_OnLoad(JavaVM* vm, void* reserved) {
	JNIEnv* env;
	if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) != JNI_OK) {
		return -1;
	}

	// Get jclass with env->FindClass.
	// Register methods with env->RegisterNatives.

	return JNI_VERSION_1_6;
} */

/* void redirectStdioToLog() {
  setvbuf(stdout, 0, _IOLBF, 0);
  setvbuf(stderr, 0, _IONBF, 0);

  int pfd[2];
  pipe(pfd);
  dup2(pfd[1], 1);
  dup2(pfd[1], 2);

  std::thread([](int pfd0) {
    char buf[1024];
    std::size_t nBytes = 0;
    while ((nBytes = read(pfd0, buf, sizeof buf - 1)) > 0) {
      if (buf[nBytes - 1] == '\n') --nBytes;
      buf[nBytes] = 0;
      NSLog(@"%s", buf);
    }
  }, pfd[0]).detach();
} */


#ifdef __cplusplus
extern "C" {
#endif
/* This does double duty as both the init and displaychanged function.
 * Signature: (II)V
 */
void NodeService_onResize
(int width, int height) {
	// LOGI("JNI onResize %d %d", width, height);

  queueServiceUiThread([&]() {
    HandleScope handle_scope(service->GetIsolate());

    Handle<Number> js_width = v8::Integer::New(service->GetIsolate(), width);
    Handle<Number> js_height = v8::Integer::New(service->GetIsolate(), height);

    Local<Value> argv[] = {js_width, js_height};
    callFunction("onResize", sizeof(argv)/sizeof(argv[0]), argv);
  });
}


void NodeService_onNewFrame
(float headViewMatrixElements[], float headQuaternionElements[], float centerArrayElements[]) {
  queueServiceUiThread([&]() {
    HandleScope handle_scope(service->GetIsolate());

    Local<Float32Array> headMatrixFloat32Array = Float32Array::New(ArrayBuffer::New(service->GetIsolate(), 16 * 4), 0, 16);
    for (int i = 0; i < 16; i++) {
      headMatrixFloat32Array->Set(i, Number::New(service->GetIsolate(), headViewMatrixElements[i]));
    }
    Local<Float32Array> headQuaternionFloat32Array = Float32Array::New(ArrayBuffer::New(service->GetIsolate(), 4 * 4), 0, 4);
    for (int i = 0; i < 4; i++) {
      headQuaternionFloat32Array->Set(i, Number::New(service->GetIsolate(), headQuaternionElements[i]));
    }
    Local<Float32Array> centerFloat32Array = Float32Array::New(ArrayBuffer::New(service->GetIsolate(), 3 * 4), 0, 3);
    for (int i = 0; i < 3; i++) {
      centerFloat32Array->Set(i, Number::New(service->GetIsolate(), centerArrayElements[i]));
    }
    Local<Value> argv[] = {headMatrixFloat32Array, headQuaternionFloat32Array, centerFloat32Array};
    callFunction("onNewFrame", sizeof(argv)/sizeof(argv[0]), argv);
  });
}


void NodeService_onDrawEye
(float eyeViewMatrixElements[], float eyePerspectiveMatrixElements[]) {
  queueServiceUiThread([&]() {
    HandleScope handle_scope(service->GetIsolate());

    Local<Float32Array> eyeViewMatrixFloat32Array = Float32Array::New(ArrayBuffer::New(service->GetIsolate(), 16 * 4), 0, 16);
    for (int i = 0; i < 16; i++) {
      eyeViewMatrixFloat32Array->Set(i, Number::New(service->GetIsolate(), eyeViewMatrixElements[i]));
    }
    Local<Float32Array> eyePerspectiveMatrixFloat32Array = Float32Array::New(ArrayBuffer::New(service->GetIsolate(), 4 * 4), 0, 4);
    for (int i = 0; i < 4; i++) {
      eyePerspectiveMatrixFloat32Array->Set(i, Number::New(service->GetIsolate(), eyePerspectiveMatrixElements[i]));
    }
    Local<Value> argv[] = {eyeViewMatrixFloat32Array, eyePerspectiveMatrixFloat32Array};
    callFunction("onDrawEye", sizeof(argv)/sizeof(argv[0]), argv);
  });
}

void NodeService_onDrawFrame
(float viewMatrixElements[], float projectionMatrixElements[], float centerArrayElements[]) {
  queueServiceUiThread([&]() {
    HandleScope handle_scope(service->GetIsolate());

    Local<Float32Array> viewFloat32Array = Float32Array::New(ArrayBuffer::New(service->GetIsolate(), 16 * 4), 0, 16);
    for (int i = 0; i < 16; i++) {
      viewFloat32Array->Set(i, Number::New(service->GetIsolate(), viewMatrixElements[i]));
    }
    Local<Float32Array> projectionFloat32Array = Float32Array::New(ArrayBuffer::New(service->GetIsolate(), 16 * 4), 0, 16);
    for (int i = 0; i < 16; i++) {
      projectionFloat32Array->Set(i, Number::New(service->GetIsolate(), projectionMatrixElements[i]));
    }
    Local<Float32Array> centerFloat32Array = Float32Array::New(ArrayBuffer::New(service->GetIsolate(), 3 * 4), 0, 3);
    for (int i = 0; i < 3; i++) {
      centerFloat32Array->Set(i, Number::New(service->GetIsolate(), centerArrayElements[i]));
    }
    Local<Value> argv[] = {viewFloat32Array, projectionFloat32Array, centerFloat32Array};
    callFunction("onDrawFrame", sizeof(argv)/sizeof(argv[0]), argv);
  });
}

std::function<void (node::NodeService *nodeService)> nodeServiceInitFunction;
void NodeService_start
(const char *binPathString, const char *jsPathString, const char *libPathString, const char *dataPathString, const char *urlString, const char *vrModeString, int vrTexture, int vrTexture2) {
  // redirectStdioToLog();

  canvas::Quartz2DContextFactory *canvasContextFactory = new canvas::Quartz2DContextFactory(1);
  CanvasRenderingContext2D::InitalizeStatic(canvasContextFactory);

  std::stringstream vrTextureStringStream;
  vrTextureStringStream << vrTexture;
  const char *vrTextureString = vrTextureStringStream.str().c_str();

  std::stringstream vrTexture2StringStream;
  vrTexture2StringStream << vrTexture2;
  const char *vrTexture2String = vrTexture2StringStream.str().c_str();
  char argsString[4096];
  int i = 0;

  char *binPathArg = argsString + i;
  strncpy(binPathArg, binPathString, sizeof(argsString) - i);
  i += strlen(binPathString) + 1;

  char *jsPathArg = argsString + i;
  strncpy(jsPathArg, jsPathString, sizeof(argsString) - i);
  i += strlen(jsPathString) + 1;

  char *libPathArg = argsString + i;
  strncpy(libPathArg, libPathString, sizeof(argsString) - i);
  i += strlen(libPathString) + 1;
  
  char *dataPathArg = argsString + i;
  strncpy(dataPathArg, dataPathString, sizeof(argsString) - i);
  i += strlen(dataPathString) + 1;

  char *urlArg = argsString + i;
  strncpy(urlArg, urlString, sizeof(argsString) - i);
  i += strlen(urlString) + 1;

  char *vrModeArg = argsString + i;
  strncpy(vrModeArg, vrModeString, sizeof(argsString) - i);
  i += strlen(vrModeString) + 1;

  char *vrTextureArg = argsString + i;
  strncpy(vrTextureArg, vrTextureString, sizeof(argsString) - i);
  i += strlen(vrTextureString) + 1;

  char *vrTexture2Arg = argsString + i;
  strncpy(vrTexture2Arg, vrTexture2String, sizeof(argsString) - i);
  i += strlen(vrTexture2String) + 1;

  char *args[] = {binPathArg, jsPathArg, libPathArg, dataPathArg, urlArg, vrModeArg, vrTextureArg, vrTexture2Arg};
  // node::Start(3, args);
  // service = new node::NodeService(3, args);

  nodeServiceInitFunction = [&](node::NodeService *service) {
    Isolate *isolate = service->GetIsolate();
    Local<Object> global = service->GetContext()->Global();

    Local<Value> gl = makeGl();
    global->Set(v8::String::NewFromUtf8(isolate, "nativeGl"), gl);

    Local<Value> image = makeImage();
    global->Set(v8::String::NewFromUtf8(isolate, "nativeImage"), image);

    Local<Value> imageData = makeImageData();
    global->Set(v8::String::NewFromUtf8(isolate, "nativeImageData"), imageData);

    Local<Value> imageBitmap = makeImageBitmap();
    global->Set(v8::String::NewFromUtf8(isolate, "nativeImageBitmap"), imageBitmap);

    Local<Value> canvas = makeCanvasRenderingContext2D(imageData);
    global->Set(v8::String::NewFromUtf8(isolate, "nativeCanvasRenderingContext2D"), canvas);

    Local<Value> path2d = makePath2D();
    global->Set(v8::String::NewFromUtf8(isolate, "nativePath2D"), path2d);
  };
  service = new node::NodeService(sizeof(args)/sizeof(args[0]), args, [](node::NodeService *service) {
    nodeServiceInitFunction(service);
  });

  std::function<void (node::NodeService *nodeService)> nopFunction;
  nodeServiceInitFunction = nopFunction;
}

void NodeService_tick
(int timeout) {
  service->Tick(timeout);
}

#ifdef __cplusplus
}
#endif


//END_INCLUDE(all)
