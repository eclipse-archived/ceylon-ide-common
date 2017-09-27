import ceylon.file {
    lines,
    File
}
import ceylon.test {
    assertEquals,
    test,
    assertTrue,
    assertFalse
}

import org.eclipse.ceylon.compiler.typechecker.analyzer {
    UsageWarning
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.util {
    nodes
}

import test.org.eclipse.ceylon.ide.common.testUtils {
    SourceCode,
    parseAndTypecheckCode,
    findInLines
}

shared class NodesNameProposalsTests() {
	[String*] loadLines(String fileName) {
		assert (is File file = resourcesRoot.childResource(fileName));
		return lines(file);
	}
	
	String fileName = "NodesNameProposalsTests_findNode.ceylon";
	[String*] theLines = loadLines(fileName);
	String contents = "\n".join(theLines);
	value pu = parseAndTypecheckCode {
		jdkIncluded = true;
		SourceCode {
			path = fileName;
			contents = contents;
		}
	}.first?.item;
	assert (exists pu);
	assertEquals([for (message in pu.compilationUnit.errors) if (!message is UsageWarning) message], []);
	
	[String+] nameProposals(String stringLiteralValue) {
		value offset = findInLines {
		    lines = theLines;
		    searchedText = "\"``stringLiteralValue``\"";
		    indexInText = 0;
		};
		value node = nodes.findNode {
		    node = pu.compilationUnit;
		    tokens = pu.tokens;
		    startOffset = offset;
		    endOffset = offset;
		};
		assert (is Tree.Term|Tree.Type? node);
		return nodes.nameProposals {
		    node = node;
		    rootNode = pu.compilationUnit;
		};
	}
	
	void test(String stringLiteralValue, Condition condition)
			=> condition.check(nameProposals(stringLiteralValue));
	
	test shared void emptyString() => test("", NotProposed("", "\\i"));
	test shared void notOnlyLeters() => test("a1", NotProposed("a1", "a", "", "\\i"));
	test shared void onlyNonLetters() => test("11", NotProposed("11", "", "\\i"));
	test shared void onlyLetters() => test("AA", Proposed("aa"));
	
	test shared void namedArgument() => test("namedArgument", Proposed("argument"));
	test shared void positionalArgument() => test("positionalArgument", Proposed("argument"));
	test shared void sequencedArgument() {
		test("sequencedArgument1", Proposed("argument1"));
		test("sequencedArgument2", Proposed("argument2"));
	}
	test shared void multiParameterList() {
		 test("argumentToFirstList", Proposed("argument"));
		 test("argumentToSecondList", NotProposed("argument", "secondArgument"));
	}
	
	test shared void singleGenericVariadic()  {
		 test("nonVariadic", Proposed("argument"));
		 test("variadic", Proposed("secondArgument"));
	}
	
	test shared void multipleGenericVariadic()  {
		 test("nonVariadic_", Proposed("argument"));
		 test("variadic1", Proposed("secondArgument1"));
		 test("variadic2", Proposed("secondArgument2"));
	}
	
	test shared void noArgumentShouldBeHere() => test("shouldntBeHere", NotProposed("", "\\i"));
	
	test shared void classWithVariadic() {
		test("firstArgumentToClass", Proposed("argument1"));
		test("secondArgumentToClass", Proposed("argument2"));
	}
	
	test shared void indirectInvocation() => test("indirect", NotProposed("", "\\i", "argument", "argument1"));
	
	test shared void java() => test("java", NotProposed("", "\\i", "a"));
	
	test shared void withKeyword() => test("keyword", Proposed("\\ivoid"));
	
	test shared void withUpperCase() => test("uppercase", Proposed("\\iArgument"));
	
	interface Condition {
		shared formal void check([String+] proposedNames);
	}
	
	class Proposed(String* names) satisfies Condition {
		shared actual void check([String+] proposedNames) {
			for(value name in names){
				assertTrue(proposedNames.contains(name),
					"Expected proposal \"``name``\" to be found in propositions ``proposedNames``");
			}
		}
	}
	
	class NotProposed(String* names) satisfies Condition {
		shared actual void check([String+] proposedNames) {			
			for(value name in names){
				assertFalse(proposedNames.contains(name),
					"Expected proposal \"``name``\" not to be found in propositions ``proposedNames``");
			}
		}
	}
}
