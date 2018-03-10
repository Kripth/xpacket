module packetmaker.buffer;

import core.exception : onOutOfMemoryError;
import core.stdc.stdlib : malloc, realloc, free;

import std.bitmanip : nativeToBigEndian, nativeToLittleEndian, bigEndianToNative, littleEndianToNative;
import std.string : toUpper;
import std.system : Endian;
import std.traits : isIntegral, isFloatingPoint, isSomeChar, Unqual;

import packetmaker.varint : isVar, Var;

private enum __byte_types = ["bool", "byte", "ubyte", "char"];

private enum __numeric_types = ["short", "ushort", "int", "uint", "long", "ulong", "float", "double"];

private enum __var_types = ["short", "ushort", "int", "uint", "long", "ulong"];

class InputBuffer {

	private immutable size_t chunk;

	private ubyte[] _data;
	private size_t _index = 0;

	this(size_t chunk=256) nothrow @trusted @nogc {
		assert(chunk > 0);
		this.chunk = chunk;
		auto ptr = malloc(chunk);
		if(ptr is null) onOutOfMemoryError();
		_data = cast(ubyte[])ptr[0..chunk];
	}
	
	@property ubyte[] data() pure nothrow @safe @nogc {
		return _data[0.._index];
	}

	~this() {
		free(_data.ptr);
	}

	void reserve(size_t length) nothrow @trusted @nogc {
		length += _data.length;
		auto ptr = realloc(_data.ptr, length);
		if(ptr is null) onOutOfMemoryError();
		_data = cast(ubyte[])ptr[0..length];
	}

	void reset() {
		_index = 0;
	}

	void writeBytes(ubyte[] data...) nothrow @trusted @nogc {
		if(_data.length < _index + data.length) {
			this.reserve((data.length + this.chunk - 1) / this.chunk * this.chunk);
		}
		_data[_index.._index+data.length] = data;
		_index += data.length;
	}

	mixin({

		string ret;
		// byte types
		foreach(type ; __byte_types) {
			ret ~= "void write" ~ fname(type) ~ "(" ~ type ~ " value) nothrow @safe @nogc {this.writeBytes(value);}";
		}
		// numeric types
		foreach(type ; __numeric_types) {
			foreach(endian ; ["BigEndian", "LittleEndian"]) {
				ret ~= "void write" ~ endian ~ fname(type) ~ "(" ~ type ~ " value) nothrow @safe @nogc {";
				ret ~= "this.writeBytes(nativeTo" ~ endian ~ "(value));";
				ret ~= "}";
			}
		}
		// varints
		foreach(type ; __var_types) {
			ret ~= "void writeVar" ~ fname(type) ~ "(" ~ type ~ " value) nothrow @safe @nogc {";
			ret ~= "Var!" ~ type ~ ".encode(this, value);";
			ret ~= "}";
		}
		return ret;

	}());

	// generic write template

	template write(Endian endianness, T) if(is(T : bool) || isIntegral!T || isFloatingPoint!T) {

		static if(T.sizeof == 1) mixin("alias write = write" ~ fname(Unqual!T.stringof) ~ ";");
		else mixin("alias write = write" ~ endianness.str ~ fname(Unqual!T.stringof) ~ ";");

	}

	template write(Endian endianness, T) if(isSomeChar!T) {

		alias write = write!(endianness, ToInteger!T);

	}

	template write(T) if(isVar!T) {

		alias write = writeVar!(T.Base);

	}

	template writeVar(T) if(isIntegral!T && T.sizeof > 1) {

		mixin("alias writeVar = writeVar" ~ fname(T.stringof) ~ ";");

	}

}

class OutputBuffer {

	private ubyte[] _data;
	private size_t _index;

	this(ubyte[] data=[]) pure nothrow @safe @nogc {
		_data = data;
	}

	@property ubyte[] data() pure nothrow @safe @nogc {
		return _data;
	}

	@property ubyte[] data(ubyte[] data) pure nothrow @safe @nogc {
		_index = 0;
		return _data = data;
	}

	@property size_t index() pure nothrow @safe @nogc {
		return _index;
	}
	
	ubyte[] readBytes(size_t length) pure @safe @nogc {
		//if(_index + length > this.data.length) throw new BufferTerminatedException();
		ubyte[] ret = _data[_index.._index+length];
		_index += length;
		return ret;
	}

	mixin({

		import std.string : toLower;

		string ret;
		// basic types
		foreach(type ; __byte_types) {
			ret ~= type ~ " read" ~ fname(type) ~ "() pure @safe @nogc {";
			ret ~= "return cast(" ~ type ~ ")this.readBytes(1)[0];";
			ret ~= "}";
		}
		// numeric types
		foreach(type ; __numeric_types) {
			foreach(endian ; ["BigEndian", "LittleEndian"]) {
				ret ~= type ~ " read" ~ endian ~ fname(type) ~ "() pure @safe @nogc {";
				ret ~= "ubyte[" ~ type ~ ".sizeof] bytes = this.readBytes(" ~ type ~ ".sizeof);";
				ret ~= "return " ~ toLower(endian[0..1]) ~ endian[1..$] ~ "ToNative!" ~ type ~ "(bytes);";
				ret ~= "}";
			}
		}
		// varints
		foreach(type ; __var_types) {
			ret ~= type ~ " readVar" ~ fname(type) ~ "() pure @safe @nogc {";
			ret ~= "return Var!" ~ type ~ ".decode(this);";
			ret ~= "}";
		}
		return ret;

	}());

	// generic read template

	template read(Endian endianness, T) if(is(T : bool) || isIntegral!T || isFloatingPoint!T) {
		
		static if(T.sizeof == 1) mixin("alias read = read" ~ fname(Unqual!T.stringof) ~ ";");
		else mixin("alias read = read" ~ endianness.str ~ fname(Unqual!T.stringof) ~ ";");
		
	}

	template read(Endian endianness, T) if(isSomeChar!T) {

		alias read = read!(endianness, ToInteger!T);

	}

	template read(T) if(isVar!T) {

		alias read = readVar!(T.Base);

	}
	
	template readVar(T) if(isIntegral!T && T.sizeof > 1) {

		mixin("alias readVar = readVar" ~ fname(T.stringof) ~ ";");
		
	}

}

class BufferTerminatedException : Exception {

	this(string file=__FILE__, size_t line=__LINE__) pure nothrow @safe @nogc {
		super("There is no more data to read", file, line);
	}

}

unittest {

	// write
	{

		InputBuffer buffer = new InputBuffer();

		buffer.writeBool(true);
		buffer.writeByte(1);
		buffer.writeUnsignedByte(255);
		buffer.writeBigEndianShort(255);
		assert(buffer.data == [1, 1, 255, 0, 255]);

		buffer.reset();

		buffer.writeBigEndianInt(39);
		buffer.writeLittleEndianShort(12);
		assert(buffer.data == [0, 0, 0, 39, 12, 0]);

		// realloc
		buffer = new InputBuffer(4);
		buffer.writeBigEndianInt(12);
		buffer.writeBigEndianShort(0);
		assert(buffer._data.length == 8);
		buffer.writeByte(1);
		buffer.writeBigEndianLong(1);
		assert(buffer.data == [0, 0, 0, 12, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 1]);

		// unsigned varint
		buffer.reset();
		buffer.writeVarUnsignedInt(1);
		buffer.writeVarUnsignedInt(128);
		buffer.writeVarUnsignedShort(256);
		assert(buffer.data == [1, 128, 1, 128, 2]);

		// signed varint
		buffer.reset();
		buffer.writeVarInt(0);
		buffer.writeVarInt(1);
		buffer.writeVarInt(-1);
		buffer.writeVarShort(200);
		assert(buffer.data == [0, 2, 1, 144, 3]);

		// modifiers
		buffer.reset();
		const bool bool_ = true;
		immutable uint a = 21;
		buffer.write!(Endian.bigEndian, typeof(bool_))(bool_);
		buffer.write!(Endian.bigEndian, typeof(a))(a);
		assert(buffer.data == [1, 0, 0, 0, 21]);

	}

	// read
	{

		OutputBuffer buffer = new OutputBuffer();

		buffer.data = [1, 0, 12, 66, 0, 0, 0];
		assert(buffer.readBool() == true);
		assert(buffer.readBigEndianShort() == 12);
		assert(buffer.readLittleEndianInt() == 66);
		assert(buffer.data == [1, 0, 12, 66, 0, 0, 0]);
		assert(buffer.index == 7);

		// unsigned varint
		buffer.data = [1, 128, 1, 0, 0, 0, 0, 0];
		assert(buffer.readVarUnsignedInt() == 1);
		assert(buffer.readVarUnsignedLong() == 128);

		// signed varint
		buffer.data = [0, 2, 1, 144, 3];
		assert(buffer.readVarInt() == 0);
		assert(buffer.readVarInt() == 1);
		assert(buffer.readVarLong() == -1);
		assert(buffer.readVarShort() == 200);

	}

}

// util

string fname(string type) {
	if(type[0] == 'u') return "Unsigned" ~ fname(type[1..$]);
	else return toUpper(type[0..1]) ~ type[1..$];
}

string str(Endian endianness) {
	return endianness == Endian.bigEndian ? "BigEndian" : "LittleEndian";
}

template ToInteger(T) if(isSomeChar!T) {

	static if(T.sizeof == 1) alias ToInteger = ubyte;
	else static if(T.sizeof == 2) alias ToInteger = ushort;
	else alias ToInteger = uint;

}
