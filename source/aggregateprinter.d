module aggregateprinter;

import std.conv : to;
import std.traits : FieldNameTuple;
import std.typecons : Nullable;

struct AggregatePrinter(T) {
	enum mems = FieldNameTuple!T;
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
	static if(is(T == Nullable!Fs, Fs...)) {
		if(t.isNull()) {
			o("null");
		} else {
			o(to!string(t.get()));
		}
	} else {
		o(to!string(t));
	}
}

AggregatePrinter!T aggPrinter(T)(auto ref T t) {
	return AggregatePrinter!T(&t);
}

unittest {
	import std.stdio;
	import std.typecons : Nullable;

	struct Foo {
		int a;
		string b;
		bool c;
		Nullable!string d;
	}

	auto f = Foo(13, "Hello World", true);
	writeln(aggPrinter(f));
}
