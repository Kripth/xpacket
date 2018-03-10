module packetmaker.maker;

import std.string : capitalize;
import std.system : Endian;
import std.traits;

import packetmaker.buffer : InputBuffer, OutputBuffer;
import packetmaker.packet : EndianType;
import packetmaker.varint : isVar;

// attributes

enum Exclude;

enum EncodeOnly;

enum DecodeOnly;

struct Condition { string condition; }

enum Var;

enum BigEndian;

enum LittleEndian;

enum Bytes;

struct LengthImpl { string type; EndianType endianness; }

LengthImpl EndianLength(T)(Endian endianness) if(isIntegral!T) { return LengthImpl(T.stringof, cast(EndianType)endianness); }

template Length(T) if(isIntegral!T) { enum Length = LengthImpl(T.stringof, EndianType.inherit); }

template Length(T) if(isVar!T) { enum Length = LengthImpl(T.Base.stringof, EndianType.var); }

// maker

mixin template MakeImpl(bool nested) /*if(is(typeof(this) : Packet))*/ {

	import std.system : Endian;

	import packetmaker.buffer : InputBuffer, OutputBuffer;
	import packetmaker.maker : write, writeImpl, writeMembers, read, readImpl, readMembers;
	import packetmaker.packet : Packet, EndianType;

	//static if(nested) static assert(is(__traits(parent, typeof(this)) : PacketBase));

	//TODO create constructor

	private enum bool __is_packet = is(typeof(this) : Packet) && is(__packet);

	static assert(__is_packet, "Make must be used inside a Packet");
	
	static if(__traits(hasMember, typeof(this), "ID")) {

		private enum __inherited_id;

		override void encodeId(InputBuffer buffer) {
			writeImpl!(__id_endianness, __Id)(buffer, ID);
		}

		override void decodeId(OutputBuffer buffer) {
			readImpl!(__id_endianness, __Id)(buffer);
		}

	} else static if(nested && __traits(hasMember, __traits(parent, typeof(this)), "__inherited_id")) {

		private enum __inherited_id;

		override void encodeId(InputBuffer buffer) {
			__traits(parent, typeof(this)).encodeId(buffer);
		}

		override void decodeId(OutputBuffer buffer) {
			__traits(parent, typeof(this)).decodeId(buffer);
		}

	}

	override void encodeBody(InputBuffer buffer) {
		static if(nested) {
			__traits(parent, typeof(this)).encodeBody(buffer);
		}
		super.encodeBody(buffer);
		writeMembers!(cast(EndianType)__endianness, __Length, __length_endianness)(buffer, this);
	}

	override void decodeBody(OutputBuffer buffer) {
		super.decodeBody(buffer);
		readMembers!(cast(EndianType)__endianness, __Length, __length_endianness)(buffer, this);
	}
	
}

mixin template Make() { import packetmaker.maker : MakeImpl; mixin MakeImpl!(false); }

alias write(EndianType endianness, OL, EndianType ole, T) = write!(endianness, OL, ole, OL, ole, T);

void write(EndianType endianness, OL, EndianType ole, CL, EndianType cle, T)(InputBuffer buffer, T data) {
	static if(isArray!T) {
		static if(isDynamicArray!T) writeLength!(cle, CL)(buffer, data.length);
		static if(ForeachType!T.sizeof == 1 && isBuiltinType!(ForeachType!T)) {
			buffer.writeBytes(cast(ubyte[])data);
		} else {
			foreach(element ; data) {
				write!(endianness, OL, ole, typeof(element))(buffer, element);
			}
		}
	} else static if(isAssociativeArray!T) {
		writeLength!(cle, CL)(buffer, data.length);
		foreach(key, value; data) {
			write!(endianness, OL, ole, typeof(key))(buffer, key);
			write!(endianness, OL, ole, typeof(value))(buffer, value);
		}
	} else static if(is(T == class) || is(T == struct)) {
		static if(__traits(hasMember, T, "encodeBody")) {
			data.encodeBody(buffer);
		} else {
			writeMembers!(endianness, OL, ole)(buffer, data);
		}
	} else static if(is(T : bool) || isIntegral!T || isFloatingPoint!T || isSomeChar!T) {
		writeImpl!endianness(buffer, data);
	} else {
		static assert(0, "Cannot encode " ~ T.stringof);
	}
}

void writeLength(EndianType endianness, L)(InputBuffer buffer, size_t length) {
	static if(L.sizeof < size_t.sizeof) writeImpl!(endianness, L)(buffer, cast(L)length);
	else writeImpl!(endianness, L)(buffer, length);
}

void writeImpl(EndianType endianness, T)(InputBuffer buffer, T value) {
	static if(endianness == EndianType.var && isIntegral!T && T.sizeof > 1) buffer.writeVar!T(value);
	else static if(endianness == EndianType.bigEndian) buffer.write!(Endian.bigEndian, T)(value);
	else static if(endianness == EndianType.littleEndian) buffer.write!(Endian.littleEndian, T)(value);
	else static assert(0, "Cannot encode " ~ T.stringof);
}

void writeMembers(EndianType endianness, L, EndianType le, T)(InputBuffer __buffer, T __container) {
	foreach(member ; Members!(T, DecodeOnly)) {
		mixin("alias M = typeof(__container." ~ member ~ ");");
		mixin({

			static if(hasUDA!(__traits(getMember, T, member), LengthImpl)) {
				import std.conv : to;
				auto length = getUDAs!(__traits(getMember, T, member), LengthImpl)[0];
				immutable e = "L, le, " ~ length.type ~ ", " ~ (length.endianness == EndianType.inherit ? "le" : "EndianType." ~ length.endianness.to!string);
			} else {
				immutable e = "L, le, L, le";
			}
			
			static if(hasUDA!(__traits(getMember, T, member), Bytes)) immutable ret = "__buffer.writeBytes(__container." ~ member ~ ");";
			else static if(hasUDA!(__traits(getMember, T, member), Var)) immutable ret = "write!(EndianType.var, " ~ e ~ ", M)(__buffer, __container." ~ member ~ ");";
			else static if(hasUDA!(__traits(getMember, T, member), BigEndian)) immutable ret = "write!(EndianType.bigEndian, " ~ e ~ ", M)(__buffer, __container." ~ member ~ ");";
			else static if(hasUDA!(__traits(getMember, T, member), LittleEndian)) immutable ret = "write!(EndianType.littleEndian, " ~ e ~ ", M)(__buffer, __container." ~ member ~ ");";
			else immutable ret = "write!(endianness, " ~ e ~ ", M)(__buffer, __container." ~ member ~ ");";
			
			static if(!hasUDA!(__traits(getMember, T, member), Condition)) return ret;
			else return "with(__container){if(" ~ getUDAs!(__traits(getMember, T, member), Condition)[0].condition ~ "){" ~ ret ~ "}}";

		}());
	}
}

alias read(EndianType endianness, OL, EndianType ole, T) = read!(endianness, OL, ole, OL, ole, T);

T read(EndianType endianness, OL, EndianType ole, CL, EndianType cle, T)(OutputBuffer buffer) {
	static if(isArray!T) {
		T ret;
		static if(isDynamicArray!T) {
			immutable length = readLength!(cle, CL)(buffer);
			static if(ForeachType!T.sizeof == 1 && isBuiltinType!(ForeachType!T)) {
				ret = cast(T)buffer.readBytes(length);
			} else {
				foreach(size_t i ; 0..length) {
					ret ~= read!(endianness, OL, ole, ForeachType!T)(buffer);
				}
			}
		} else {
			foreach(size_t i ; 0..ret.length) {
				ret[i] = read!(endianness, OL, ole, ForeachType!T)(buffer);
			}
		}
		return ret;
	} else static if(isAssociativeArray!T) {
		T ret;
		foreach(i ; 0..readLength!(cle, CL)(buffer)) {
			ret[read!(endianness, OL, ole, KeyType!T)(buffer)] = read!(endianness, OL, ole, ValueType!T)(buffer);
		}
		return ret;
	} else static if(is(T == class) || is(T == struct)) {
		static if(is(T == class)) T ret = new T();
		else T ret;
		static if(__traits(hasMember, T, "decodeBody")) {
			ret.decodeBody(buffer);
		} else {
			ret = readMembers!(endianness, OL, ole)(buffer, ret);
		}
		return ret;
	} else static if(is(T : bool) || isIntegral!T || isFloatingPoint!T || isSomeChar!T) {
		return readImpl!(endianness, T)(buffer);
	} else {
		static assert(0, "Cannot decode " ~ T.stringof);
	}
}

size_t readLength(EndianType endianness, L)(OutputBuffer buffer) {
	static if(size_t.sizeof < L.sizeof) return cast(size_t)readImpl!(endianness, L)(buffer);
	else return readImpl!(endianness, L)(buffer);
}

T readImpl(EndianType endianness, T)(OutputBuffer buffer) {
	static if(endianness == EndianType.var && isIntegral!T && T.sizeof > 1) return buffer.readVar!T();
	else static if(endianness == EndianType.bigEndian) return buffer.read!(Endian.bigEndian, T)();
	else static if(endianness == EndianType.littleEndian) return buffer.read!(Endian.littleEndian, T)();
	else static assert(0, "Cannot decode " ~ T.stringof);
}

T readMembers(EndianType endianness, L, EndianType le, T)(OutputBuffer __buffer, T __container) {
	foreach(member ; Members!(T, EncodeOnly)) {
		mixin("alias M = typeof(__container." ~ member ~ ");");
		mixin({

			static if(hasUDA!(__traits(getMember, T, member), LengthImpl)) {
				import std.conv : to;
				auto length = getUDAs!(__traits(getMember, T, member), LengthImpl)[0];
				immutable e = "L, le, " ~ length.type ~ ", " ~ (length.endianness == EndianType.inherit ? "le" : "EndianType." ~ length.endianness.to!string);
			} else {
				immutable e = "L, le, L, le";
			}

			static if(hasUDA!(__traits(getMember, T, member), Bytes)) immutable ret = "__container." ~ member ~ "=__buffer.readBytes(__buffer.data.length-__buffer.index);";
			else static if(hasUDA!(__traits(getMember, T, member), Var)) immutable ret = "__container." ~ member ~ "=read!(EndianType.var, " ~ e ~ ", M)(__buffer);";
			else static if(hasUDA!(__traits(getMember, T, member), BigEndian)) immutable ret = "__container." ~ member ~ "=read!(EndianType.bigEndian, " ~ e ~ ", M)(__buffer);";
			else static if(hasUDA!(__traits(getMember, T, member), LittleEndian)) immutable ret = "__container." ~ member ~ "=read!(EndianType.littleEndian, " ~ e ~ ", M)(__buffer);";
			else immutable ret = "__container." ~ member ~ "=read!(endianness, " ~ e ~ ", M)(__buffer);";
			
			static if(!hasUDA!(__traits(getMember, T, member), Condition)) return ret;
			else return "with(__container){if(" ~ getUDAs!(__traits(getMember, T, member), Condition)[0].condition ~ "){" ~ ret ~ "}}";

		}());
	}
	return __container;
}

template Members(T, alias Only) {

	import std.typetuple : TypeTuple;

	mixin({

		string ret = "alias Members = TypeTuple!(";
		foreach(member ; __traits(derivedMembers, T)) {
			static if(is(typeof(mixin("T." ~ member)))) {
				mixin("alias M = typeof(T." ~ member ~ ");");
				static if(
					isType!M &&
					!isCallable!M &&
					!__traits(compiles, { mixin("auto test=T." ~ member ~ ";"); }) &&			// static members
					!__traits(compiles, { mixin("auto test=T.init." ~ member ~ "();"); }) &&	// properties
					!hasUDA!(__traits(getMember, T, member), Exclude) &&
					!hasUDA!(__traits(getMember, T, member), Only)
				) {
					ret ~= `"` ~ member ~ `",`;

				}
			}
		}
		return ret ~ ");";
		
	}());

}

unittest {

	import std.stdio : writeln;

	import packetmaker.packet : PacketImpl;

	alias Test = PacketImpl!(Endian.bigEndian, ubyte, ushort);
	
	class A : Test {
		
		enum ubyte ID = 44;
		
		int a;
		ushort b;
		
		mixin Make;
		
	}
	
	auto a = new A();
	a.a = 12;
	a.b = 2;
	assert(a.autoEncode() == [44, 0, 0, 0, 12, 0, 2]);

	a.decode([44, 0, 0, 0, 44, 0, 44]);
	assert(a.a == 44);
	assert(a.b == 44);

	// arrays
	
	class B : Test {
		
		enum ubyte ID = 45;
		
		ubyte[] bytes;
		int[2] ints;
		string str;
		immutable(bool)[] bools;
		
		mixin Make;
		
	}

	auto b = new B();
	b.bytes = [1, 2, 3];
	b.ints = [0, 256];
	b.str = "hello";
	b.bools = [true, false].idup;
	assert(b.autoEncode() == [45, 0, 3, 1, 2, 3, 0, 0, 0, 0, 0, 0, 1, 0, 0, 5, 'h', 'e', 'l', 'l', 'o', 0, 2, true, false]);

	b.decode([45, 0, 3, 1, 2, 3, 0, 0, 0, 0, 0, 0, 1, 0, 0, 5, 'h', 'e', 'l', 'l', 'o', 0, 2, false, true]);
	assert(b.bytes == [1, 2, 3]);
	assert(b.ints == [0, 256]);
	assert(b.str == "hello");
	assert(b.bools == [false, true]);

	class B2 : Test {

		wstring utf16;

		mixin Make;

	}

	auto b2 = new B2();
	b2.utf16 = "test"w;
	assert(b2.autoEncode() == [0, 4, 0, 't', 0, 'e', 0, 's', 0, 't']);

	// attributes

	class C : Test {

		enum ubyte ID = 8;

		@LittleEndian int le;

		@BigEndian int be;

		@Exclude long exclude;

		@EncodeOnly ubyte enc;

		@DecodeOnly ushort dec;

		@Var uint varuint;

		@Var short varshort;

		@LittleEndian ushort[] lea;

		@Var int[] varr;

		@Bytes ubyte[] rest;

		@property string prop() {
			return "test";
		}

		@property string prop(string value) {
			return value;
		}

		mixin Make;

	}

	auto c = new C();
	c.le = 1;
	c.be = 1;
	c.enc = 99;
	c.dec = 199;
	c.varuint = 200;
	c.varshort = -5;
	c.lea = [1];
	c.varr = [1];
	c.rest = [5];
	assert(c.autoEncode() == [8, 1, 0, 0, 0, 0, 0, 0, 1, 99, 200, 1, 9, 0, 1, 1, 0, 0, 1, 2, 5]);

	c.decode([8, 1, 1, 0, 0, 0, 0, 1, 0, 0, 44, 0, 3, 0, 1, 1, 0, 0, 1, 14, 1, 2, 3]);
	assert(c.le == 257);
	assert(c.be == 256);
	assert(c.enc == 99); // as previously assigned
	assert(c.dec == 44);
	assert(c.varuint == 0);
	assert(c.varshort == -2);
	assert(c.lea == [1]);
	assert(c.varr == [7]);
	assert(c.rest == [1, 2, 3]);

	// condition

	class D : Test {

		ubyte a;

		@Condition("a == 12") ubyte b;

		mixin Make;

	}

	auto d = new D();
	d.a = 11;
	d.b = 12;
	assert(d.autoEncode() == [11]); // no id!
	d.a = 12;
	assert(d.autoEncode() == [12, 12]);

	d.decode([100, 100]);
	assert(d.a == 100);
	assert(d.b == 12); // old one
	d.decode([12, 100]);
	assert(d.a == 12);
	assert(d.b == 100);

	// auto and custom struct encoding

	static struct E {

		uint a;
		@Var uint b;

	}

	static struct F {

		void encodeBody(InputBuffer buffer) {
			buffer.writeBytes(3, 3, 3);
		}

		void decodeBody(OutputBuffer buffer) {
			buffer.readBytes(3);
		}

	}

	class G : Test {

		ubyte a;
		E[] b;
		F c;

		mixin Make;

	}

	auto g = new G();
	g.a = 44;
	g.b ~= E(1, 2);
	g.b ~= E(0, 0);
	assert(g.autoEncode() == [44, 0, 2, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 3, 3, 3]);

	g.decode([12, 0, 1, 0, 0, 0, 1, 5, 3, 3, 3]);
	assert(g.a == 12);
	assert(g.b == [E(1, 5)]);

	// inheritance

	class H : Test {

		ushort a;

		mixin Make;

	}

	class I : H {

		enum ubyte ID = 1;

		ubyte b;

		mixin Make;

	}

	auto i = new I();
	i.a = 1;
	i.b = 2;
	assert(i.autoEncode() == [1, 0, 1, 2]);

	// custom length

	import packetmaker.varint : varuint, varulong;

	class J : Test {

		@Length!varuint ubyte[] a;
		@Length!ubyte string b;
		@EndianLength!ushort(Endian.littleEndian) ubyte[] c;
		@Length!varulong @Var int[] d;

		mixin Make;

	}

	auto j = new J();
	j.a = [1, 2, 3];
	j.b = "test";
	j.c = [50];
	j.d = [1, 2, 3];
	assert(j.autoEncode() == [3, 1, 2, 3, 4, 't', 'e', 's', 't', 1, 0, 50, 3, 2, 4, 6]);

	j.decode([2, 1, 2, 5, 'h', 'e', 'l', 'l', 'o', 5, 0, 33, 33, 33, 33, 33, 1, 1]);
	assert(j.a == [1, 2]);
	assert(j.b == "hello");
	assert(j.c == [33, 33, 33, 33, 33]);
	assert(j.d == [-1]);
	
}

mixin template MakeNested() { import packetmaker.maker : MakeImpl; mixin MakeImpl!(true); }

///
unittest {

	import std.stdio : writeln;
	
	import packetmaker.packet : PacketImpl;
	
	alias Base = PacketImpl!(Endian.bigEndian, ubyte, uint);
	
	class A : Base {
		
		enum ubyte ID = 1;
		
		int a, b, c;

		mixin Make;
		
		class B : Base {
			
			ushort d, e;

			mixin MakeNested;
			
			class C : Base {
				
				ubyte f, g, h;

				mixin MakeNested;
				
			}
			
		}
		
	}

	auto a = new A();
	a.a = 1;
	a.b = 2;
	a.c = 3;
	assert(a.autoEncode() == [1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3]);

	auto b = a.new B();
	b.d = 4;
	b.e = 5;
	assert(b.autoEncode() == [1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 4, 0, 5]);

	auto c = b.new C();
	c.f = 6;
	c.g = 7;
	c.h = 8;
	assert(c.autoEncode() == [1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 4, 0, 5, 6, 7, 8]);

	auto buffer = c.createInputBuffer();
	c.encodeBody(buffer);
	assert(buffer.data == [0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 4, 0, 5, 6, 7, 8]);
	
}
