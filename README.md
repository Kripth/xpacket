Create packet encoders and decoders without writing any encode or decode method.

[![DUB Package](https://img.shields.io/dub/v/packet-maker.svg)](https://code.dlang.org/packages/packet-maker)
[![Build Status](https://travis-ci.org/Kripth/packet-maker.svg?branch=master)](https://travis-ci.org/Kripth/packet-maker)

```d
import packetmaker;

class MyPacket : PacketImpl!(Endian.bigEndian, ubyte, varuint) {

	enum ubyte ID = 1;

	uint integer;
	ubyte[] array;
	@LittleEndian short le;

	mixin Make;

}

MyPacket packet = new MyPacket();
packet.integer = 12;
packet.array = [1, 2, 3];
packet.le = 1;

assert(packet.autoEncode() == [

	// `ID` constant encoded as an unsigned byte as specified in the
	// second field of PacketImpl
	1,
	
	// `integer` field encoded as big endian as specified in the first
	// field of PacketImpl
	0, 0, 0, 12,
	
	// `array` field's length encoded as unsigned varint, as specified
	// in the third field of PacketImpl
	3,
	
	// content of `array`, a sequence of 3 bytes
	1, 2, 3,
	
	// content of `le` encoded as little endian because the @LittleEndian
	// attribute overrides the default endianness specified in PacketImpl
	1, 0,
	
]);
```