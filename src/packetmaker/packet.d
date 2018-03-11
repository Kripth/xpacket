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
