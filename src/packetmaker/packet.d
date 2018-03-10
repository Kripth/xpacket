module packetmaker.packet;

import std.system : Endian;
import std.traits : isIntegral;

import packetmaker.buffer : InputBuffer, OutputBuffer;
import packetmaker.varint : isVar;

class Packet {

	void encode(InputBuffer buffer) {
		encodeId(buffer);
		encodeBody(buffer);
	}

	void encodeId(InputBuffer buffer) {}

	void encodeBody(InputBuffer buffer) {}

	ubyte[] autoEncode() {
		InputBuffer buffer = this.createInputBuffer();
		encode(buffer);
		return buffer.data;
	}

	InputBuffer createInputBuffer() {
		return new InputBuffer();
	}

	void decode(ubyte[] data) {
		decode(this.createOutputBuffer(data));
	}

	void decode(OutputBuffer buffer) {
		decodeId(buffer);
		decodeBody(buffer);
	}

	void decodeId(OutputBuffer buffer) {}

	void decodeBody(OutputBuffer buffer) {}

	OutputBuffer createOutputBuffer(ubyte[] data) {
		return new OutputBuffer(data);
	}

}

enum EndianType {

	bigEndian = cast(int)Endian.bigEndian,
	littleEndian = cast(int)Endian.littleEndian,
	inherit,
	var,
	
}

class PacketImpl(Endian endianness, T, EndianType id_endianness, L, EndianType length_endianness) : Packet if(isIntegral!T && isIntegral!L) {

	// enums

	protected enum __packet;

	protected enum Endian __endianness = endianness;

	protected enum EndianType __id_endianness = id_endianness == EndianType.inherit ? cast(EndianType)endianness : id_endianness;

	protected enum EndianType __length_endianness = length_endianness == EndianType.inherit ? cast(EndianType)endianness : length_endianness;

	// aliases

	protected alias __Id = T;

	protected alias __Length = L;

}

template PacketImpl(Endian endianness, T, EndianType id_endianness, L) if(isIntegral!T && (isIntegral!L || isVar!L)) {

	static if(isIntegral!L) alias PacketImpl = PacketImpl!(endianness, T, id_endianness, L, EndianType.inherit);
	else alias PacketImpl = PacketImpl!(endianness, T, id_endianness, L.Base, EndianType.var);

}

template PacketImpl(Endian endianness, T, L) if((isIntegral!T || isVar!T) && (isIntegral!L || isVar!L)) {

	static if(isIntegral!T) alias PacketImpl = PacketImpl!(endianness, T, EndianType.inherit, L);
	else alias PacketImpl = PacketImpl!(endianness, T.Base, EndianType.var, L);

}

unittest {

	import packetmaker.varint;

	alias A = PacketImpl!(Endian.bigEndian, ubyte, ushort);
	static assert(is(A.__packet));
	static assert(A.__endianness == Endian.bigEndian);
	static assert(A.__id_endianness == EndianType.bigEndian);
	static assert(A.__length_endianness == EndianType.bigEndian);

	alias B = PacketImpl!(Endian.littleEndian, ubyte, varuint);
	static assert(B.__endianness == Endian.littleEndian);
	static assert(B.__id_endianness == EndianType.littleEndian);
	static assert(B.__length_endianness == EndianType.var);
	static assert(is(B.__Length == uint));

	alias C = PacketImpl!(Endian.bigEndian, ushort, EndianType.littleEndian, uint);
	static assert(C.__endianness == Endian.bigEndian);
	static assert(C.__id_endianness == EndianType.littleEndian);
	static assert(C.__length_endianness == EndianType.bigEndian);
	static assert(is(C.__Id == ushort));

	alias D = PacketImpl!(Endian.littleEndian, varint, varuint);
	static assert(D.__id_endianness == EndianType.var);
	static assert(D.__length_endianness == EndianType.var);
	static assert(is(D.__Id == int));
	static assert(is(D.__Length == uint));

}
