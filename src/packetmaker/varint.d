﻿module packetmaker.varint;

import std.traits : isIntegral, isUnsigned, isSigned, Unsigned;

import packetmaker.buffer : InputBuffer, OutputBuffer;

enum isVar(T) = is(T == Var!V, V);

struct Var(T) if(isIntegral!T && T.sizeof > 1) {

	alias Base = T;

	static if(isSigned!T) alias U = Unsigned!T;

	@disable this();

	static void encode(InputBuffer buffer, T value) nothrow @safe @nogc {
		static if(isUnsigned!T) {
			while(value > 0x7F) {
				buffer.writeUnsignedByte((value & 0x7F) | 0x80);
				value >>>= 7;
			}
			buffer.writeUnsignedByte(value & 0x7F);
		} else {
			static if(T.sizeof < int.sizeof) Var!U.encode(buffer, cast(U)(value >= 0 ? value << 1 : (-cast(int)value << 1) - 1));
			else Var!U.encode(buffer, value >= 0 ? value << 1 : (-value << 1) - 1);
		}
	}

	static T decode(OutputBuffer buffer) pure @safe @nogc {
		static if(isUnsigned!T) {
			T ret;
			size_t shift;
			ubyte next;
			do {
				next = buffer.readUnsignedByte();
				ret |= (next & 0x7F) << shift;
				shift += 7;
			} while(next > 0x7F);
			return ret;
		} else {
			T ret = Var!U.decode(buffer);
			if(ret & 1) return ((ret >> 1) + 1) * -1;
			else return ret >> 1;
		}
	}

}

alias varshort = Var!short;

alias varushort = Var!ushort;

alias varint = Var!int;

alias varuint = Var!uint;

alias varlong = Var!long;

alias varulong = Var!ulong;

unittest {

	static assert(isVar!varshort);
	static assert(!isVar!short);

}
