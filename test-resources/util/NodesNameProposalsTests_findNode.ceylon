import java.util {
	Arrays { asList }
}

void fun({Anything*} argument)(Anything secondArgument){}

void variadic<Argument>(Argument argument, Argument* secondArgument) {}

void noParameters(){}

class Foo(Anything* argument){}

void withKeyword(Anything \ivoid) {}

void withUpperCase(Anything \iArgument) {}

void strings() {
	// empty string
	fun("");
	
	// string literal containing oter letters than characters
	fun("a1");
	
	// string literal containing only characters other than letters
	fun("11");
	
	// string litteral containing only letters
	fun("AA");
}

void parameters() {
	// Named argument
	fun{
		argument = "namedArgument";
	};
	
	// Positional argument
	fun("positionalArgument");
	
	// Sequenced argument
	fun{ "sequencedArgument1", "sequencedArgument2" };
	
	// Arguments on function which has more than one parameter list
	fun("argumentToFirstList")("argumentToSecondList");
	
	// Generic function with variadic parameter
	// Variadic parameters
	//  * Single argument for variadic parameter
	variadic<Anything>("nonVariadic", "variadic");
	//  * Multiple arguments for variadic parameter
	variadic<Anything>("nonVariadic_", "variadic1", "variadic2");
	
	// Argument to function with no parameters
	noParameters("shouldntBeHere");
	
	// Class with variadic parameter
	Foo("firstArgumentToClass", "secondArgumentToClass");
	
	// Indirect invocation
	Anything(Anything) indirect = variadic<Anything>;
	indirect("indirect");
	
	// Java method invocation
	asList("java");
	
	// Parameter name with keyword
	withKeyword("keyword");
	
	// Parameter name starting with uppercase letter
	withUpperCase("uppercase");
}
