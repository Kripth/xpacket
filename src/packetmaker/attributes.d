module packetmaker.attributes;

import std.system : Endian;
import std.traits : isIntegral;

import packetmaker.maker : EndianType;

import xbuffer.varint : isVar;

/**
 * Excludes the field from both encoding and decoding.
 */
enum Exclude;

/**
 * Excludes the field from decoding, encode only.
 */
enum EncodeOnly;

/**
 * Excludes the field from encoding, decode only.
 */
enum DecodeOnly;

/**
 * Only encode/decode the field when the condition is met.
 * The condition is placed inside an if statement and can access
 * the variables and functions of the class/struct (without `this`).
 * 
 * This attribute can be used with EncodeOnly and DecodeOnly.
 */
struct Condition { string condition; }

/**
 * Indicates the endianness for the type and its subtypes.
 */
enum BigEndian;

/// ditto
enum LittleEndian;

enum Var;

enum Bytes;

struct LengthImpl { string type; int endianness; }

LengthImpl EndianLength(T)(Endian endianness) if(isIntegral!T) { return LengthImpl(T.stringof, endianness); }

template Length(T) if(isIntegral!T) { enum Length = LengthImpl(T.stringof, -1); }

template Length(T) if(isVar!T) { enum Length = LengthImpl(T.Base.stringof, EndianType.var); }

struct Custom(T) if(is(T == struct) || is(T == class)) { alias C = T; }
