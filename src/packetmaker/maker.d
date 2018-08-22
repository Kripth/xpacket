module packetmaker.maker;

import std.string : capitalize;
import std.system : Endian;
import std.traits;

import xbuffer.buffer : Buffer;
import xbuffer.varint : isVar;

import xserial.serial : EndianType;

mixin template Make(Endian endianness, L, EndianType length_endianness) {

	import std.traits : isNested;

	import packetmaker.packet : Packet;
	
	import xbuffer.buffer : Buffer;

	import xserial.serial : EndianType, serializeNumber, serializeMembers, deserializeNumber, deserializeMembers;

	static assert(is(typeof(this) == class) || is(typeof(this) == struct));

	private enum bool __packet = is(typeof(this) : Packet);

	private enum bool __nested = __packet && isNested!(typeof(this)) && __traits(hasMember, __traits(parent, typeof(this)), "__packet");
	
	static if(__traits(hasMember, typeof(this), "ID")) {

		static assert(__traits(hasMember, typeof(this), "__PacketId") && __traits(hasMember, typeof(this), "__packetIdEndianness"));

		override void encodeId(Buffer buffer) {
			static if(isVar!__PacketId) serializeNumber!(EndianType.var, __PacketId.Base)(buffer, ID);
			else serializeNumber!(cast(EndianType)__packetIdEndianness, __PacketId)(buffer, ID);
		}

		override void decodeId(Buffer buffer) {
			static if(isVar!__PacketId) deserializeNumber!(EndianType.var, __PacketId.Base)(buffer);
			else deserializeNumber!(cast(EndianType)__packetIdEndianness, __PacketId)(buffer);
		}

	} else static if(__nested) {

		override void encodeId(Buffer buffer) {
			__traits(parent, typeof(this)).encodeId(buffer);
		}

		// decodeId should not be called in nested types

	}

	static if(__packet) {

		override void encodeBody(Buffer buffer) {
			static if(__nested) {
				__traits(parent, typeof(this)).encodeBody(buffer);
			}
			super.encodeBody(buffer);
			serializeMembers!(cast(EndianType)endianness, L, length_endianness)(buffer, this);
		}

		override void decodeBody(Buffer buffer) {
			super.decodeBody(buffer);
			deserializeMembers!(cast(EndianType)endianness, L, length_endianness)(buffer, this);
		}

	} else {

		void encodeBody(Buffer buffer) {
			serializeMembers!(cast(EndianType)endianness, L, length_endianness)(buffer, this);
		}

		void decodeBody(Buffer buffer) {
			deserializeMembers!(cast(EndianType)endianness, L, length_endianness)(buffer, &this);
		}

	}
	
}

mixin template Make(Endian endianness, Length, Endian length_endianness) {

	import packetmaker.maker : Make;

	import xserial.serial : EndianType;

	mixin Make!(endianness, Length, cast(EndianType)length_endianness);

}

mixin template Make(Endian endianness, Length) {

	import packetmaker.maker : Make;

	import xbuffer.varint : isVar;
	
	import xserial.serial : EndianType;

	static if(isVar!Length) mixin Make!(endianness, Length.Base, EndianType.var);
	else mixin Make!(endianness, Length, cast(EndianType)endianness);

}

mixin template Make() {

	//TODO check variables

	import packetmaker.maker : Make;

	import xbuffer.varint : isVar;
	
	import xserial.serial : EndianType;

	static if(isVar!__PacketLength) mixin Make!(__packetEndianness, __PacketLength.Base, EndianType.var);
	else mixin Make!(__packetEndianness, __PacketLength, cast(EndianType)__packetLengthEndianness);

}

unittest {

	import std.stdio : writeln;

	import packetmaker.packet : PacketImpl;

	import xserial.attribute;

	alias Test = PacketImpl!(Endian.bigEndian, ubyte, ushort);

	Buffer buffer = new Buffer(16);
	
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

	a.autoDecode([44, 0, 0, 0, 44, 0, 44]);
	assert(a.a == 44);
	assert(a.b == 44);

	// arrays
	
	class B : Test {
		
		enum ubyte ID = 45;
		
		ubyte[] bytes;
		int[2] ints;
		string str;
		immutable(bool)[] bools;
		ubyte[ubyte] aa;
		
		mixin Make;
		
	}

	auto b = new B();
	b.bytes = [1, 2, 3];
	b.ints = [0, 256];
	b.str = "hello";
	b.bools = [true, false].idup;
	b.aa[44] = 1;
	assert(b.autoEncode() == [45, 0, 3, 1, 2, 3, 0, 0, 0, 0, 0, 0, 1, 0, 0, 5, 'h', 'e', 'l', 'l', 'o', 0, 2, true, false, 0, 1, 44, 1]);

	b.autoDecode([45, 0, 3, 1, 2, 3, 0, 0, 0, 0, 0, 0, 1, 0, 0, 5, 'h', 'e', 'l', 'l', 'o', 0, 2, false, true, 0, 2, 0, 0, 1, 1]);
	assert(b.bytes == [1, 2, 3]);
	assert(b.ints == [0, 256]);
	assert(b.str == "hello");
	assert(b.bools == [false, true]);
	assert(b.aa.length == 2);
	assert(b.aa[0] == 0 && b.aa[1] == 1);

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

		@NoLength ubyte[] rest;

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
	c.prop = c.prop;
	assert(c.autoEncode() == [8, 1, 0, 0, 0, 0, 0, 0, 1, 99, 200, 1, 9, 0, 1, 1, 0, 0, 1, 2, 5]);

	c.autoDecode([8, 1, 1, 0, 0, 0, 0, 1, 0, 0, 44, 0, 3, 0, 1, 1, 0, 0, 1, 14, 1, 2, 3]);
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

	d.autoDecode([100, 100]);
	assert(d.a == 100);
	assert(d.b == 12); // old one
	d.autoDecode([12, 100]);
	assert(d.a == 12);
	assert(d.b == 100);

	// auto and custom struct encoding

	static struct E {

		uint a;
		@Var uint b;

	}

	/+static struct F {

		static const ubyte[] bytes = [3, 3, 3];

		void encodeBody(Buffer buffer) @nogc {
			buffer.write(bytes);
		}

		void decodeBody(Buffer buffer) {
			buffer.read!(ubyte[])(3);
		}

	}

	struct G {

		ubyte a;
		E[] b;
		F c;

		mixin Make!(Endian.bigEndian, ushort);

	}

	auto g = G();
	g.a = 44;
	g.b ~= E(1, 2);
	g.b ~= E(0, 0);
	g.encodeBody(buffer);
	assert(buffer == cast(ubyte[])[44, 0, 2, 0, 0, 0, 1, 2, 0, 0, 0, 0, 0, 3, 3, 3]);

	buffer.data = cast(ubyte[])[12, 0, 1, 0, 0, 0, 1, 5, 3, 3, 3];
	g.decodeBody(buffer);
	assert(g.a == 12);
	assert(g.b == [E(1, 5)]);+/

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

	import xbuffer.varint : varuint, varulong;

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

	j.autoDecode([2, 1, 2, 5, 'h', 'e', 'l', 'l', 'o', 5, 0, 33, 33, 33, 33, 33, 1, 1]);
	assert(j.a == [1, 2]);
	assert(j.b == "hello");
	assert(j.c == [33, 33, 33, 33, 33]);
	assert(j.d == [-1]);

	// nested packets
	
	alias Base = PacketImpl!(Endian.bigEndian, ubyte, uint);
	
	class K : Base {
		
		enum ubyte ID = 1;
		
		int a, b, c;

		mixin Make;
		
		class L : Base {
			
			ushort d, e;

			mixin Make;
			
			class M : Base {
				
				ubyte f, g, h;

				mixin Make;
				
			}
			
		}

		static class N : Base {

			uint i;

			mixin Make;

		}

	}

	static assert(K.__packet);
	static assert(!K.__nested);
	static assert(K.L.__packet);
	static assert(K.L.__nested);
	static assert(K.L.M.__packet);
	static assert(K.L.M.__nested);
	static assert(K.N.__packet);
	static assert(!K.N.__nested);

	auto k = new K();
	k.a = 1;
	k.b = 2;
	k.c = 3;
	assert(k.autoEncode() == [1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3]);

	auto l = k.new L();
	l.d = 4;
	l.e = 5;
	assert(l.autoEncode() == [1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 4, 0, 5]);

	auto m = l.new M();
	m.f = 6;
	m.g = 7;
	m.h = 8;
	assert(m.autoEncode() == [1, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 4, 0, 5, 6, 7, 8]);

	auto n = new K.N();
	n.i = 12;
	assert(n.autoEncode() == [0, 0, 0, 12]);

	buffer.reset();
	m.encodeBody(buffer);
	assert(buffer.data!ubyte == [0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 3, 0, 4, 0, 5, 6, 7, 8]);

	// structs

	struct O {

		uint a, b;
		ubyte[] d;

		mixin Make!(Endian.littleEndian, uint);

	}

	auto o = O(1, 2, [3]);
	buffer.reset();
	o.encodeBody(buffer);
	assert(buffer.data!ubyte == [1, 0, 0, 0, 2, 0, 0, 0, 1, 0, 0, 0, 3]);

	struct P {

		ubyte a;

		mixin Make!(Endian.bigEndian, varuint);

		struct Q {

			ubyte[] b;

			mixin Make!(Endian.bigEndian, varuint);

		}

	}

	auto q = P(12).Q([13]); // structs cannot be nested, because the base struct does not extend packet
	buffer.reset();
	q.encodeBody(buffer);
	assert(buffer.data!ubyte == [1, 13]);
	
	// issue #1

	class R : PacketImpl!(Endian.bigEndian, ubyte, varuint) {

		@Length!ushort short[] array;

		mixin Make;

	}

	auto r = new R();
	r.array = [-1, 0, 1];
	assert(r.autoEncode() == [0, 3, 255, 255, 0, 0, 0, 1]);

	r.autoDecode([0, 3, 255, 255, 0, 0, 0, 1]);
	assert(r.array == [-1, 0, 1]);

	// custom attribute

	import std.uuid : UUID;

	struct CustomUUID {

		public static void serialize(UUID uuid, Buffer buffer) {
			buffer.write(uuid.data);
		}

		public static UUID deserialize(Buffer buffer) {
			ubyte[16] data = buffer.read!(ubyte[])(16);
			return UUID(data);
		}

	}

	class S : Base {

		enum ubyte ID = 18;

		@Custom!CustomUUID UUID uuid;

		mixin Make;

	}

	ubyte[16] data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0];

	auto s = new S();
	s.uuid = UUID(data);
	assert(s.autoEncode() == [18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0]);

	a.autoDecode([18, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0]);
	assert(s.uuid.data == data);
	
}
