import std.stdio;
import std.algorithm;
import std.range;
import std.string;


/*
Enums without body.
	eg `enum SDL_MIX_MAXVOLUME = 128;`
Structs & TransparentStruct.
*/

void main() {
	sdl_err;
	sdl_helpers;
	sdl_funs;
	sdl_types;
	sdl;
}

void sdl() {
	auto fout = File("./sdl-d/src/sdld/sdl.d", "w");
	
	fout.writeln("module sdld.sdl;");
	
	fout.writeln(
"public import
	sdld._sdl_err	,
	sdld._sdl_types	,
	sdld._sdl_funs	,
");
}
void sdl_err() {
	auto fout = File("./sdl-d/src/sdld/_sdl_err.d", "w");
	
	fout.writeln("module sdld._sdl_err;");
	fout.writeln("import derelict.sdl2.sdl");
	
	fout.writeln(
q{class SDLError : Exception {
	this(string msg,string file=__FILE__,size_t line=__LINE__) {
		super(msg,file,line);
	}
}});
}
void sdl_helpers() {
	auto fout = File("./sdl-d/src/sdld/_sdl_helpers.d", "w");
	
	fout.writeln("module sdld._sdl_helpers;");
	
	fout.writeln(
"abstract class Refer(T) {
	T* __refer;
	alias __refer this;
}
Refer!T makeRefer(alias deconstruct, T)(T t) {
	class MakeRefer : Refer!T {
		this(T refer) {
			this.__refer = refer;
		}
		~this() {
			deconstruct(__refer);
		}
	}
	return new MakeRefer(t);
}"); // A name better than `Refer` would be nice.
}

void sdl_funs() {
	auto fin = File("./DerelictSDL2/source/derelict/sdl2/internal/sdl_static.d", "r");
	auto fout = File("./sdl-d/src/sdld/_sdl_funs.d", "w");
	
	fout.writeln("module sdld._sdl_funs;");
	fout.writeln("import derelict.sdl2.sdl");
	fout.writeln("import sdld._sdl_err;");
	
	auto lines = fin.byLine.map!(l=>l.strip);
	foreach(line;lines) {
		if (line=="extern(C) @nogc nothrow {") {
			lines.popFront;
			break;
		}
	}
	foreach(line;lines) {
		if (line=="}") {
			break;
		}
		if (line.startsWith("static if")) {
			fout.writeln(line);
			lines.popFront;
			foreach(l;lines) {
				if (l=="}") {
					fout.writeln(l);
					break;
				}
				try {
					fout.writeln(bind(l));
				}
				catch (Throwable e) {
					writeln(r"\/\/\/ Line caused Crash");
					writeln(l);
					writeln(r"/\/\/\");
					throw e;
				}
			}
			continue;
		}
		try {
			fout.writeln(bind(line));
		}
		catch (Throwable e) {
			writeln(r"\/\/\/ Line caused Crash");
			writeln(line);
			writeln(r"/\/\/\");
			throw e;
		}
	}
}
void sdl_types() {
	auto fin = File("./DerelictSDL2/source/derelict/sdl2/internal/sdl_types.d", "r");
	auto fout = File("./sdl-d/src/sdld/_sdl_types.d", "w");
	
	fout.writeln("module sdld._sdl_types;");
	fout.writeln("import derelict.sdl2.sdl");
	fout.writeln("import sdld._sdl_err,sdld._sdl_helpers;");
	
	auto lines = fin.byLine.map!(l=>l.strip);
	foreach(line;lines) {
		try {
			if (line.startsWith("enum")&&line.endsWith("{")) {
				auto curlyIndex = line.countUntil('{');
				auto lineStrip = line["enum ".length..curlyIndex].strip;
				auto colonIndex = lineStrip.countUntil(':');
				auto beforeColon = (colonIndex==-1?lineStrip:lineStrip[0..colonIndex]).strip;
				auto afterColon =  (colonIndex==-1?lineStrip:lineStrip[colonIndex+1..$]).strip;
				string baseType = afterColon.idup;
				string newName = beforeColon.rSDL.camelCase!true.idup;
				
				if (newName=="") {
					string toAdd = line.idup~"\n";
					lines.popFront;
					foreach(l;lines) {
						if (l=="}") {
							toAdd ~= "}\n";
							break;
						}
						toAdd ~= "\t"~l.idup~"\n";
					}
					fout.writeln(toAdd);
				}
				else {
					string[] oldMemNames = [];
					lines.popFront;
					foreach(l;lines) {
						if (l=="}") {
							break;
						}
						auto mem = function(line){
							auto equalIndex = line.countUntil('=');
							auto commaIndex = line.countUntil(','); if(commaIndex==-1)commaIndex = line.length;
							auto name = line[0..equalIndex==-1?commaIndex:equalIndex].strip;
							return name.idup;
						}(l);
						if (mem!="") {
							oldMemNames ~= mem;
						}
						if (mem=="SDL_INIT_EVERYTHING") {
							writeln("Manually break enum");
							foreach(ll;lines) {
								if (ll=="}") {
									break;
								}
							}
							break;
						}
					}
					string repeatedPart;
					outer:for(int i=0;;i++) {
						auto last = oldMemNames[0][i];
						foreach (mem;oldMemNames[1..$]) {
							if (mem[i] != last) {
								repeatedPart = oldMemNames[0][0..i];
								break outer;
							}
						}
					}
					string[] memNames=oldMemNames.map!(a=>a[repeatedPart.length..$].toLower.camelCase).array;
					
					////if (newName=="") {
					////	newName = repeatedPart.rSDL.camelCase!true;
					////}
					
					string memString = zip(memNames,oldMemNames).map!(a=>"\t"~a[0]~"\t= "~a[1]~"\t,").join('\n');
					
					fout.writeln("enum "~newName~" "~(baseType==""?"":": "~baseType~" ")~"{\n"~memString~"\n}");
				}
			}
			else if (line.startsWith("struct")&&line.endsWith("{")) {
				string oldName = line["struct".length..$-"{".length].strip.idup;
				string newName = oldName.rSDL.strip.idup;
				fout.writeln("alias "~newName~"\t= "~oldName~";");
			}
			else if (line.startsWith("struct")&&line.endsWith(";")) {
				string oldName = line["struct".length..$-";".length].strip.idup;
				string newName = oldName.rSDL.strip.idup;
				fout.writeln("alias "~newName~"\t= Refer!"~oldName~";");
			}
		}
		catch (Throwable e) {
			writeln(r"\/\/\/ Line caused Crash");
			writeln(line);
			writeln(r"/\/\/\");
			throw e;
		}
	}
}

string bind(char[] mLine) {
	string line = mLine.idup;
	string type;
	string name;
	string[] argTypes;
	{
		auto spaceIndex = line.countUntil(' ');
		auto parenIndex = spaceIndex+line[spaceIndex..$].countUntil('(');
		auto closeParenIndex = line.length-(line.retro.countUntil(')')+1);
		type = line[0..spaceIndex];
		name = line[spaceIndex+1..parenIndex];
		argTypes = line[parenIndex+1..closeParenIndex].split(',');
	}
	if (name.startsWith("SDL_Destroy")) return "";
	
	bool throws = false;
	string niceName = name;
	////writeln(recurrence!"n"(0).take(2));
	////writeln(argTypes.zip(recurrence!"a+1"(0).map!"cast(char)((cast(ubyte)'a')+a)"));
	////return "";
	string paramString = argTypes.zip(recurrence!"n"(0).map!"cast(char)((cast(ubyte)'a')+a)").map!(a=>a[0]~' '~a[1]).join(',');
	string argString = recurrence!"n"(0).map!"cast(char)((cast(ubyte)'a')+a)".take(argTypes.length).map!"[a]".join(',');
	{
		niceName = niceName.rSDL.camelCase;
	}
	string callString = name~"("~argString~")";
	if (type == "int") {
		throws = true;
		type = "void";
	}
	
	if (type.endsWith("*") && niceName.startsWith("create")) {
		return 
"Refer!"~type~" "~niceName~"("~paramString~") {
	auto ptr = "~callString~";
	if (ptr is null) {
		throw new SDLError(SDL_GetError());
	}
	else {
		return makeRefer!(SDL_Destroy"~type.rSDL[0..$-"*".length]~")(ptr);
	}
}";
	}
	else {
		return type~" "~niceName~"("~paramString~") {\n"
			~	(throws
				?"\tif ("~callString~" != 0) {\n\t\tthrow new SDLError(SDL_GetError());\n\t}"
				:"\treturn "~callString~";")
			~"\n}";
	}	
}


inout(char)[] camelCase(bool capFirst=false)(inout(char)[] name) {
	assert(name==name.strip);
	if (name.length == 0) return [];
	auto newName = [name[0]].toLower~name[1..$];
	static if(capFirst) newName = [newName[0]].toUpper~newName[1..$];
	static if(!capFirst) newName = [newName[0]].toLower~newName[1..$];
	while(true) {
		auto scoreIndex = newName.countUntil('_');
		if (scoreIndex==-1) break;
		if (scoreIndex<newName.length-1) {
			newName = newName[0..scoreIndex]~[newName[scoreIndex+1]].toUpper~newName[scoreIndex+2..$];
		}
		else {
			newName = newName[0..scoreIndex];
		}
	}
	return newName;
}
inout(char)[] rSDL(inout(char)[] name) {
	return name[(name.startsWith("SDL_")?4:0)..$];
}