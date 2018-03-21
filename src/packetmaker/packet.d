module packetmaker.packet;

import std.system : Endian;
import std.traits : isIntegral;

import xbuffer.buffer : Buffer;
import xbuffer.memory : alloc, free;
import xbuffer.varint : isVar;

class Packet {

	void encode(Buffer buffer) @nogc {
		encodeId(buffer);
		encodeBody(buffer);
	}

	void encodeId(Buffer buffer) @nogc {}

	void encodeBody(Buffer buffer) @nogc {}

	ubyte[] autoEncode() {
		Buffer buffer = createInputBuffer();
		scope(exit) free(buffer);
		encode(buffer);
		return buffer.data!ubyte.dup; // move to GC
	}

	Buffer createInputBuffer() @nogc {
		return alloc!Buffer(64);
	}

	void decode(Buffer buffer) {
		decodeId(buffer);
		decodeBody(buffer);
	}

	void decodeId(Buffer buffer) {}

	void decodeBody(Buffer buffer) {}

	void autoDecode(ubyte[] data) {
		Buffer buffer = createOutputBuffer(data);
		scope(exit) free(buffer);
		decode(buffer);
	}

	Buffer createOutputBuffer(ubyte[] data) @nogc {
		return alloc!Buffer(data);
	}

}

class PacketImpl(Endian endianness, T, Endian id_endianness, L, Endian length_endianness) : Packet if((isIntegral!T || isVar!T) && (isIntegral!L || isVar!L)) {

	// enums and aliases used by mixin template Make when not overriden

	protected enum Endian __packetEndianness = endianness;

	protected enum Endian __packetIdEndianness = id_endianness;

	protected enum Endian __packetLengthEndianness = length_endianness;

	protected alias __PacketId = T;

	protected alias __PacketLength = L;

}

alias PacketImpl(Endian endianness, T, Endian id_endianness, L) = PacketImpl!(endianness, T, id_endianness, L, endianness);

alias PacketImpl(Endian endianness, T, L, Endian length_endianness) = PacketImpl!(endianness, T, endianness, L, length_endianness);

alias PacketImpl(Endian endianness, T, L) = PacketImpl!(endianness, T, endianness, L, endianness);
