module aggregateprinter;

import std.conv : to;
import std.traits : FieldNameTuple, BaseClassesTuple;
import std.typecons : Nullable;

AggregatePrinter!T aggPrinter(T)(auto ref T t) {
	return AggregatePrinter!T(&t);
}

private template ClassFields(T) {
	enum ClassFields = [FieldNameTuple!(T)];
}

struct AggregatePrinter(T) {
	import std.meta : staticMap;
	static if(is(T == class)) {
		enum mems = ClassField!T;
	} else {
		enum mems = FieldNameTuple!T;
	}
	T* thing;

	this(T* thing) {
		this.thing = thing;
	}

	void toString(void delegate(const(char)[]) @safe output ) {
		output(T.stringof);
		output("(");
		static if(mems.length > 0) {
			output(mems[0]);
			output(": ");
			enum mOne = mems[0];
			printerImpl(output, __traits(getMember, *this.thing, mOne));
			foreach(mem; mems[1 .. $]) {
				output(", ");
				output(mem);
				output(": ");
				printerImpl(output, __traits(getMember, *this.thing, mem));
			}
		}
		output(")");
	}
}

private void printerImpl(Out,T)(ref Out o, T t) {
	import std.traits : isSomeString;
	static if(is(T == Nullable!Fs, Fs...)) {
		if(t.isNull()) {
			o("null");
		} else {
			o(to!string(t.get()));
		}
	} else static if(isSomeString!T) {
		o("\"");
		o(to!string(t));
		o("\"");
	} else {
		o(to!string(t));
	}
}

unittest {
	import std.typecons : Nullable;
	import std.format;

	struct Foo {
		int a;
		string b;
		bool c;
		Nullable!string d;
	}

	auto f = Foo(13, "Hello World", true);
	string s = format("%s", aggPrinter(f));
	assert(s == `Foo(a: 13, b: "Hello World", c: true, d: null)`, s);
}

unittest {
	import std.typecons : Nullable;
	import std.format;

	class Bar {
		int a;
		string b;
		bool c;
		Nullable!string d;

		this(int a, string b, bool c) {
			this.a = a;
			this.b = b;
			this.c = c;
		}
	}

	auto f = new Bar(13, "Hello World", true);
	string s = format("%s", aggPrinter(f));
	assert(s == `Bar(a: 13, b: "Hello World", c: true, d: null)`, s);
}

unittest {
	import std.typecons : Nullable;
	import std.format;

	class Cls {
		int a;
		string b;
		bool c;
		Nullable!string d;

		this(int a, string b, bool c) {
			this.a = a;
			this.b = b;
			this.c = c;
		}
	}

	class SubClass : Cls {
		long e;
		this(int a, string b, bool c, long e) {
			super(a, b, c);
			this.e = e;
		}
	}

	auto f = new SubClass(13, "Hello World", true, 1337);
	string s = format("%s", aggPrinter(f));
	assert(s == `SubClass(a: 13, b: "Hello World", c: true, d: null, e: 1337)`, s);
}
