module xpacket.packet;

import std.system : Endian;
import std.traits : isIntegral;

import xbuffer.buffer : Buffer;
import xbuffer.memory : xalloc, xfree;
import xbuffer.varint : isVar;

class Packet {

	ubyte[] encode(Buffer buffer) {
		encodeId(buffer);
		encodeBody(buffer);
		return buffer.data!ubyte;
	}

	void encodeId(Buffer buffer) {}

	void encodeBody(Buffer buffer) {}

	ubyte[] encode() {
		Buffer buffer = createInputBuffer();
		scope(exit) xfree(buffer);
		return encode(buffer).dup; // move to GC
	}

	deprecated("Use encode instead") ubyte[] autoEncode() {
		return encode();
	}

	Buffer createInputBuffer() @nogc {
		return xalloc!Buffer(64);
	}

	void decode(Buffer buffer) {
		decodeId(buffer);
		decodeBody(buffer);
	}

	void decodeId(Buffer buffer) {}

	void decodeBody(Buffer buffer) {}

	void decode(in ubyte[] data) {
		Buffer buffer = createOutputBuffer(data);
		scope(exit) xfree(buffer);
		decode(buffer);
	}

	deprecated("Use decode instead") void autoDecode(in ubyte[] data) {
		return decode(data);
	}

	Buffer createOutputBuffer(in ubyte[] data) @nogc {
		return xalloc!Buffer(data);
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
