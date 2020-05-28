module aggregateprinter;

import std.conv : to;
import std.traits : FieldNameTuple, BaseClassesTuple;
import std.typecons : Nullable, nullable;
import std.meta : staticMap;
import std.format;

AggregatePrinter!T aggPrinter(T)(auto ref T t) {
	return AggregatePrinter!T(&t);
}

struct AggregatePrinter(T) {
	T* thing;

	this(T* thing) {
		this.thing = thing;
	}

	void toString(void delegate(const(char)[]) @safe output ) {
		printerImpl(output, *(this.thing));
	}
}

private template ClassFieldsImpl(T) {
	enum ClassFieldsImpl = FieldNameTuple!(T);
}

private template ClassFields(T) {
	enum ClassFields = [staticMap!(ClassFieldsImpl, BaseClassesTuple!T)]
		~ [ClassFieldsImpl!T];
}

private template AllFieldNames(T) {
	static if(is(T == class)) {
		enum AllFieldNames = ClassFields!T;
	} else {
		enum AllFieldNames = FieldNameTuple!T;
	}
}

private void printerImpl(Out,T)(ref Out o, T t) {
	import std.traits : isSomeString;
	import graphql : GQLDCustomLeaf;
	import nullablestore : NullableStore;
	import std.datetime : SysTime, Date, DateTime, TimeOfDay;
	import core.time : Duration;

	static if(is(T == Nullable!Fs, Fs...)) {
		if(t.isNull()) {
			o("null");
		} else {
			printerImpl(o, t.get());
		}
	} else static if(is(T : GQLDCustomLeaf!K, K...)) {
		printerImpl(o, t.value);
	} else static if(is(T : NullableStore!G, G)) {
		o(T.stringof);
 		// NullableStore stores no data
	} else static if(isSomeString!T) {
		o("\"");
		o(to!string(t));
		o("\"");
	} else static if(is(T == DateTime) || is(T == TimeOfDay) || is(T == Date)
			|| is(T == SysTime))
	{
		o(t.toISOExtString());
	} else static if(is(T == Duration)) {
		o(t.toString());
	} else static if(is(T == struct) || is(T == class)) {
		enum mems = AllFieldNames!T;
		o(T.stringof);
		o("(");
		static if(mems.length > 0) {
			o(mems[0]);
			o(": ");
			enum mOne = mems[0];
			printerImpl(o, __traits(getMember, t, mOne));
			static foreach(mem; mems[1 .. $]) {
				o(", ");
				o(mem);
				o(": ");
				printerImpl(o, __traits(getMember, t, mem));
			}
		}
		o(")");
	} else {
		o(to!string(t));
	}
}

unittest {
	import std.typecons : Nullable;

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
	string exp = `SubClass(a: 13, b: "Hello World", c: true, d: null, e: 1337)`;
	string as = format("\next: %s\ngot: %s", exp, s);
	assert(s == exp, as);
}

unittest {
	import std.typecons : Nullable;

	struct Foo {
		Nullable!int a;
	}

	Foo f;
	f.a = 1337;
	string s = format("%s", aggPrinter(f));
	assert(s == "Foo(a: 1337)", s);
}
unittest {
	import std.typecons : Nullable;
	import graphql.uda : GQLDCustomLeaf;
	import nullablestore;

	int toInt(string s) {
		return to!int(s);
	}

	string fromInt(int i) {
		return to!string(i);
	}

	alias QInt = GQLDCustomLeaf!(int, fromInt, toInt);
	alias QNInt = GQLDCustomLeaf!(Nullable!int, fromInt, toInt);

	struct Foo {
		Nullable!int a;
		QNInt b;
		QInt c;
		NullableStore!(int[]) d;
	}

	Foo f;
	f.a = 1337;
	string s = format("%s", aggPrinter(f));
	string exp = "Foo(a: 1337, b: null, c: 0, d: NullableStore!(int[]))";
	assert(s == exp, format("\next: %s\ngot: %s", exp, s));

	Foo f2;
	f2.a = 1338;
	f2.b.value = nullable(37);
	s = format("%s", aggPrinter(f2));
	exp = "Foo(a: 1338, b: 37, c: 0, d: NullableStore!(int[]))";
	assert(s == exp, format("\next: %s\ngot: %s", exp, s));
}

unittest {
	import std.stdio;
	import std.datetime;
	static struct Foo {
		int a;
		float b;
		DateTime dt;
		Date d;
		TimeOfDay tod;
	}

	static struct Bar {
		Foo foo;
		Nullable!Foo foo2;
		string c;
		Duration dur;
		TickDuration tdur;
	}

	Bar b;
	string s = format("%s", aggPrinter(b));
	string exp = 
	`Bar(foo: Foo(a: 0, b: nan, dt: 0001-01-01T00:00:00, d: 0001-01-01, tod: 00:00:00), foo2: null, c: "", dur: 0 hnsecs, tdur: TickDuration(length: 0))`
	;
	assert(s == exp, s);
}
